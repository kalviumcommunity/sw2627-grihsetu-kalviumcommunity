import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class KpiValue {
  const KpiValue({
    required this.label,
    required this.value,
    this.delta,
    this.deltaIsPositive = true,
  });

  final String label;
  final String value;
  final String? delta;
  final bool deltaIsPositive;
}

/// A single bordered KPI panel: four columns on wide screens, 2x2 on phones.
class KpiStrip extends StatelessWidget {
  const KpiStrip({super.key, required this.values});

  final List<KpiValue> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 600 ? 2 : values.length;
      final width = constraints.maxWidth / columns;
      final palette = context.palette;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Wrap(
            children: [
              for (var index = 0; index < values.length; index++)
                SizedBox(
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: index % columns == 0
                            ? BorderSide.none
                            : BorderSide(color: palette.border),
                        top: index < columns
                            ? BorderSide.none
                            : BorderSide(color: palette.border),
                      ),
                    ),
                    child: _KpiCell(value: values[index]),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({required this.value});

  final KpiValue value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.label,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 6),
          Text(
            value.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(color: palette.ink),
          ),
          if (value.delta != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  value.deltaIsPositive
                      ? Icons.trending_up
                      : Icons.trending_down,
                  size: 14,
                  color: value.deltaIsPositive
                      ? palette.success
                      : palette.danger,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value.delta!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: value.deltaIsPositive
                          ? palette.success
                          : palette.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
