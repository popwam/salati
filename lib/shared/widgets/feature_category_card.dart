import 'package:flutter/material.dart';

enum FeatureCategoryCardVariant { category, compact }

class FeatureCategoryCardGrid extends StatelessWidget {
  const FeatureCategoryCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _FeatureCategoryGridMetrics.fromWidth(
          constraints.maxWidth,
        );
        return GridView.builder(
          padding: metrics.padding,
          physics: const BouncingScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: metrics.spacing,
            mainAxisSpacing: metrics.spacing,
            mainAxisExtent: metrics.mainAxisExtent,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class FeatureCategoryCard extends StatelessWidget {
  const FeatureCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.locked = false,
    this.subtitleMaxLines = 2,
    this.footerLabel,
    this.variant = FeatureCategoryCardVariant.category,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool locked;
  final int subtitleMaxLines;
  final String? footerLabel;
  final FeatureCategoryCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = _FeatureCategoryCardTokens.fromTheme(theme, locked: locked);
    final metrics = _FeatureCategoryCardMetrics.fromVariant(variant);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: tokens.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: metrics.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: metrics.borderRadius,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: tokens.gradientColors,
            ),
            border: Border.all(color: tokens.borderColor),
            borderRadius: metrics.borderRadius,
          ),
          child: Padding(
            padding: metrics.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: metrics.iconBoxSize,
                  height: metrics.iconBoxSize,
                  decoration: BoxDecoration(
                    color: tokens.iconBackgroundColor,
                    borderRadius: BorderRadius.circular(metrics.iconRadius),
                  ),
                  child: Icon(
                    locked ? Icons.lock_outline_rounded : icon,
                    color: tokens.iconColor,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: metrics.subtitleSpacing),
                Text(
                  subtitle,
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (footerLabel != null) ...[
                  SizedBox(height: metrics.footerSpacing),
                  Text(
                    footerLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tokens.iconColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCategoryGridMetrics {
  const _FeatureCategoryGridMetrics({
    required this.padding,
    required this.spacing,
    required this.mainAxisExtent,
  });

  final EdgeInsets padding;
  final double spacing;
  final double mainAxisExtent;

  factory _FeatureCategoryGridMetrics.fromWidth(double width) {
    if (width < 360) {
      return const _FeatureCategoryGridMetrics(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 20),
        spacing: 10,
        mainAxisExtent: 176,
      );
    }
    return const _FeatureCategoryGridMetrics(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      spacing: 14,
      mainAxisExtent: 192,
    );
  }
}

class _FeatureCategoryCardMetrics {
  const _FeatureCategoryCardMetrics({
    required this.borderRadius,
    required this.contentPadding,
    required this.iconBoxSize,
    required this.iconRadius,
    required this.subtitleSpacing,
    required this.footerSpacing,
  });

  final BorderRadius borderRadius;
  final EdgeInsets contentPadding;
  final double iconBoxSize;
  final double iconRadius;
  final double subtitleSpacing;
  final double footerSpacing;

  factory _FeatureCategoryCardMetrics.fromVariant(
    FeatureCategoryCardVariant variant,
  ) {
    switch (variant) {
      case FeatureCategoryCardVariant.compact:
        return const _FeatureCategoryCardMetrics(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          contentPadding: EdgeInsets.all(16),
          iconBoxSize: 44,
          iconRadius: 14,
          subtitleSpacing: 4,
          footerSpacing: 8,
        );
      case FeatureCategoryCardVariant.category:
        return const _FeatureCategoryCardMetrics(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          contentPadding: EdgeInsets.all(20),
          iconBoxSize: 52,
          iconRadius: 18,
          subtitleSpacing: 6,
          footerSpacing: 12,
        );
    }
  }
}

class _FeatureCategoryCardTokens {
  const _FeatureCategoryCardTokens({
    required this.surfaceColor,
    required this.gradientColors,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
  });

  final Color surfaceColor;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;

  factory _FeatureCategoryCardTokens.fromTheme(
    ThemeData theme, {
    required bool locked,
  }) {
    final scheme = theme.colorScheme;
    return _FeatureCategoryCardTokens(
      surfaceColor: scheme.surface,
      gradientColors: [
        scheme.surface,
        (locked ? scheme.surfaceContainerHigh : scheme.surfaceContainerHighest)
            .withValues(alpha: 0.96),
      ],
      borderColor: locked
          ? scheme.outline.withValues(alpha: 0.22)
          : scheme.primary.withValues(alpha: 0.14),
      iconBackgroundColor: locked
          ? scheme.surfaceContainerHigh
          : scheme.primary.withValues(alpha: 0.12),
      iconColor: locked ? scheme.outline : scheme.primary,
    );
  }
}
