import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// One quiet bordered surface for a related group of rows.
class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Padding(
                padding:
                    padding ??
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: children[index],
              ),
              if (index < children.length - 1)
                Divider(height: 1, thickness: 1, color: palette.border),
            ],
          ],
        ),
      ),
    );
  }
}
