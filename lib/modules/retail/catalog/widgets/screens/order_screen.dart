// lib/core/catalog/widgets/screens/quote_screen.dart

import 'package:afyakit/core/auth_user/guards/require_auth.dart';
import 'package:afyakit/modules/retail/catalog/controllers/order_controller.dart';
import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:afyakit/shared/widgets/screens/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _nf = NumberFormat.decimalPattern();

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(orderControllerProvider);
    final ctrl = ref.read(orderControllerProvider.notifier);
    final theme = Theme.of(context);

    return BaseScreen(
      scrollable: false,
      maxContentWidth: 900,
      header: const ScreenHeader(
        'Your order',
        // keep back arrow
        showBack: true,
        // tighten the header
        minHeight: 56,
        outerPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        // no user badge here to keep it compact
        showUserBadge: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quote.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your quote is empty. Add some items from the catalog.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: quote.lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.4),
                itemBuilder: (ctx, i) {
                  final line = quote.lines[i];
                  final tile = line.tile;
                  final price = tile.bestSellPrice;

                  final title = (tile.tileTitle?.trim().isNotEmpty ?? false)
                      ? tile.tileTitle!.trim()
                      : '${tile.brand} ${tile.strengthSig}'.trim();

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: title + form
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tile.form,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Middle: qty controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              tooltip: 'Decrease quantity',
                              onPressed: () =>
                                  ctrl.updateQty(tile, line.qty - 1),
                            ),
                            Text(
                              '${line.qty}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Increase quantity',
                              onPressed: () =>
                                  ctrl.updateQty(tile, line.qty + 1),
                            ),
                          ],
                        ),

                        // Right: line total
                        if (price != null) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: Text(
                              _nf.format(price * line.qty),
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

          if (quote.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estimated total:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _nf.format(quote.estimatedTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Submit order'),
                onPressed: () async {
                  if (quote.lines.isEmpty) return;

                  final ok = await requireAuth(context, ref);
                  if (!ok) return;

                  // TODO: submit to backend

                  ctrl.clear();
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Order submitted. We’ll contact you shortly.',
                      ),
                    ),
                  );
                  Navigator.of(context).maybePop();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
