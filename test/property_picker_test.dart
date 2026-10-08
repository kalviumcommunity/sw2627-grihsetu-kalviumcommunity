import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/repositories/property_repository.dart';
import 'package:grihsetu/screens/property/property_browse_panels.dart';
import 'package:grihsetu/screens/property/property_selection_flow.dart';
import 'package:grihsetu/screens/property/property_view_models.dart';

void main() {
  testWidgets('unit search filters by unit number', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: UnitListPanel(
              units: [_unit('A-101'), _unit('B-204')],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'B-204');
    await tester.pump();
    expect(find.text('B-204'), findsNWidgets(2));
    expect(find.text('A-101'), findsNothing);
    expect(find.text('1 unit'), findsOneWidget);
  });

  testWidgets('picker returns the selected property, unit, and tenant', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final navigatorKey = GlobalKey<NavigatorState>();
    Future<PropertyUnitTenantSelection?>? result;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => result = PropertySelectionFlow.pick(
                  context,
                  repository: InMemoryPropertyRepository(
                    loadingDelay: Duration.zero,
                  ),
                ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pump();
    await _pumpAsyncLoads(tester);
    await tester.tap(find.text('Shanti Heights'));
    await tester.pump();
    await tester.tap(find.text('A-101'));
    await tester.pump();
    await tester.tap(find.text('Priya Patel'));
    await tester.pump();
    await tester.tap(find.text('Confirm selection'));
    await tester.pumpAndSettle();

    final selection = await result;
    expect(selection, isNotNull);
    expect(selection!.propertyId, 'prop_001');
    expect(selection.unitId, 'unit_101');
    expect(selection.tenantId, 'ten_001');
    expect(selection.propertyName, 'Shanti Heights');
    expect(selection.unitNumber, 'A-101');
    expect(selection.tenantName, 'Priya Patel');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('vacant unit cannot be selected when a tenant is required', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => PropertySelectionFlow.pick(
                  context,
                  repository: InMemoryPropertyRepository(
                    loadingDelay: Duration.zero,
                  ),
                ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pump();
    await _pumpAsyncLoads(tester);
    await tester.tap(find.text('Shanti Heights'));
    await tester.pump();
    await tester.tap(find.text('C-307'));
    await tester.pump();

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm selection'),
    );
    expect(confirm.onPressed, isNull);
    expect(find.text('Choose a unit to see its tenants.'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('empty units show an empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: UnitListPanel(units: const [], onSelected: _ignoreUnit),
          ),
        ),
      ),
    );
    expect(find.text('No units yet'), findsOneWidget);
  });

  testWidgets('picker layout has no overflow at target widths and themes', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    for (final width in [360.0, 768.0, 1280.0]) {
      for (final brightness in Brightness.values) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => PropertySelectionFlow.pick(
                      context,
                      repository: InMemoryPropertyRepository(
                        loadingDelay: Duration.zero,
                      ),
                    ),
                    child: const Text('Open picker'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open picker'));
        await tester.pump();
        await _pumpAsyncLoads(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width brightness=$brightness',
        );
        await tester.ensureVisible(find.text('Shanti Heights').first);
        await tester.tap(find.text('Shanti Heights').first);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'unit level width=$width',
        );
        await tester.ensureVisible(find.text('A-101').first);
        await tester.tap(find.text('A-101').first);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'tenant level width=$width',
        );
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
      }
    }
    await tester.binding.setSurfaceSize(null);
  });
}

UnitBrowseData _unit(String number) => UnitBrowseData(
  unit: Unit(
    id: number,
    propertyId: 'prop_001',
    unitNumber: number,
    floor: 1,
    tenantId: 'tenant',
  ),
  tenants: const [],
  openComplaints: 0,
  repeatComplaints: 0,
);

void _ignoreUnit(UnitBrowseData _) {}

Future<void> _pumpAsyncLoads(WidgetTester tester) async {
  for (var index = 0; index < 40; index++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
