// lib/features/delivery_addresses/models/delivery_address.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class DeliveryPinLocation {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? placeId;
  final String? placeName;

  const DeliveryPinLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.placeId,
    this.placeName,
  });

  factory DeliveryPinLocation.fromMap(Map<String, dynamic> json) {
    double? toDouble(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = toDouble(json['latitude']);
    final lng = toDouble(json['longitude']);

    if (lat == null || lng == null) {
      throw ArgumentError(
        'DeliveryPinLocation requires latitude and longitude',
      );
    }

    return DeliveryPinLocation(
      latitude: lat,
      longitude: lng,
      accuracyMeters: toDouble(json['accuracyMeters']),
      placeId: (json['placeId'] as String?)?.trim(),
      placeName: (json['placeName'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
    if (placeId != null && placeId!.trim().isNotEmpty) 'placeId': placeId,
    if (placeName != null && placeName!.trim().isNotEmpty)
      'placeName': placeName,
  };
}

@immutable
class DeliveryAddress {
  final String id;
  final String tenantId;
  final String ownerUid;
  final String? ownerAccountNumber;

  final String label;

  final String recipientName;
  final String recipientPhone;

  final String? line1;
  final String? line2;
  final String? area;
  final String? city;
  final String? county;
  final String? landmark;
  final String? instructions;

  final DeliveryPinLocation? pinLocation;

  final bool isDefault;
  final bool isArchived;

  final String? createdAt;
  final String? updatedAt;

  const DeliveryAddress({
    required this.id,
    required this.tenantId,
    required this.ownerUid,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    this.ownerAccountNumber,
    this.line1,
    this.line2,
    this.area,
    this.city,
    this.county,
    this.landmark,
    this.instructions,
    this.pinLocation,
    this.isDefault = false,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  static String _clean(Object? v) => (v ?? '').toString().trim();

  static String? _opt(Object? v) {
    final s = _clean(v);
    return s.isEmpty ? null : s;
  }

  static bool _bool(Object? v) => v == true;

  static String? _parseTimestamp(Object? v) {
    if (v == null) return null;

    if (v is Timestamp) {
      return v.toDate().toIso8601String();
    }

    if (v is DateTime) {
      return v.toIso8601String();
    }

    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }

    return null;
  }

  static bool _hasAnyAddressText({
    String? line1,
    String? line2,
    String? area,
    String? city,
    String? county,
    String? landmark,
  }) {
    return [
      line1,
      line2,
      area,
      city,
      county,
      landmark,
    ].any((e) => (e ?? '').trim().isNotEmpty);
  }

  bool get hasPin => pinLocation != null;

  bool get hasAddressText => _hasAnyAddressText(
    line1: line1,
    line2: line2,
    area: area,
    city: city,
    county: county,
    landmark: landmark,
  );

  bool get isUsable => hasPin || hasAddressText;

  String get recipientDisplay => '$recipientName • $recipientPhone';

  String get shortDisplay {
    final parts = <String>[
      label,
      if ((area ?? '').trim().isNotEmpty) area!.trim(),
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
    ];
    return parts.join(' • ');
  }

  String get fullDisplay {
    final parts = <String>[
      if (line1 != null && line1!.trim().isNotEmpty) line1!.trim(),
      if (line2 != null && line2!.trim().isNotEmpty) line2!.trim(),
      if (area != null && area!.trim().isNotEmpty) area!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (county != null && county!.trim().isNotEmpty) county!.trim(),
      if (landmark != null && landmark!.trim().isNotEmpty) 'Near $landmark',
    ];
    return parts.join(', ');
  }

  DateTime? get createdAtDate =>
      createdAt != null ? DateTime.tryParse(createdAt!) : null;

  DateTime? get updatedAtDate =>
      updatedAt != null ? DateTime.tryParse(updatedAt!) : null;

  factory DeliveryAddress.fromMap(Map<String, dynamic> json) {
    final id = _clean(json['id']);
    final tenantId = _clean(json['tenantId']);
    final ownerUid = _clean(json['ownerUid']);
    final label = _clean(json['label']);
    final recipientName = _clean(json['recipientName']);
    final recipientPhone = _clean(json['recipientPhone']);

    if (id.isEmpty) throw ArgumentError('DeliveryAddress requires id');
    if (tenantId.isEmpty) {
      throw ArgumentError('DeliveryAddress requires tenantId');
    }
    if (ownerUid.isEmpty) {
      throw ArgumentError('DeliveryAddress requires ownerUid');
    }
    if (label.isEmpty) throw ArgumentError('DeliveryAddress requires label');
    if (recipientName.isEmpty) {
      throw ArgumentError('DeliveryAddress requires recipientName');
    }
    if (recipientPhone.isEmpty) {
      throw ArgumentError('DeliveryAddress requires recipientPhone');
    }

    final pinRaw = json['pinLocation'];
    DeliveryPinLocation? pin;
    if (pinRaw is Map) {
      pin = DeliveryPinLocation.fromMap(
        Map<String, dynamic>.from(
          pinRaw.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
    }

    final address = DeliveryAddress(
      id: id,
      tenantId: tenantId,
      ownerUid: ownerUid,
      ownerAccountNumber: _opt(json['ownerAccountNumber']),
      label: label,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      line1: _opt(json['line1']),
      line2: _opt(json['line2']),
      area: _opt(json['area']),
      city: _opt(json['city']),
      county: _opt(json['county']),
      landmark: _opt(json['landmark']),
      instructions: _opt(json['instructions']),
      pinLocation: pin,
      isDefault: _bool(json['isDefault']),
      isArchived: _bool(json['isArchived']),
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
    );

    if (!address.isUsable) {
      throw ArgumentError(
        'DeliveryAddress must have address text and/or a pin location',
      );
    }

    return address;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'tenantId': tenantId,
    'ownerUid': ownerUid,
    if (ownerAccountNumber != null) 'ownerAccountNumber': ownerAccountNumber,
    'label': label,
    'recipientName': recipientName,
    'recipientPhone': recipientPhone,
    if (line1 != null) 'line1': line1,
    if (line2 != null) 'line2': line2,
    if (area != null) 'area': area,
    if (city != null) 'city': city,
    if (county != null) 'county': county,
    if (landmark != null) 'landmark': landmark,
    if (instructions != null) 'instructions': instructions,
    if (pinLocation != null) 'pinLocation': pinLocation!.toMap(),
    if (isDefault) 'isDefault': true,
    if (isArchived) 'isArchived': true,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  DeliveryAddress copyWith({
    String? id,
    String? tenantId,
    String? ownerUid,
    String? ownerAccountNumber,
    String? label,
    String? recipientName,
    String? recipientPhone,
    String? line1,
    String? line2,
    String? area,
    String? city,
    String? county,
    String? landmark,
    String? instructions,
    DeliveryPinLocation? pinLocation,
    bool? isDefault,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerAccountNumber: ownerAccountNumber ?? this.ownerAccountNumber,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      area: area ?? this.area,
      city: city ?? this.city,
      county: county ?? this.county,
      landmark: landmark ?? this.landmark,
      instructions: instructions ?? this.instructions,
      pinLocation: pinLocation ?? this.pinLocation,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
