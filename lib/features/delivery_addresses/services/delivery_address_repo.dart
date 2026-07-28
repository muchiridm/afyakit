// lib/features/delivery_addresses/services/delivery_address_repo.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';

class DeliveryAddressRepo {
  DeliveryAddressRepo(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _collectionName = 'delivery_addresses';
  static const String _authUsersCollection = 'auth_users';

  CollectionReference<Map<String, dynamic>> _collection({
    required String tenantId,
    required String ownerUid,
  }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection(_authUsersCollection)
        .doc(ownerUid)
        .collection(_collectionName);
  }

  DocumentReference<Map<String, dynamic>> _docRef({
    required String tenantId,
    required String ownerUid,
    required String addressId,
  }) {
    return _collection(tenantId: tenantId, ownerUid: ownerUid).doc(addressId);
  }

  String newId({required String tenantId, required String ownerUid}) {
    return _collection(tenantId: tenantId, ownerUid: ownerUid).doc().id;
  }

  Future<List<DeliveryAddress>> listForUser({
    required String tenantId,
    required String ownerUid,
    bool includeArchived = false,
  }) async {
    Query<Map<String, dynamic>> query = _collection(
      tenantId: tenantId,
      ownerUid: ownerUid,
    );

    if (!includeArchived) {
      query = query.where('isArchived', isEqualTo: false);
    }

    final snap = await query.get();

    final items = <DeliveryAddress>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final normalized = <String, dynamic>{
        ...data,
        'id': (data['id'] as String?)?.trim().isNotEmpty == true
            ? data['id']
            : doc.id,
        'tenantId': (data['tenantId'] as String?)?.trim().isNotEmpty == true
            ? data['tenantId']
            : tenantId,
        'ownerUid': (data['ownerUid'] as String?)?.trim().isNotEmpty == true
            ? data['ownerUid']
            : ownerUid,
      };

      try {
        items.add(DeliveryAddress.fromMap(normalized));
      } catch (e, st) {
        debugPrint(
          '⚠️ DeliveryAddressRepo.listForUser: skipping invalid address '
          'doc=${doc.id} tenant=$tenantId owner=$ownerUid error=$e\n$st',
        );
      }
    }

    items.sort(_sortAddresses);
    return items;
  }

  Future<DeliveryAddress?> getById({
    required String tenantId,
    required String ownerUid,
    required String addressId,
  }) async {
    final snap = await _docRef(
      tenantId: tenantId,
      ownerUid: ownerUid,
      addressId: addressId,
    ).get();

    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final normalized = <String, dynamic>{
      ...data,
      'id': (data['id'] as String?)?.trim().isNotEmpty == true
          ? data['id']
          : snap.id,
      'tenantId': (data['tenantId'] as String?)?.trim().isNotEmpty == true
          ? data['tenantId']
          : tenantId,
      'ownerUid': (data['ownerUid'] as String?)?.trim().isNotEmpty == true
          ? data['ownerUid']
          : ownerUid,
    };

    return DeliveryAddress.fromMap(normalized);
  }

  Future<DeliveryAddress?> getDefault({
    required String tenantId,
    required String ownerUid,
    bool includeArchived = false,
  }) async {
    final items = await listForUser(
      tenantId: tenantId,
      ownerUid: ownerUid,
      includeArchived: includeArchived,
    );

    for (final item in items) {
      if (item.isDefault) return item;
    }
    return null;
  }

  Future<DeliveryAddress> save(DeliveryAddress address) async {
    _validateOwnership(address);

    final doc = _docRef(
      tenantId: address.tenantId,
      ownerUid: address.ownerUid,
      addressId: address.id,
    );

    if (address.isDefault) {
      await _unsetOtherDefaults(
        tenantId: address.tenantId,
        ownerUid: address.ownerUid,
        keepAddressId: address.id,
      );
    }

    final now = FieldValue.serverTimestamp();

    await doc.set({
      ...address.toMap(),
      'id': address.id,
      'tenantId': address.tenantId,
      'ownerUid': address.ownerUid,
      'isArchived': address.isArchived,
      'isDefault': address.isArchived ? false : address.isDefault,
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));

    final saved = await getById(
      tenantId: address.tenantId,
      ownerUid: address.ownerUid,
      addressId: address.id,
    );

    if (saved == null) {
      throw StateError(
        'DeliveryAddressRepo.save: address was written but could not be reloaded',
      );
    }

    return saved;
  }

  Future<DeliveryAddress> create({
    required String tenantId,
    required String ownerUid,
    required String label,
    required String recipientName,
    required String recipientPhone,
    String? ownerAccountNumber,
    String? line1,
    String? line2,
    String? area,
    String? city,
    String? county,
    String? landmark,
    String? instructions,
    DeliveryPinLocation? pinLocation,
    bool isDefault = false,
  }) async {
    final id = newId(tenantId: tenantId, ownerUid: ownerUid);

    final address = DeliveryAddress(
      id: id,
      tenantId: tenantId,
      ownerUid: ownerUid,
      ownerAccountNumber: ownerAccountNumber,
      label: label,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      line1: line1,
      line2: line2,
      area: area,
      city: city,
      county: county,
      landmark: landmark,
      instructions: instructions,
      pinLocation: pinLocation,
      isDefault: isDefault,
      isArchived: false,
    );

    return save(address);
  }

