import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/widgets/attention_list_tile.dart';
import 'package:grihsetu/widgets/status_badge.dart';

void main() {
  group('AttentionListTile', () {
    testWidgets('renders main title and supporting subtitle text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttentionListTile(
              title: 'Aman Verma',
              subtitle: 'Emerald Heights • Unit 402',
            ),
          ),
        ),
      );

      expect(find.text('Aman Verma'), findsOneWidget);
      expect(find.text('Emerald Heights • Unit 402'), findsOneWidget);
    });

    testWidgets('renders optional status and trailing content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttentionListTile(
              title: 'Riya Sharma',
              subtitle: 'Oakwood Towers • Unit 105',
              leadingIcon: Icons.phone_forwarded,
              statusLabel: 'Due today',
              statusTone: StatusBadgeTone.warning,
              trailingText: '10 Oct 2026',
              trailingIcon: Icons.chevron_right,
            ),
          ),
        ),
      );

      expect(find.text('Riya Sharma'), findsOneWidget);
      expect(find.text('Oakwood Towers • Unit 105'), findsOneWidget);
      expect(find.byIcon(Icons.phone_forwarded), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      expect(find.text('10 Oct 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tap callback fires when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttentionListTile(
              title: 'Interactive Item',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Interactive Item'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('urgent item applies semantic danger tone', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttentionListTile(
              title: 'Overdue Tenant',
              isUrgent: true,
              statusLabel: '5d overdue',
              leadingIcon: Icons.warning_amber_rounded,
            ),
          ),
        ),
      );

      final statusBadgeFinder = find.byType(StatusBadge);
      expect(statusBadgeFinder, findsOneWidget);
      final badge = tester.widget<StatusBadge>(statusBadgeFinder);
      expect(badge.tone, StatusBadgeTone.danger);
    });

    testWidgets('narrow screen (320px) renders without layout overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AttentionListTile(
                  title: 'Extremely Long Tenant Full Legal Name Here',
                  subtitle:
                      'Grand Splendour Residency Towers • Block C • Unit 1204',
                  leadingIcon: Icons.phone_forwarded,
                  statusLabel: '14d overdue',
                  isUrgent: true,
                  trailingText: 'Oct 2026',
                  trailingIcon: Icons.chevron_right,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('Extremely Long Tenant Full Legal Name Here'),
        findsOneWidget,
      );
    });
  });
}
