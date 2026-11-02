import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/user_role.dart';

import 'screen_catalog.dart';

void main() {
  test('screen catalog contains unique named states', () {
    expect(screenCatalog.length, greaterThanOrEqualTo(50));
    expect(
      screenCatalog.map((entry) => entry.name).toSet().length,
      screenCatalog.length,
    );
  });

  testWidgets('responsive role roots pass the catalog viewport matrix', (
    tester,
  ) async {
    const sizes = [
      Size(360, 640),
      Size(390, 844),
      Size(768, 1024),
      Size(1280, 800),
      Size(1920, 1080),
    ];
    const scales = [1.0, 1.3, 2.0];
    final failures = <String>[];
    final representatives = <UserRole, ScreenCatalogEntry>{
      for (final entry in screenCatalog) entry.role: entry,
    };

    for (final entry in representatives.values) {
      for (final size in sizes) {
        for (final brightness in Brightness.values) {
          for (final scale in scales) {
            await entry.setup(
              tester,
              size: size,
              textScale: scale,
              brightness: brightness,
            );
            final errors = <Object>[];
            while (true) {
              final error = tester.takeException();
              if (error == null) break;
              errors.add(error);
            }
            if (errors.isNotEmpty) {
              failures.add(
                '${entry.role.value} | ${size.width.toInt()}x${size.height.toInt()} | ${brightness.name} | $scale | ${errors.first}',
              );
            }
          }
        }
      }
    }

    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print('role | size | theme | scale | failure\n${failures.join('\n')}');
    }
    expect(failures, isEmpty, reason: '${failures.length} matrix failures');
  });
}
