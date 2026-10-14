import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/widgets/empty_state.dart';
import 'package:grihsetu/widgets/error_state.dart';
import 'package:grihsetu/widgets/skeleton_box.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders icon, title, and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing here',
              message: 'Check back later for updates.',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Check back later for updates.'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
      'action button appears only when both label and callback provided',
      (tester) async {
        var actionCount = 0;

        // Both provided -> button appears
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: Icons.add_circle_outline,
                title: 'Create first record',
                message: 'Get started by creating a new entry.',
                actionLabel: 'Create now',
                onAction: () => actionCount++,
              ),
            ),
          ),
        );

        expect(find.text('Create now'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);

        await tester.tap(find.text('Create now'));
        await tester.pump();
        expect(actionCount, equals(1));

        // Callback null -> button hidden
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: Icons.add_circle_outline,
                title: 'Create first record',
                message: 'Get started by creating a new entry.',
                actionLabel: 'Create now',
                onAction: null,
              ),
            ),
          ),
        );
        expect(find.byType(FilledButton), findsNothing);

        // Label null -> button hidden
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: Icons.add_circle_outline,
                title: 'Create first record',
                message: 'Get started by creating a new entry.',
                actionLabel: null,
                onAction: () {},
              ),
            ),
          ),
        );
        expect(find.byType(FilledButton), findsNothing);

        // Label empty -> button hidden
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: Icons.add_circle_outline,
                title: 'Create first record',
                message: 'Get started by creating a new entry.',
                actionLabel: '   ',
                onAction: () {},
              ),
            ),
          ),
        );
        expect(find.byType(FilledButton), findsNothing);
      },
    );

    testWidgets('factories render specialized semantics correctly', (
      tester,
    ) async {
      // noData factory
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              title: 'No complaints yet',
              message: 'All clear across properties.',
            ),
          ),
        ),
      );
      expect(find.text('No complaints yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);

      // noResults factory
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyState.noResults())),
      );
      expect(find.text('No results found'), findsOneWidget);
      expect(
        find.text('Try adjusting your search terms or active filters.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);

      // restricted factory
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyState.restricted())),
      );
      expect(find.text('Access restricted'), findsOneWidget);
      expect(
        find.text('You do not have permission to view this information.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      // compact factory
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState.compact(
              icon: Icons.history_toggle_off_outlined,
              title: 'No activity recorded yet',
              message: 'Timeline events will appear here.',
            ),
          ),
        ),
      );
      expect(find.text('No activity recorded yet'), findsOneWidget);
      expect(find.byIcon(Icons.history_toggle_off_outlined), findsOneWidget);
    });

    testWidgets(
      'wraps long copy without overflowing on narrow screens (320px to 390px)',
      (tester) async {
        for (final width in [320.0, 360.0, 390.0, 800.0]) {
          await tester.binding.setSurfaceSize(Size(width, 600));
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: EmptyState(
                  icon: Icons.assignment_late_outlined,
                  title: 'A very long operational title that might wrap onto multiple lines in mobile viewports',
                  message: 'This is an exceptionally descriptive message explaining the empty operational condition in comprehensive detail so we ensure text wraps safely without clipping or rendering flex overflows.',
                  actionLabel: 'A longer button label that needs safe wrapping',
                  onAction: () {},
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Failed at width $width',
          );
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });

  group('ErrorState', () {
    testWidgets('renders default title, message, and invokes retry on tap', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              message: 'Failed to load records from server.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('Failed to load records from server.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('custom title and retry label are displayed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              title: 'Sync failed',
              message: 'Could not sync complaints.',
              retryLabel: 'Try again',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sync failed'), findsOneWidget);
      expect(find.text('Could not sync complaints.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('retry button is absent when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorState(
              message: 'This action is not allowed.',
              onRetry: null,
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets(
      'protects against duplicate submission when isRetrying is true',
      (tester) async {
        var retryTaps = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorState(
                message: 'Loading failed.',
                onRetry: () => retryTaps++,
                isRetrying: true,
              ),
            ),
          ),
        );

        expect(find.text('Retrying...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verify the button is disabled
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);

        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(retryTaps, equals(0));
      },
    );

    testWidgets('factories render specialized error states', (tester) async {
      // connectivity
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorState.connectivity(onRetry: () {})),
        ),
      );
      expect(find.text('Unable to connect'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);

      // permission (no retry)
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ErrorState.permission())),
      );
      expect(find.text('Access restricted'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);

      // compact
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState.compact(
              message: 'Failed to update item.',
              onRetry: () {},
            ),
          ),
        ),
      );
      expect(find.text('Failed to update item.'), findsOneWidget);
    });

    testWidgets(
      'wraps long error messages safely on narrow screens (320px to 390px)',
      (tester) async {
        for (final width in [320.0, 360.0, 390.0, 800.0]) {
          await tester.binding.setSurfaceSize(Size(width, 600));
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ErrorState(
                  title: 'A verbose error title that requires wrapping on small screen form factors',
                  message: 'A very detailed user-friendly error message indicating that the connection was interrupted and advising the user on recovery steps without exposing raw Firebase exception traces or internals.',
                  onRetry: () {},
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Failed at width $width',
          );
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });

  group('SkeletonBox & SkeletonList', () {
    testWidgets('SkeletonBox renders requested dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonBox(width: 140, height: 28, borderRadius: 10),
          ),
        ),
      );

      final box = find.byType(SkeletonBox);
      expect(box, findsOneWidget);
      final size = tester.getSize(box);
      expect(size.width, equals(140));
      expect(size.height, equals(28));
    });

    testWidgets('SkeletonList renders requested item count and cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkeletonList(itemCount: 4, spacing: 12),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(SkeletonCard), findsNWidgets(4));
    });

    testWidgets(
      'SkeletonList does not overflow on narrow mobile screens (320px to 390px)',
      (tester) async {
        for (final width in [320.0, 360.0, 390.0, 800.0]) {
          await tester.binding.setSurfaceSize(Size(width, 700));
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: SkeletonList(itemCount: 3)),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Failed at width $width',
          );
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
