import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/user_role.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('role roots meet accessibility guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    const sizes = [Size(390, 844), Size(1280, 800)];
    const roles = [UserRole.tenant, UserRole.complaintOperations];
    final failures = <String>[];
    final guidelines = {
      'androidTapTarget': androidTapTargetGuideline,
      'iOSTapTarget': iOSTapTargetGuideline,
      'labeledTapTarget': labeledTapTargetGuideline,
      'textContrast': textContrastGuideline,
    };

    for (final role in roles) {
      for (final size in sizes) {
        for (final brightness in Brightness.values) {
          await pumpApp(tester, role: role, size: size, brightness: brightness);
          for (final guideline in guidelines.entries) {
            try {
              await expectLater(tester, meetsGuideline(guideline.value));
            } on TestFailure catch (error) {
              failures.add(
                '${role.value} | ${size.width.toInt()}x${size.height.toInt()} | ${brightness.name} | ${guideline.key} | $error',
              );
            }
          }

          for (final element in find.byType(IconButton).evaluate()) {
            final button = element.widget as IconButton;
            final iconLabel = button.icon is Icon
                ? (button.icon as Icon).semanticLabel
                : null;
            if ((button.tooltip == null || button.tooltip!.trim().isEmpty) &&
                (iconLabel == null || iconLabel.trim().isEmpty)) {
              failures.add(
                '${role.value} | ${size.width.toInt()}x${size.height.toInt()} | ${brightness.name} | icon-label | ${button.key ?? button.icon.runtimeType}',
              );
            }
          }
        }
      }
    }

    semantics.dispose();
    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print('role | size | theme | rule | failure\n${failures.join('\n')}');
    }
    expect(
      failures,
      isEmpty,
      reason: '${failures.length} accessibility failures',
    );
  });
}
