import 'package:flutter/material.dart';

import '../../../../theme/app_palette.dart';

/// Shows an action sheet: modal bottom sheet on narrow screens (<900px)
/// or a 420px wide side dialog at >=900px.
Future<T?> showActionSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 900) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 420,
              height: double.infinity,
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(left: BorderSide(color: palette.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: builder(dialogContext),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => builder(sheetContext),
  );
}
