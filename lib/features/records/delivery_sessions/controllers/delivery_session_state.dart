import 'dart:convert';

class DeliverySessionState {
  final String? deliveryId;
  final String? enteredByName;
  final String? enteredByEmail;
  final List<String> sources;
  final String? lastStoreId;
  final String? lastSource;

  const DeliverySessionState({
    this.deliveryId,
    this.enteredByName,
    this.enteredByEmail,
    this.sources = const [],
    this.lastStoreId,
    this.lastSource,
  });

  DeliverySessionState copyWith({
    String? deliveryId,
    String? enteredByName,
    String? enteredByEmail,
    List<String>? sources,
    String? lastStoreId,
    String? lastSource,
  }) {
    return DeliverySessionState(
      deliveryId: deliveryId ?? this.deliveryId,
      enteredByName: enteredByName ?? this.enteredByName,
      enteredByEmail: enteredByEmail ?? this.enteredByEmail,
      sources: sources ?? this.sources,
      lastStoreId: lastStoreId ?? this.lastStoreId,
      lastSource: lastSource ?? this.lastSource,
    );
  }

  Map<String, dynamic> toJson() => {
    'deliveryId': deliveryId,
    'enteredByName': enteredByName,
    'enteredByEmail': enteredByEmail,
    'sources': sources,
    'lastStoreId': lastStoreId,
    'lastSource': lastSource,
  };

  factory DeliverySessionState.fromJson(Map<String, dynamic> json) {
    return DeliverySessionState(
      deliveryId: json['deliveryId'],
      enteredByName: json['enteredByName'],
      enteredByEmail: json['enteredByEmail'],
      sources: (json['sources'] as List<dynamic>? ?? []).cast<String>(),
      lastStoreId: json['lastStoreId'],
      lastSource: json['lastSource'],
    );
  }

  @override
  String toString() => jsonEncode(toJson());

  bool get isActive => deliveryId != null && deliveryId!.isNotEmpty;
}
