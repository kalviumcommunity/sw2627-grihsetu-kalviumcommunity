import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/widgets/stat_tile.dart';

void main() {
  group('StatTile (KPI Card)', () {
    testWidgets('renders title/label and value accurately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatTile(label: 'Open Complaints', value: '18'),
          ),
        ),
      );

      expect(find.text('Open Complaints'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('supports title alias constructor and getter', (tester) async {
      const tile = StatTile(title: 'Pending Follow-Ups', value: '7');

      expect(tile.title, 'Pending Follow-Ups');
      expect(tile.label, 'Pending Follow-Ups');

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: tile)));

      expect(find.text('Pending Follow-Ups'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders optional icon and delta text when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatTile(
              label: 'Active Work Orders',
              value: '42',
              delta: '4 completed today',
              icon: Icons.assignment_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Active Work Orders'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('4 completed today'), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    });

    testWidgets('tap callback fires when card is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatTile(
              label: 'Clickable KPI',
              value: '99',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(StatTile));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets(
      'existing usage without icon or callback remains valid and non-interactive',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatTile(
                label: 'Static KPI',
                value: '100',
                delta: 'No change',
              ),
            ),
          ),
        );

        expect(find.text('Static KPI'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.text('No change'), findsOneWidget);
      },
    );

    testWidgets(
      'extremely long values and labels do not cause layout overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(200, 300));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 150,
                  child: StatTile(
                    label: 'Very Long Label Description That Wraps Across Multiple Lines',
                    value: '₹999,999,999,999.00',
                    delta: 'Extremely long delta string with additional trend text',
                    icon: Icons.trending_up,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('₹999,999,999,999.00'), findsOneWidget);
      },
    );
  });
}
