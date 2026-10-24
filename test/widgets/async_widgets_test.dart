import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/services/errors/app_failure.dart';
import 'package:grihsetu/services/errors/run_guarded.dart';
import 'package:grihsetu/widgets/async_button.dart';
import 'package:grihsetu/widgets/async_view.dart';
import 'package:grihsetu/widgets/error_state.dart';
import 'package:grihsetu/widgets/skeleton_box.dart';

void main() {
  group('AsyncView Widget Tests', () {
    testWidgets(
      'renders loading state with skeleton when Loadable is loading',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AsyncView<String>.fromLoadable(
                state: const Loadable<String>.loading(),
                builder: (context, data) => Text('Data: $data'),
              ),
            ),
          ),
        );

        expect(find.byType(SkeletonList), findsOneWidget);
        expect(find.textContaining('Data:'), findsNothing);
      },
    );

    testWidgets('renders data state when Loadable has data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<String>.fromLoadable(
              state: const Loadable<String>.data('Hello World'),
              builder: (context, data) => Text('Data: $data'),
            ),
          ),
        ),
      );

      expect(find.text('Data: Hello World'), findsOneWidget);
      expect(find.byType(SkeletonList), findsNothing);
    });

    testWidgets('renders empty state when data is empty list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<List<String>>.fromLoadable(
              state: const Loadable<List<String>>.data([]),
              isEmpty: (data) => data.isEmpty,
              emptyBuilder: (context) => const Text('No records found'),
              builder: (context, data) => Text('Count: ${data.length}'),
            ),
          ),
        ),
      );

      expect(find.text('No records found'), findsOneWidget);
      expect(find.textContaining('Count:'), findsNothing);
    });

    testWidgets('renders ErrorState with retry button for retryable failure', (
      tester,
    ) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncView<String>.fromLoadable(
              state: const Loadable<String>.error(NetworkFailure()),
              onRetry: () => retried = true,
              builder: (context, data) => Text('Data: $data'),
            ),
          ),
        ),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets(
      'renders ErrorState without retry button for non-retryable failure',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AsyncView<String>.fromLoadable(
                state: const Loadable<String>.error(
                  InvalidCredentialsFailure(),
                ),
                onRetry: () {},
                builder: (context, data) => Text('Data: $data'),
              ),
            ),
          ),
        );

        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );
  });

  group('AsyncButton Widget Tests', () {
    testWidgets('blocks double tap while executing async operation', (
      tester,
    ) async {
      final completer = Completer<void>();
      int taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncButton(
              onPressed: () async {
                taps++;
                await completer.future;
              },
              child: const Text('Submit'),
            ),
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);

      // Tap first time
      await tester.tap(find.text('Submit'));
      await tester.pump(); // Start async work

      expect(taps, equals(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap second time while first is still pending
      await tester.tap(find.byType(AsyncButton));
      await tester.pump();

      // Double tap must be blocked; tap count remains 1
      expect(taps, equals(1));

      // Complete the future
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Submit'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows mapped error snackbar on operation failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AsyncButton(
              onPressed: () async {
                throw const NetworkFailure();
              },
              child: const Text('Trigger Error'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      // Verify mapped error message appears in SnackBar
      expect(
        find.text(
          'Unable to connect to the network. Please check your internet connection.',
        ),
        findsOneWidget,
      );
    });
  });
}