  Future<DeliveryAddress> update(DeliveryAddress address) async {
    _validateOwnership(address);

    final existing = await getById(
      tenantId: address.tenantId,
      ownerUid: address.ownerUid,
      addressId: address.id,
    );

    if (existing == null) {
      throw StateError(
        'DeliveryAddressRepo.update: address not found: ${address.id}',
      );
    }

    if (address.isDefault) {
      await _unsetOtherDefaults(
        tenantId: address.tenantId,
        ownerUid: address.ownerUid,
        keepAddressId: address.id,
      );
    }

    final updated = address.copyWith(
      createdAt: existing.createdAt,
      updatedAt: null,
      isDefault: address.isArchived ? false : address.isDefault,
    );

    final doc = _docRef(
      tenantId: updated.tenantId,
      ownerUid: updated.ownerUid,
      addressId: updated.id,
    );

    await doc.set({
      ...updated.toMap(),
      'id': updated.id,
      'tenantId': updated.tenantId,
      'ownerUid': updated.ownerUid,
      'updatedAt': FieldValue.serverTimestamp(),
      if ((existing.createdAt ?? '').trim().isEmpty)
        'createdAt': FieldValue.serverTimestamp()
      else
        'createdAt': existing.createdAt,
    }, SetOptions(merge: true));

    final reloaded = await getById(
      tenantId: updated.tenantId,
      ownerUid: updated.ownerUid,
      addressId: updated.id,
    );

    if (reloaded == null) {
      throw StateError(
        'DeliveryAddressRepo.update: address was updated but could not be reloaded',
      );
    }

    return reloaded;
  }

  Future<void> archive({
    required String tenantId,
    required String ownerUid,
    required String addressId,
  }) async {
    final doc = _docRef(
      tenantId: tenantId,
      ownerUid: ownerUid,
      addressId: addressId,
    );

    final snap = await doc.get();
    if (!snap.exists) return;

    await doc.set({
      'isArchived': true,
      'isDefault': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unarchive({
    required String tenantId,
    required String ownerUid,
    required String addressId,
  }) async {
    final doc = _docRef(
      tenantId: tenantId,
      ownerUid: ownerUid,
      addressId: addressId,
    );

    final snap = await doc.get();
    if (!snap.exists) return;

    await doc.set({
      'isArchived': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDefault({
    required String tenantId,
    required String ownerUid,
    required String addressId,
  }) async {
    final target = await getById(
      tenantId: tenantId,
      ownerUid: ownerUid,
      addressId: addressId,
    );

    if (target == null) {
      throw StateError(
        'DeliveryAddressRepo.setDefault: address not found: $addressId',
      );
    }

    if (target.isArchived) {
      throw StateError(
        'DeliveryAddressRepo.setDefault: cannot set archived address as default',
      );
    }

    await _unsetOtherDefaults(
      tenantId: tenantId,
      ownerUid: ownerUid,
      keepAddressId: addressId,
    );

    await _docRef(
      tenantId: tenantId,
      ownerUid: ownerUid,
      addressId: addressId,
    ).set({
      'isDefault': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearDefault({
    required String tenantId,
    required String ownerUid,
    required String addressId,
  }) async {
    await _docRef(
      tenantId: tenantId,
      ownerUid: ownerUid,
      addressId: addressId,
    ).set({
      'isDefault': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _unsetOtherDefaults({
    required String tenantId,
    required String ownerUid,
    required String keepAddressId,
  }) async {
    final snap = await _collection(
      tenantId: tenantId,
      ownerUid: ownerUid,
    ).where('isDefault', isEqualTo: true).get();

    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final doc in snap.docs) {
      if (doc.id == keepAddressId) continue;
      batch.set(doc.reference, {
        'isDefault': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  void _validateOwnership(DeliveryAddress address) {
    if (address.tenantId.trim().isEmpty) {
      throw ArgumentError('DeliveryAddressRepo: tenantId is required');
    }
    if (address.ownerUid.trim().isEmpty) {
      throw ArgumentError('DeliveryAddressRepo: ownerUid is required');
    }
    if (address.id.trim().isEmpty) {
      throw ArgumentError('DeliveryAddressRepo: id is required');
    }
    if (!address.isUsable) {
      throw ArgumentError(
        'DeliveryAddressRepo: address must have address text and/or a pin location',
      );
    }
  }

  static int _sortAddresses(DeliveryAddress a, DeliveryAddress b) {
    if (a.isArchived != b.isArchived) {
      return a.isArchived ? 1 : -1;
    }
    if (a.isDefault != b.isDefault) {
      return a.isDefault ? -1 : 1;
    }

    final aUpdated = (a.updatedAt ?? '').trim();
    final bUpdated = (b.updatedAt ?? '').trim();
    if (aUpdated != bUpdated) {
      return bUpdated.compareTo(aUpdated);
    }

    final aCreated = (a.createdAt ?? '').trim();
    final bCreated = (b.createdAt ?? '').trim();
    if (aCreated != bCreated) {
      return bCreated.compareTo(aCreated);
    }

    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }
}
