import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/screens/auth/forgot_password_screen.dart';
import 'package:grihsetu/screens/auth/signup_screen.dart';
import 'package:grihsetu/screens/dev/widget_gallery.dart';
import 'package:grihsetu/widgets/audit_timeline.dart';
import 'package:grihsetu/widgets/empty_state.dart';

void main() {
  testWidgets('forgot password validates the email before sending', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Check your inbox'), findsNothing);
  });

  testWidgets('sign-up requires acceptance of terms', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(
      find.text('Please accept the Terms and Privacy Policy to continue.'),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });

  testWidgets('audit timeline renders one event', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AuditTimeline(events: [_event(0)])),
      ),
    );
    expect(find.text('Event 0'), findsOneWidget);
    expect(find.text('Actor 0 · Technician'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('audit timeline renders five events and elapsed time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AuditTimeline(events: List.generate(5, _event)),
          ),
        ),
      ),
    );
    for (var index = 0; index < 5; index++) {
      expect(find.text('Event $index'), findsOneWidget);
    }
    expect(find.text('1h between events'), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty state renders message and optional action', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'All caught up',
            message: 'New updates will appear here.',
            actionLabel: 'Refresh',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('New updates will appear here.'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    expect(tapped, isTrue);
  });

  testWidgets('widget gallery fits common web widths and text scale', (
    tester,
  ) async {
    for (final width in [360.0, 768.0, 1280.0]) {
      for (final brightness in Brightness.values) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const WidgetGalleryScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width brightness=$brightness',
        );
      }
    }
    await tester.binding.setSurfaceSize(null);
  });
}

AuditEvent _event(int index) => AuditEvent(
  title: 'Event $index',
  actor: 'Actor $index',
  role: 'Technician',
  timestamp: DateTime(2026, 10, 7, 10 + index),
  note: index == 2
      ? 'A note that may wrap across multiple lines without overflowing.'
      : null,
);
