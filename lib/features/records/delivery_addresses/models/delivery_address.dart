import 'package:flutter/foundation.dart';

@immutable
class DeliveryPinLocation {
  const DeliveryPinLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.placeId,
    this.placeName,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? placeId;
  final String? placeName;

  factory DeliveryPinLocation.fromMap(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    if (lat is! num || lng is! num) {
      throw const FormatException(
        'Pin requires numeric latitude and longitude',
      );
    }
    return DeliveryPinLocation(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      accuracyMeters: json['accuracy_meters'] is num
          ? (json['accuracy_meters'] as num).toDouble()
          : null,
      placeId: json['place_id'] as String?,
      placeName: json['place_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
    if (placeId != null) 'place_id': placeId,
    if (placeName != null) 'place_name': placeName,
  };
}

@immutable
class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.contactId,
    required this.appId,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
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

  final String id;
  final String contactId;
  final String appId;
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

  bool get hasPin => pinLocation != null;
  bool get hasAddressText => [
    line1,
    line2,
    area,
    city,
    county,
    landmark,
  ].any((value) => (value ?? '').trim().isNotEmpty);
  bool get isUsable => hasPin || hasAddressText;
  String get recipientDisplay => '$recipientName • $recipientPhone';
  String get shortDisplay => [
    label,
    area,
    city,
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ');
  String get fullDisplay => [
    line1,
    line2,
    area,
    city,
    county,
    if ((landmark ?? '').trim().isNotEmpty) 'Near $landmark',
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
  DateTime? get createdAtDate =>
      createdAt == null ? null : DateTime.tryParse(createdAt!);
  DateTime? get updatedAtDate =>
      updatedAt == null ? null : DateTime.tryParse(updatedAt!);

  static String string(Object? value) => (value ?? '').toString().trim();
  static String? optional(Object? value) {
    final valueString = string(value);
    return valueString.isEmpty ? null : valueString;
  }

  factory DeliveryAddress.fromMap(Map<String, dynamic> json) {
    final pin = json['pin_location'];
    return DeliveryAddress(
      id: string(json['address_id']),
      contactId: string(json['contact_id']),
      appId: string(json['app_id']),
      label: string(json['label']),
      recipientName: string(json['recipient_name']),
      recipientPhone: string(json['recipient_phone']),
      line1: optional(json['line1']),
      line2: optional(json['line2']),
      area: optional(json['area']),
      city: optional(json['city']),
      county: optional(json['county']),
      landmark: optional(json['landmark']),
      instructions: optional(json['instructions']),
      pinLocation: pin is Map
          ? DeliveryPinLocation.fromMap(Map<String, dynamic>.from(pin))
          : null,
      isDefault: json['is_default'] == true,
      isArchived: json['is_archived'] == true,
      createdAt: optional(json['created_at']),
      updatedAt: optional(json['updated_at']),
    );
  }

  /// Backend POST/PATCH payload. Never send owner, app, id or timestamps.
  Map<String, dynamic> toWriteMap() => {
    'label': label,
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
    if (line1 != null) 'line1': line1,
    if (line2 != null) 'line2': line2,
    if (area != null) 'area': area,
    if (city != null) 'city': city,
    if (county != null) 'county': county,
    if (landmark != null) 'landmark': landmark,
    if (instructions != null) 'instructions': instructions,
    if (pinLocation != null) 'pin_location': pinLocation!.toMap(),
    'is_default': isDefault,
  };

  DeliveryAddress copyWith({
    String? id,
    String? contactId,
    String? appId,
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
  }) => DeliveryAddress(
    id: id ?? this.id,
    contactId: contactId ?? this.contactId,
    appId: appId ?? this.appId,
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
