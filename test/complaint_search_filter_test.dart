import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/screens/complaints/search/complaint_search_screen.dart';
import 'package:grihsetu/utils/complaint_query.dart';
import 'package:grihsetu/widgets/complaint_card.dart';

void main() {
  final now = DateTime(2026, 3, 10, 12, 0);

  final c1 = Complaint(
    id: 'cmp_1',
    title: 'Water leakage in kitchen sink',
    description: 'Pipe is cracked underneath and leaking water',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.open,
    propertyId: 'prop_001',
    unitId: 'unit_101',
    tenantId: 'ten_001',
    currentTechnicianId: 'usr_002',
    createdBy: 'ten_001',
    createdAt: DateTime(2026, 3, 8, 10, 0),
    updatedAt: DateTime(2026, 3, 8, 11, 0),
    visitCount: 1,
    isRepeatVisit: false,
  );

  final c2 = Complaint(
    id: 'cmp_2',
    title: 'Electrical spark in main switch',
    description: 'Dangerous sparking in breaker box',
    category: ComplaintCategory.electrical,
    priority: ComplaintPriority.urgent,
    status: ComplaintStatus.assigned,
    propertyId: 'prop_001',
    unitId: 'unit_204',
    tenantId: 'ten_002',
    currentTechnicianId: null, // Unassigned
    createdBy: 'ten_002',
    createdAt: DateTime(2026, 3, 9, 10, 0),
    updatedAt: DateTime(2026, 3, 9, 10, 0),
    visitCount: 0,
    isRepeatVisit: false,
  );

  final c3 = Complaint(
    id: 'cmp_3',
    title: 'Door lock replacement',
    description: 'Lock latch is sticky and jammed',
    category: ComplaintCategory.security,
    priority: ComplaintPriority.low,
    status: ComplaintStatus.inProgress,
    propertyId: 'prop_002',
    unitId: 'unit_402',
    tenantId: 'ten_003',
    currentTechnicianId: 'usr_002',
    createdBy: 'ten_003',
    createdAt: DateTime(2026, 3, 10, 8, 0),
    updatedAt: DateTime(2026, 3, 10, 9, 0),
    visitCount: 2,
    isRepeatVisit: true,
  );

  final testComplaints = [c1, c2, c3];

  group('Ticket GRIH-035 Tests', () {
    test('applyFilter (word matching, AND/OR combination, the Unassigned technician filter, overdue boundary)', () {
      // 1. Word matching (all words required, case-insensitive, trimmed)
      final matchBoth = applyFilter(
        testComplaints,
        const ComplaintFilter(text: 'kitchen water'),
        now: now,
      );
      expect(matchBoth.map((c) => c.id), [c1.id]);

      final mismatchOneWord = applyFilter(
        testComplaints,
        const ComplaintFilter(text: 'kitchen electrical'),
        now: now,
      );
      expect(mismatchOneWord, isEmpty);

      // Matches by unit or tenant name lookup
      final matchUnit = applyFilter(
        testComplaints,
        const ComplaintFilter(text: 'A-101'),
        now: now,
      );
      expect(matchUnit.map((c) => c.id), [c1.id]);

      // 2. AND/OR combination:
      // Status in {open, assigned} (OR) AND Category in {plumbing} (AND)
      final andOrMatch = applyFilter(
        testComplaints,
        const ComplaintFilter(
          statuses: {ComplaintStatus.open, ComplaintStatus.assigned},
          categories: {ComplaintCategory.plumbing},
        ),
        now: now,
      );
      expect(andOrMatch.map((c) => c.id), [c1.id]);

      // 3. Unassigned technician filter
      final unassignedMatch = applyFilter(
        testComplaints,
        const ComplaintFilter(technicianId: 'Unassigned'),
        now: now,
      );
      expect(unassignedMatch.map((c) => c.id), [c2.id]);

      // 4. Overdue boundary:
      // c2 is urgent: SLA is 24h. Created at 2026-03-09 10:00.
      // At 2026-03-10 09:59 (23h 59m): NOT overdue.
      final beforeBoundary = applyFilter(
        [c2],
        const ComplaintFilter(overdueOnly: true),
        now: DateTime(2026, 3, 10, 9, 59),
      );
      expect(beforeBoundary, isEmpty);

      // At 2026-03-10 10:01 (24h 1m): overdue.
      final afterBoundary = applyFilter(
        [c2],
        const ComplaintFilter(overdueOnly: true),
        now: DateTime(2026, 3, 10, 10, 1),
      );
      expect(afterBoundary.map((c) => c.id), [c2.id]);

      // Resolved complaint is never overdue
      final resolvedC2 = c2.copyWith(status: ComplaintStatus.resolved);
      final resolvedAfterBoundary = applyFilter(
        [resolvedC2],
        const ComplaintFilter(overdueOnly: true),
        now: DateTime(2026, 3, 10, 10, 1),
      );
      expect(resolvedAfterBoundary, isEmpty);
    });

    test('each sort order', () {
      // Newest
      final newest = applyFilter(
        testComplaints,
        const ComplaintFilter(sort: ComplaintSort.newest),
        now: now,
      );
      expect(newest.map((c) => c.id), ['cmp_3', 'cmp_2', 'cmp_1']);

      // Oldest
      final oldest = applyFilter(
        testComplaints,
        const ComplaintFilter(sort: ComplaintSort.oldest),
        now: now,
      );
      expect(oldest.map((c) => c.id), ['cmp_1', 'cmp_2', 'cmp_3']);

      // Priority (urgent > high > medium > low)
      final byPriority = applyFilter(
        testComplaints,
        const ComplaintFilter(sort: ComplaintSort.priority),
        now: now,
      );
      expect(byPriority.map((c) => c.id), ['cmp_2', 'cmp_1', 'cmp_3']);

      // Last updated (newest updated first)
      final byLastUpdated = applyFilter(
        testComplaints,
        const ComplaintFilter(sort: ComplaintSort.lastUpdated),
        now: now,
      );
      expect(byLastUpdated.map((c) => c.id), ['cmp_3', 'cmp_2', 'cmp_1']);

      // Longest open (oldest created first)
      final longestOpen = applyFilter(
        testComplaints,
        const ComplaintFilter(sort: ComplaintSort.longestOpen),
        now: now,
      );
      expect(longestOpen.map((c) => c.id), ['cmp_1', 'cmp_2', 'cmp_3']);
    });

    test('activeCount and describe', () {
      const empty = ComplaintFilter();
      expect(empty.isEmpty, isTrue);
      expect(empty.activeCount, 0);
      expect(describe(empty), isEmpty);

      final filter = const ComplaintFilter(
        text: 'kitchen',
        statuses: {ComplaintStatus.open, ComplaintStatus.assigned},
        priorities: {ComplaintPriority.urgent},
        categories: {ComplaintCategory.plumbing},
        technicianId: 'Unassigned',
        repeatOnly: true,
        overdueOnly: true,
      );

      expect(filter.isEmpty, isFalse);
      expect(filter.activeCount, 8);

      final chips = describe(filter);
      expect(chips.length, 8);

      final labels = chips.map((c) => c.label).toSet();
      expect(labels.contains('Search: "kitchen"'), isTrue);
      expect(labels.contains('Open'), isTrue);
      expect(labels.contains('Assigned'), isTrue);
      expect(labels.contains('Urgent'), isTrue);
      expect(labels.contains('Plumbing'), isTrue);
      expect(labels.contains('Unassigned'), isTrue);
      expect(labels.contains('Repeat only'), isTrue);
      expect(labels.contains('Overdue only'), isTrue);

      // Verify removal
      final textChip = chips.firstWhere((c) => c.id == 'text');
      final withoutText = textChip.onRemove!(filter);
      expect(withoutText.text, isNull);
      expect(withoutText.activeCount, 7);
    });

    testWidgets(
      'the search screen narrows the list, shows the live count and the "No results" state, and Clear restores the list',
      (tester) async {
        final repo = InMemoryComplaintRepository(initialComplaints: [c1, c2]);

        await tester.pumpWidget(
          MaterialApp(
            home: ComplaintSearchScreen(repository: repo, showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial full count
        expect(find.text('2 of 2 complaints'), findsOneWidget);
        expect(find.byType(ComplaintCard), findsNWidgets(2));

        // 2. Narrow the list via search field with 250ms debounce
        await tester.enterText(find.byType(TextField), 'water');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('1 of 2 complaints'), findsOneWidget);
        expect(find.byType(ComplaintCard), findsOneWidget);
        expect(find.textContaining('Water leakage'), findsOneWidget);

        // 3. No results state
        await tester.enterText(find.byType(TextField), 'nonexistentquery');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('0 of 2 complaints'), findsOneWidget);
        expect(find.byType(ComplaintCard), findsNothing);
        expect(find.text('No results for "nonexistentquery"'), findsOneWidget);
        expect(find.text('Clear filters'), findsOneWidget);

        // 4. Clear restores the list
        await tester.tap(find.text('Clear filters'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('2 of 2 complaints'), findsOneWidget);
        expect(find.byType(ComplaintCard), findsNWidgets(2));
      },
    );

    testWidgets('an initial filter passed to the screen is applied', (
      tester,
    ) async {
      final repo = InMemoryComplaintRepository(initialComplaints: [c1, c2]);

      final initial = const ComplaintFilter(
        statuses: {ComplaintStatus.open},
        technicianId: 'usr_002',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ComplaintSearchScreen(
            repository: repo,
            initial: initial,
            showAppBar: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only c1 matches status: open & technician: usr_002
      expect(find.text('1 of 2 complaints'), findsOneWidget);
      expect(find.byType(ComplaintCard), findsOneWidget);
      expect(find.textContaining('Water leakage'), findsOneWidget);
    });
  });
}
