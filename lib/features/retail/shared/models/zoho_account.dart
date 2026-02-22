// lib/features/retail/shared/models/zoho_account.dart

import 'package:flutter/foundation.dart';
import 'package:afyakit/shared/utils/utils.dart';

@immutable
class ZohoAccount {
  const ZohoAccount({
    required this.accountId,
    required this.accountName,
    this.accountType,
    this.accountCode,
    this.currencyCode,
    this.isActive,
    this.balance,
  });

  final String accountId;
  final String accountName;

  final String? accountType;
  final String? accountCode;
  final String? currencyCode;
  final bool? isActive;
  final num? balance;

  factory ZohoAccount.fromJson(JsonMap json) {
    // keep it safe even if json is Map<String, dynamic>
    final j = json.cast<String, Object?>();

    // Required-ish fields (Zoho always has these; fallback to empty string if not)
    final id = readString(j['account_id'] ?? j['accountId'] ?? j['id']);
    final name = readString(j['account_name'] ?? j['accountName'] ?? j['name']);

    return ZohoAccount(
      accountId: id,
      accountName: name,
      accountType: readStringOrNull(j['account_type'] ?? j['accountType']),
      accountCode: readStringOrNull(j['account_code'] ?? j['accountCode']),
      currencyCode: readStringOrNull(j['currency_code'] ?? j['currencyCode']),
      isActive: readBool(j['is_active'] ?? j['isActive'] ?? j['active']),
      balance: j.containsKey('balance') ? readNum(j['balance']) : null,
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'account_id': accountId.trim(),
      'account_name': accountName.trim(),
      if ((accountType ?? '').trim().isNotEmpty)
        'account_type': accountType!.trim(),
      if ((accountCode ?? '').trim().isNotEmpty)
        'account_code': accountCode!.trim(),
      if ((currencyCode ?? '').trim().isNotEmpty)
        'currency_code': currencyCode!.trim(),
      if (isActive != null) 'is_active': isActive,
      if (balance != null) 'balance': balance,
    };
  }

  ZohoAccount copyWith({
    String? accountId,
    String? accountName,
    String? accountType,
    String? accountCode,
    String? currencyCode,
    bool? isActive,
    num? balance,
    bool clearAccountType = false,
    bool clearAccountCode = false,
    bool clearCurrencyCode = false,
    bool clearIsActive = false,
    bool clearBalance = false,
  }) {
    return ZohoAccount(
      accountId: (accountId ?? this.accountId).trim(),
      accountName: (accountName ?? this.accountName).trim(),
      accountType: clearAccountType ? null : (accountType ?? this.accountType),
      accountCode: clearAccountCode ? null : (accountCode ?? this.accountCode),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
      isActive: clearIsActive ? null : (isActive ?? this.isActive),
      balance: clearBalance ? null : (balance ?? this.balance),
    );
  }
}
