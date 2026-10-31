import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/app/app.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/fixtures/sample_fixtures.dart';
import 'package:grihsetu/core/models/user.dart';
import 'package:grihsetu/repositories/complaint_store.dart';
import 'package:grihsetu/utils/app_clock.dart';

final _testNow = DateTime.utc(2026, 10, 6, 12);

ComplaintStore get harnessStore => ComplaintStore.instance;

Future<void> pumpApp(
  WidgetTester tester, {
  UserRole role = UserRole.tenant,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;

  AppClock.current = FixedClock(_testNow);
  ComplaintStore.resetInstance(
    ComplaintStore(
      initialComplaints: SampleFixtures.sampleComplaints,
      clock: AppClock.current,
    ),
  );

  addTearDown(() {
    ComplaintStore.resetInstance();
    AppClock.reset();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(
    GrihSetuApp(webFonts: false, profile: _profileFor(role)),
  );
  await settle(tester);
}

Future<void> settle(
  WidgetTester tester, {
  int pumps = 10,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < pumps; index++) {
    await tester.pump(step);
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.tap(target.first);
  await settle(tester);
}

Future<void> enterByLabel(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.widgetWithText(TextFormField, label);
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void expectNoOverflow(WidgetTester tester) {
  final errors = <Object>[];
  while (true) {
    final error = tester.takeException();
    if (error == null) break;
    errors.add(error);
  }
  final overflowErrors = errors.where(
    (error) => error.toString().contains('overflowed'),
  );
  expect(overflowErrors, isEmpty, reason: overflowErrors.join('\n'));
  expect(errors, isEmpty, reason: errors.join('\n'));
}

AppUser _profileFor(UserRole role) {
  for (final user in SampleFixtures.sampleUsers) {
    if (user.role == role) return user;
  }
  return AppUser(
    id: role == UserRole.tenant ? 'ten_004' : 'test_${role.value}',
    name: 'Test ${role.displayLabel}',
    email: '${role.value}@grihsetu.test',
    role: role,
    createdAt: _testNow,
  );
}
