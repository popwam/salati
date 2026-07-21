import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';

class QuranLockedFeatureView extends StatelessWidget {
  const QuranLockedFeatureView({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamed(AppRouter.subscriptionsRoute);
                  },
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('عرض الترقية'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showQuranUpgradeSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(sheetContext).textTheme.bodyMedium),
            const SizedBox(height: 18),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(
                      context,
                    ).pushNamed(AppRouter.subscriptionsRoute);
                  },
                  child: const Text('عرض الباقات'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('لاحقاً'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
