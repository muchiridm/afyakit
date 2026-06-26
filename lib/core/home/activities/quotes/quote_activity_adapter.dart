// lib/core/home/widgets/shared/activities/quote_activity_adapter.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/home/models/activity_entry.dart';
import 'package:afyakit/core/home/activities/shared/activity_event_tile.dart';
import 'package:afyakit/core/home/activities/shared/activity_time_format.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';

typedef QuoteActivityTapBuilder = VoidCallback? Function(ZohoQuote quote);

class QuoteActivityAdapter {
  const QuoteActivityAdapter._();

  static final NumberFormat _moneyFmt = NumberFormat('#,##0.##');

  /// Backwards-compatible alias.
  ///
  /// Use [fromQuotes] going forward. Drafts are now important activity because
  /// they represent editable quote requests.
  static List<ActivityEntry> fromSubmittedQuotes(
    List<ZohoQuote> quotes, {
    QuoteActivityTapBuilder? onTapForQuote,
  }) {
    return fromQuotes(quotes, onTapForQuote: onTapForQuote);
  }

  static List<ActivityEntry> fromQuotes(
    List<ZohoQuote> quotes, {
    QuoteActivityTapBuilder? onTapForQuote,
  }) {
    return [
      for (final quote in quotes.where(_isActivityQuote))
        ActivityEntry(
          date: _quoteActivityDate(quote),
          widget: ActivityEventTile(
            icon: _quoteIcon(quote),
            title: '${_activityTitlePrefix(quote)} • ${_quoteLabel(quote)}',
            subtitle: _quoteSubtitle(quote),
            timestamp: activityDateLabel(
              label: _activityDateLabel(quote),
              date: _quoteActivityDate(quote),
            ),
            onTap: onTapForQuote?.call(quote),
          ),
        ),
    ];
  }

  static bool _isActivityQuote(ZohoQuote quote) {
    final status = quote.status.trim().toLowerCase();

    return status.isEmpty ||
        status == 'draft' ||
        status == 'sent' ||
        status == 'accepted' ||
        status == 'declined' ||
        status == 'expired' ||
        status == 'invoiced' ||
        status == 'converted';
  }

  static bool isDraft(ZohoQuote quote) {
    return quote.status.trim().toLowerCase() == 'draft';
  }

  static bool isLockedForMember(ZohoQuote quote) {
    final status = quote.status.trim().toLowerCase();

    return status == 'sent' ||
        status == 'accepted' ||
        status == 'declined' ||
        status == 'expired' ||
        status == 'invoiced' ||
        status == 'converted';
  }

  static bool isConvertedOrInvoiced(ZohoQuote quote) {
    final status = quote.status.trim().toLowerCase();

    return status == 'invoiced' || status == 'converted';
  }

  static DateTime _quoteActivityDate(ZohoQuote quote) {
    return quote.date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static IconData _quoteIcon(ZohoQuote quote) {
    final status = quote.status.trim().toLowerCase();

    return switch (status) {
      'draft' => Icons.edit_note_outlined,
      'sent' => Icons.outgoing_mail,
      'accepted' => Icons.check_circle_outline,
      'declined' => Icons.cancel_outlined,
      'expired' => Icons.schedule_outlined,
      'invoiced' => Icons.receipt_long_outlined,
      'converted' => Icons.receipt_long_outlined,
      _ => Icons.request_quote_outlined,
    };
  }

  static String _activityTitlePrefix(ZohoQuote quote) {
    final status = quote.status.trim().toLowerCase();

    return switch (status) {
      'draft' => 'Quote request',
      'sent' => 'Quote submitted',
      'accepted' => 'Quote accepted',
      'declined' => 'Quote declined',
      'expired' => 'Quote expired',
      'invoiced' => 'Quote invoiced',
      'converted' => 'Quote converted',
      _ => 'Quote',
    };
  }

  static String _activityDateLabel(ZohoQuote quote) {
    final status = quote.status.trim().toLowerCase();

    return switch (status) {
      'draft' => 'Draft date',
      'sent' => 'Submitted',
      'accepted' => 'Accepted',
      'declined' => 'Declined',
      'expired' => 'Expired',
      'invoiced' => 'Invoiced',
      'converted' => 'Converted',
      _ => 'Quote date',
    };
  }

  static String _quoteLabel(ZohoQuote quote) {
    final accountNumber = (quote.accountNumber ?? '').trim();
    if (accountNumber.isNotEmpty) return accountNumber;

    final quoteId = quote.quoteId.trim();
    if (quoteId.isNotEmpty) return quoteId;

    return 'Quote';
  }

  static String _quoteSubtitle(ZohoQuote quote) {
    final parts = <String>[];

    final status = quote.status.trim();
    if (status.isNotEmpty) {
      parts.add(_statusLabel(status));
    } else {
      parts.add('Draft');
    }

    final customer = quote.customerName.trim();
    if (customer.isNotEmpty) {
      parts.add(customer);
    }

    final amount = _amountLabel(quote);
    if (amount.isNotEmpty) {
      parts.add(amount);
    }

    final helper = _helperLabel(quote);
    if (helper.isNotEmpty) {
      parts.add(helper);
    }

    return parts.join(' • ');
  }

  static String _helperLabel(ZohoQuote quote) {
    final status = quote.status.trim().toLowerCase();

    return switch (status) {
      'draft' => 'Editable',
      'sent' => 'Locked for member',
      'accepted' => 'Locked',
      'declined' => 'Closed',
      'expired' => 'Closed',
      'invoiced' => 'Converted to invoice',
      'converted' => 'Converted to invoice',
      _ => '',
    };
  }

  static String _amountLabel(ZohoQuote quote) {
    final total = quote.total;
    if (total <= 0) return '';

    final currency = (quote.currencyCode ?? '').trim();

    if (currency.isEmpty) {
      return _moneyFmt.format(total);
    }

    return '$currency ${_moneyFmt.format(total)}';
  }

  static String _statusLabel(String status) {
    final clean = status.trim().toLowerCase();

    return switch (clean) {
      'draft' => 'Draft',
      'sent' => 'Sent',
      'accepted' => 'Accepted',
      'declined' => 'Declined',
      'expired' => 'Expired',
      'invoiced' => 'Invoiced',
      'converted' => 'Converted',
      _ => status,
    };
  }
}
