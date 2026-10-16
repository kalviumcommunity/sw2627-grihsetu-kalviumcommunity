import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/widgets/complaint_chips.dart';

Widget _buildWrapper({
  required Widget child,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  double? width,
}) {
  final theme = brightness == Brightness.light
      ? AppTheme.light(webFonts: false)
      : AppTheme.dark(webFonts: false);

  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ComplaintStatusChip', () {
    testWidgets('renders displayLabel for all 8 ComplaintStatus values', (
      tester,
    ) async {
      for (final status in ComplaintStatus.values) {
        await tester.pumpWidget(
          _buildWrapper(child: ComplaintStatusChip(status: status)),
        );

        expect(
          find.text(status.displayLabel),
          findsOneWidget,
          reason: 'Status ${status.name} must render ${status.displayLabel}',
        );
        expect(
          find.byIcon(ComplaintStatusChip.iconFor(status)),
          findsOneWidget,
        );
      }
    });

    test('exposes tone and icon mappings for every status', () {
      for (final status in ComplaintStatus.values) {
        final (tone, icon) = ComplaintStatusChip.visualProperties(status);
        expect(tone, equals(ComplaintStatusChip.toneFor(status)));
        expect(icon, equals(ComplaintStatusChip.iconFor(status)));
        expect(icon, isNotNull);
      }

      expect(
        ComplaintStatusChip.toneFor(ComplaintStatus.resolved),
        StatusBadgeTone.success,
      );
      expect(
        ComplaintStatusChip.toneFor(ComplaintStatus.waitingForParts),
        StatusBadgeTone.warning,
      );
      expect(
        ComplaintStatusChip.toneFor(ComplaintStatus.reopened),
        StatusBadgeTone.danger,
      );
      expect(
        ComplaintStatusChip.toneFor(ComplaintStatus.cancelled),
        StatusBadgeTone.danger,
      );
    });

    testWidgets('fromValue parses valid and unknown persisted values safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: ComplaintStatusChip.fromValue('waiting_for_parts'),
        ),
      );
      expect(find.text('Waiting for Parts'), findsOneWidget);

      await tester.pumpWidget(
        _buildWrapper(
          child: ComplaintStatusChip.fromValue(
            'unknown_legacy_status',
            fallback: ComplaintStatus.open,
          ),
        ),
      );
      expect(find.text('Open'), findsOneWidget);

      await tester.pumpWidget(
        _buildWrapper(
          child: ComplaintStatusChip.fromValue(
            null,
            fallback: ComplaintStatus.assigned,
          ),
        ),
      );
      expect(find.text('Assigned'), findsOneWidget);
    });

    testWidgets('renders in light and dark themes without exceptions', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          _buildWrapper(
            brightness: brightness,
            child: const ComplaintStatusChip(
              status: ComplaintStatus.inProgress,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('In Progress'), findsOneWidget);
      }
    });

    testWidgets('supports compact mode without exceptions', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: const ComplaintStatusChip(
            status: ComplaintStatus.resolved,
            compact: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Resolved'), findsOneWidget);
    });

    testWidgets('does not overflow at narrow widths or 2.0 text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(
          width: 90,
          textScale: 2.0,
          child: const ComplaintStatusChip(
            status: ComplaintStatus.waitingForParts,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ComplaintStatusChip), findsOneWidget);
    });

    testWidgets('ComplaintStatusBadge alias works identically', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: const ComplaintStatusBadge(status: ComplaintStatus.closed),
        ),
      );
      expect(find.text('Closed'), findsOneWidget);
      expect(find.byType(ComplaintStatusBadge), findsOneWidget);
    });
  });

  group('ComplaintPriorityChip', () {
    testWidgets('renders displayLabel for all 4 ComplaintPriority values', (
      tester,
    ) async {
      for (final priority in ComplaintPriority.values) {
        await tester.pumpWidget(
          _buildWrapper(child: ComplaintPriorityChip(priority: priority)),
        );

        expect(
          find.text(priority.displayLabel),
          findsOneWidget,
          reason:
              'Priority ${priority.name} must render ${priority.displayLabel}',
        );
        expect(
          find.byIcon(ComplaintPriorityChip.iconFor(priority)),
          findsOneWidget,
        );
      }
    });

    test('exposes tone and icon mappings for every priority', () {
      for (final priority in ComplaintPriority.values) {
        final (tone, icon) = ComplaintPriorityChip.visualProperties(priority);
        expect(tone, equals(ComplaintPriorityChip.toneFor(priority)));
        expect(icon, equals(ComplaintPriorityChip.iconFor(priority)));
        expect(icon, isNotNull);
      }

      expect(
        ComplaintPriorityChip.toneFor(ComplaintPriority.low),
        StatusBadgeTone.neutral,
      );
      expect(
        ComplaintPriorityChip.toneFor(ComplaintPriority.medium),
        StatusBadgeTone.accent,
      );
      expect(
        ComplaintPriorityChip.toneFor(ComplaintPriority.high),
        StatusBadgeTone.warning,
      );
      expect(
        ComplaintPriorityChip.toneFor(ComplaintPriority.urgent),
        StatusBadgeTone.danger,
      );
    });

    testWidgets('fromValue parses valid and unknown values safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(child: ComplaintPriorityChip.fromValue('urgent')),
      );
      expect(find.text('Urgent'), findsOneWidget);

      await tester.pumpWidget(
        _buildWrapper(
          child: ComplaintPriorityChip.fromValue(
            'super_urgent',
            fallback: ComplaintPriority.high,
          ),
        ),
      );
      expect(find.text('High'), findsOneWidget);

      await tester.pumpWidget(
        _buildWrapper(
          child: ComplaintPriorityChip.fromValue(
            null,
            fallback: ComplaintPriority.medium,
          ),
        ),
      );
      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('renders in light and dark themes without exceptions', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          _buildWrapper(
            brightness: brightness,
            child: const ComplaintPriorityChip(
              priority: ComplaintPriority.urgent,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Urgent'), findsOneWidget);
      }
    });

    testWidgets('supports compact mode without exceptions', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: const ComplaintPriorityChip(
            priority: ComplaintPriority.high,
            compact: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('does not overflow at narrow widths or 2.0 text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(
          width: 70,
          textScale: 2.0,
          child: const ComplaintPriorityChip(
            priority: ComplaintPriority.urgent,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ComplaintPriorityChip), findsOneWidget);
    });

    testWidgets('ComplaintPriorityBadge alias works identically', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: const ComplaintPriorityBadge(priority: ComplaintPriority.low),
        ),
      );
      expect(find.text('Low'), findsOneWidget);
      expect(find.byType(ComplaintPriorityBadge), findsOneWidget);
    });
  });

  group('ComplaintCategoryChip', () {
    testWidgets(
      'renders displayLabel and icon for all 8 ComplaintCategory values',
      (tester) async {
        for (final category in ComplaintCategory.values) {
          await tester.pumpWidget(
            _buildWrapper(child: ComplaintCategoryChip(category: category)),
          );

          expect(
            find.text(category.displayLabel),
            findsOneWidget,
            reason:
                'Category ${category.name} must render ${category.displayLabel}',
          );
          expect(
            find.byIcon(ComplaintCategoryChip.iconFor(category)),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('fromValue parses valid and unknown category strings safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(child: ComplaintCategoryChip.fromValue('plumbing')),
      );
      expect(find.text('Plumbing'), findsOneWidget);

      await tester.pumpWidget(
        _buildWrapper(
          child: ComplaintCategoryChip.fromValue(
            'roofing',
            fallback: ComplaintCategory.other,
          ),
        ),
      );
      expect(find.text('Other'), findsOneWidget);

      await tester.pumpWidget(
        _buildWrapper(
          child: ComplaintCategoryChip.fromValue(
            null,
            fallback: ComplaintCategory.electrical,
          ),
        ),
      );
      expect(find.text('Electrical'), findsOneWidget);
    });

    testWidgets('renders in light and dark themes without exceptions', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          _buildWrapper(
            brightness: brightness,
            child: const ComplaintCategoryChip(
              category: ComplaintCategory.security,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Security'), findsOneWidget);
      }
    });

    testWidgets('supports compact mode without exceptions', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: const ComplaintCategoryChip(
            category: ComplaintCategory.appliance,
            compact: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Appliance'), findsOneWidget);
    });

    testWidgets('does not overflow at narrow widths or 2.0 text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWrapper(
          width: 80,
          textScale: 2.0,
          child: const ComplaintCategoryChip(
            category: ComplaintCategory.commonArea,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ComplaintCategoryChip), findsOneWidget);
    });
  });
}
