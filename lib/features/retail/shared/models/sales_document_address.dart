// lib/features/retail/shared/models/sales_document_address.dart

import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter/foundation.dart';

@immutable
class SalesDocumentAddress {
  const SalesDocumentAddress({
    this.addressId,
    this.label,
    this.recipientName,
    this.recipientPhone,
    this.line1,
    this.line2,
    this.area,
    this.city,
    this.county,
    this.landmark,
    this.instructions,
    this.placeName,
    this.latitude,
    this.longitude,
  });

  final String? addressId;
  final String? label;
  final String? recipientName;
  final String? recipientPhone;
  final String? line1;
  final String? line2;
  final String? area;
  final String? city;
  final String? county;
  final String? landmark;
  final String? instructions;
  final String? placeName;
  final double? latitude;
  final double? longitude;

  factory SalesDocumentAddress.fromDeliveryAddress(DeliveryAddress a) {
    return SalesDocumentAddress(
      addressId: a.id,
      label: a.label,
      recipientName: a.recipientName,
      recipientPhone: a.recipientPhone,
      line1: a.line1,
      line2: a.line2,
      area: a.area,
      city: a.city,
      county: a.county,
      landmark: a.landmark,
      instructions: a.instructions,
      placeName: a.pinLocation?.placeName,
      latitude: a.pinLocation?.latitude,
      longitude: a.pinLocation?.longitude,
    );
  }

  factory SalesDocumentAddress.fromJson(JsonMap json) {
    final j = json.cast<String, Object?>();

    return SalesDocumentAddress(
      addressId: _cleanStringOrNull(j['address_id'] ?? j['addressId']),
      label: _cleanStringOrNull(j['label']),
      recipientName: _cleanStringOrNull(
        j['recipient_name'] ?? j['recipientName'],
      ),
      recipientPhone: _cleanStringOrNull(
        j['recipient_phone'] ?? j['recipientPhone'],
      ),
      line1: _cleanStringOrNull(j['line1']),
      line2: _cleanStringOrNull(j['line2']),
      area: _cleanStringOrNull(j['area']),
      city: _cleanStringOrNull(j['city']),
      county: _cleanStringOrNull(j['county']),
      landmark: _cleanStringOrNull(j['landmark']),
      instructions: _cleanStringOrNull(j['instructions']),
      placeName: _cleanStringOrNull(j['place_name'] ?? j['placeName']),
      latitude: _readDoubleOrNull(j['latitude']),
      longitude: _readDoubleOrNull(j['longitude']),
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasRecipient =>
      (recipientName ?? '').trim().isNotEmpty ||
      (recipientPhone ?? '').trim().isNotEmpty;

  bool get hasAddressText =>
      (line1 ?? '').trim().isNotEmpty ||
      (line2 ?? '').trim().isNotEmpty ||
      (area ?? '').trim().isNotEmpty ||
      (city ?? '').trim().isNotEmpty ||
      (county ?? '').trim().isNotEmpty ||
      (landmark ?? '').trim().isNotEmpty;

  bool get isUsable => hasAddressText || hasCoordinates;

  String get shortDisplay {
    final parts = <String>[
      if ((label ?? '').trim().isNotEmpty) label!.trim(),
      if ((area ?? '').trim().isNotEmpty) area!.trim(),
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
    ];
    return parts.join(' • ');
  }

  String get singleLine {
    final parts = <String>[
      if ((line1 ?? '').trim().isNotEmpty) line1!.trim(),
      if ((line2 ?? '').trim().isNotEmpty) line2!.trim(),
      if ((area ?? '').trim().isNotEmpty) area!.trim(),
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((county ?? '').trim().isNotEmpty) county!.trim(),
      if ((landmark ?? '').trim().isNotEmpty) 'Near ${landmark!.trim()}',
    ];
    return parts.join(', ');
  }

  String get recipientDisplay {
    final parts = <String>[
      if ((recipientName ?? '').trim().isNotEmpty) recipientName!.trim(),
      if ((recipientPhone ?? '').trim().isNotEmpty) recipientPhone!.trim(),
    ];
    return parts.join(' • ');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if ((addressId ?? '').trim().isNotEmpty) 'address_id': addressId!.trim(),
      if ((label ?? '').trim().isNotEmpty) 'label': label!.trim(),
      if ((recipientName ?? '').trim().isNotEmpty)
        'recipient_name': recipientName!.trim(),
      if ((recipientPhone ?? '').trim().isNotEmpty)
        'recipient_phone': recipientPhone!.trim(),
      if ((line1 ?? '').trim().isNotEmpty) 'line1': line1!.trim(),
      if ((line2 ?? '').trim().isNotEmpty) 'line2': line2!.trim(),
      if ((area ?? '').trim().isNotEmpty) 'area': area!.trim(),
      if ((city ?? '').trim().isNotEmpty) 'city': city!.trim(),
      if ((county ?? '').trim().isNotEmpty) 'county': county!.trim(),
      if ((landmark ?? '').trim().isNotEmpty) 'landmark': landmark!.trim(),
      if ((instructions ?? '').trim().isNotEmpty)
        'instructions': instructions!.trim(),
      if ((placeName ?? '').trim().isNotEmpty) 'place_name': placeName!.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  SalesDocumentAddress copyWith({
    String? addressId,
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
    String? placeName,
    double? latitude,
    double? longitude,
  }) {
    return SalesDocumentAddress(
      addressId: addressId ?? this.addressId,
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
      placeName: placeName ?? this.placeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  static String? _cleanStringOrNull(Object? v) {
    final s = readStringOrNull(v)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static double? _readDoubleOrNull(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();

    final s = readStringOrNull(v)?.trim();
    if (s == null || s.isEmpty) return null;

    return double.tryParse(s);
  }
}
