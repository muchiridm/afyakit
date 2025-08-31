import 'package:flutter/material.dart';
import 'package:afyakit/core/auth_users/widgets/user_badge.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;

  const ScreenHeader(
    this.title, {
    super.key,
    this.onBack,
    this.trailing,
    this.showBack = true,
  });

  static const double _shrinkBreakpoint = 540; // tweak as needed

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final shouldStack = screenWidth < _shrinkBreakpoint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: shouldStack
          // ─────────────────────────────────────────────────────────────
          // NARROW: stack + WRAP so content never overflows horizontally
          // ─────────────────────────────────────────────────────────────
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack ?? () => Navigator.of(context).pop(),
                    ),
                  ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // <-- this used to be a Row; switch to Wrap so it can flow to the next line
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const UserBadge(),
                    if (trailing != null) trailing!,
                  ],
                ),
              ],
            )
          // ─────────────────────────────────────────────────────────────
          // WIDE: title centered with ellipsis, trailing cluster shrinks if necessary
          // ─────────────────────────────────────────────────────────────
          : Row(
              children: [
                if (showBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                  )
                else
                  const SizedBox(width: 48),
                const SizedBox(width: 8),
                // Center title; let it ellipsize instead of pushing out trailing
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Trailing cluster: Flexible + FittedBox keeps it within bounds
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const UserBadge(),
                          if (trailing != null) ...[
                            const SizedBox(width: 16),
                            trailing!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
