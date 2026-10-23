import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/core/enums/complaint_priority.dart';
import 'package:grihsetu/core/enums/complaint_status.dart';
import 'package:grihsetu/core/enums/rent_status.dart';
import 'package:grihsetu/core/enums/tenant_status.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/models/complaint.dart';
import 'package:grihsetu/core/models/property.dart';
import 'package:grihsetu/core/models/rent_record.dart';
import 'package:grihsetu/core/models/tenant.dart';
import 'package:grihsetu/repositories/complaint_repository.dart';
import 'package:grihsetu/repositories/property_repository.dart';
import 'package:grihsetu/repositories/rent_repository.dart';
import 'package:grihsetu/repositories/tenant_repository.dart';
import 'package:grihsetu/screens/complaints/complaint_detail_screen.dart';
import 'package:grihsetu/screens/property/tenant_picker_screen.dart';
import 'package:grihsetu/screens/rent/rent_detail_screen.dart';
import 'package:grihsetu/screens/rent/rent_models.dart';
import 'package:grihsetu/screens/tenant/tenant_detail_context_screen.dart';

void main() {
  const sampleProperty = Property(
    id: 'prop_001',
    name: 'Green Valley Heights',
    address: 'Sector 48, Gurugram',
  );

  const sampleUnit = Unit(
    id: 'unit_101',
    propertyId: 'prop_001',
    unitNumber: 'A-101',
    floor: 1,
  );

  final sampleTenantFull = Tenant(
    id: 'ten_full',
    fullName: 'Vikram Malhotra',
    phone: '+91 98765 00000',
    email: 'vikram@example.com',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    status: TenantStatus.active,
    occupancyStart: DateTime(2025, 6, 1),
    occupancyEnd: DateTime(2026, 5, 31),
  );

  final sampleTenantSparse = Tenant(
    id: 'ten_sparse',
    fullName: 'Sparse Tenant',
    status: TenantStatus.pending,
  );

  final activeComplaint = Complaint(
    id: 'cmp_active_1',
    tenantId: 'ten_full',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    title: 'Leaking kitchen tap',
    description: 'Continuous dripping under the kitchen sink.',
    category: ComplaintCategory.plumbing,
    priority: ComplaintPriority.high,
    status: ComplaintStatus.open,
    createdBy: 'usr_staff',
    createdAt: DateTime(2026, 10, 1, 10, 0),
  );

  final reopenedComplaint = Complaint(
    id: 'cmp_reopened',
    tenantId: 'ten_full',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    title: 'Repeated MCB tripping',
    description: 'Circuit breaker trips when geyser is switched on.',
    category: ComplaintCategory.electrical,
    priority: ComplaintPriority.urgent,
    status: ComplaintStatus.reopened,
    reopenCount: 1,
    createdBy: 'usr_staff',
    createdAt: DateTime(2026, 10, 5, 14, 0),
  );

  final terminalResolvedComplaint = Complaint(
    id: 'cmp_resolved',
    tenantId: 'ten_full',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    title: 'Faulty door latch',
    description: 'Balcony door latch repaired and adjusted.',
    category: ComplaintCategory.structural,
    priority: ComplaintPriority.low,
    status: ComplaintStatus.resolved,
    createdBy: 'usr_staff',
    createdAt: DateTime(2026, 9, 20, 11, 0),
  );

  final terminalClosedComplaint = Complaint(
    id: 'cmp_closed',
    tenantId: 'ten_full',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    title: 'Intercom static noise',
    description: 'Rewired line terminal in hallway.',
    category: ComplaintCategory.security,
    priority: ComplaintPriority.medium,
    status: ComplaintStatus.closed,
    createdBy: 'usr_staff',
    createdAt: DateTime(2026, 9, 15, 9, 0),
  );

  final terminalCancelledComplaint = Complaint(
    id: 'cmp_cancelled',
    tenantId: 'ten_full',
    propertyId: 'prop_001',
    unitId: 'unit_101',
    title: 'Duplicate test ticket',
    description: 'Cancelled due to duplication.',
    category: ComplaintCategory.other,
    priority: ComplaintPriority.low,
    status: ComplaintStatus.cancelled,
    createdBy: 'usr_staff',
    createdAt: DateTime(2026, 9, 10, 8, 0),
  );

  final sampleRentWithFollowUps = RentItem(
    record: RentRecord(
      id: 'rnt_1',
      tenantId: 'ten_full',
      propertyId: 'prop_001',
      unitId: 'unit_101',
      month: 'October 2026',
      amountDue: 25000.0,
      dueDate: DateTime(2026, 10, 5),
      status: RentStatus.overdue,
    ),
    tenant: sampleTenantFull,
    property: sampleProperty,
    unit: sampleUnit,
    followUps: [
      RentFollowUp(
        id: 'flw_101',
        rentRecordId: 'rnt_1',
        method: FollowUpMethod.call,
        outcome: FollowUpOutcome.promisedToPay,
        actor: 'Riya Sharma',
        timestamp: DateTime(2026, 10, 6, 14, 30),
        note: 'Spoke with tenant; salary credited on 8th.',
        tenantResponse: 'Will transfer by October 9th morning.',
        promisedDate: DateTime(2026, 10, 9),
        promisedAmount: 25000.0,
        nextFollowUpDate: DateTime(2026, 10, 9),
      ),
    ],
  );

  final sampleRentWithoutFollowUps = RentItem(
    record: RentRecord(
      id: 'rnt_2',
      tenantId: 'ten_full',
      propertyId: 'prop_001',
      unitId: 'unit_101',
      month: 'September 2026',
      amountDue: 25000.0,
      dueDate: DateTime(2026, 9, 5),
      status: RentStatus.paid,
    ),
    tenant: sampleTenantFull,
    property: sampleProperty,
    unit: sampleUnit,
    followUps: const [],
    payments: [
      PaymentRecord(
        id: 'pay_1',
        rentRecordId: 'rnt_2',
        amount: 25000.0,
        date: DateTime(2026, 9, 4),
        mode: PaymentMode.upi,
        actor: 'Tenant Online',
      ),
    ],
  );

  Widget buildTestWidget({
    required Widget child,
    Size size = const Size(1000, 1200),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('GRIH-045 Tenant Detail Context Screen Tests', () {
    testWidgets(
      '1. Tenant name, phone, email, property, and unit render correctly with occupancy dates',
      (tester) async {
        final tenantRepo = InMemoryTenantRepository(
          initialTenants: [sampleTenantFull],
        );
        final propRepo = InMemoryPropertyRepository(
          loadingDelay: Duration.zero,
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              tenantRepository: tenantRepo,
              propertyRepository: propRepo,
              complaintRepository: InMemoryComplaintRepository(
                initialComplaints: const [],
              ),
              rentRepository: InMemoryRentRepository(
                simulatedDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tenant summary assertions
        expect(find.byKey(const Key('tenant_summary_card')), findsOneWidget);
        expect(find.text('Vikram Malhotra'), findsOneWidget);
        expect(find.text('ID: ten_full'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('+91 98765 00000'), findsOneWidget);
        expect(
          find.text('Shanti Heights · 12 Park Avenue, Sector 14, Gurugram'),
          findsOneWidget,
        );
        expect(find.text('Unit A-101'), findsOneWidget);
        expect(find.text('Occupancy'), findsOneWidget);
        expect(find.text('1 Jun 2025 – 31 May 2026'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Missing optional contact and location values render graceful fallback text without fabricating dates',
      (tester) async {
        final tenantRepo = InMemoryTenantRepository(
          initialTenants: [sampleTenantSparse],
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_sparse',
              tenantRepository: tenantRepo,
              complaintRepository: InMemoryComplaintRepository(
                initialComplaints: const [],
              ),
              rentRepository: InMemoryRentRepository(
                simulatedDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sparse Tenant'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('No phone provided'), findsOneWidget);
        expect(find.text('No email provided'), findsOneWidget);
        expect(find.text('Unassigned property'), findsOneWidget);
        expect(find.text('Unassigned unit'), findsOneWidget);
        // Occupancy row is not fabricated when missing
        expect(find.byKey(const Key('tenant_occupancy_text')), findsNothing);
      },
    );

    testWidgets(
      '3. Active and terminal complaints appear in the correct separate sections with counts and ordering',
      (tester) async {
        final allComplaints = [
          activeComplaint,
          terminalResolvedComplaint,
          terminalClosedComplaint,
          terminalCancelledComplaint,
        ];

        final complaintRepo = InMemoryComplaintRepository(
          initialComplaints: allComplaints,
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              complaintRepository: complaintRepo,
              rentRepository: InMemoryRentRepository(
                simulatedDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Section header counts
        expect(find.text('Active Complaints (1)'), findsOneWidget);
        expect(find.text('Historical Complaints (3)'), findsOneWidget);

        // Active complaint details
        expect(find.text('Leaking kitchen tap'), findsOneWidget);
        expect(
          find.text('Continuous dripping under the kitchen sink.'),
          findsOneWidget,
        );

        // Terminal complaints details
        expect(find.text('Faulty door latch'), findsOneWidget);
        expect(find.text('Intercom static noise'), findsOneWidget);
        expect(find.text('Duplicate test ticket'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Reopened complaint is classified as active, not historical',
      (tester) async {
        final complaintRepo = InMemoryComplaintRepository(
          initialComplaints: [reopenedComplaint, terminalResolvedComplaint],
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              complaintRepository: complaintRepo,
              rentRepository: InMemoryRentRepository(
                simulatedDelay: Duration.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Active Complaints (1)'), findsOneWidget);
        expect(find.text('Historical Complaints (1)'), findsOneWidget);

        // Reopened complaint is in active section
        expect(find.text('Repeated MCB tripping'), findsOneWidget);
        expect(find.text('Reopened'), findsOneWidget);
        expect(find.text('Faulty door latch'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Empty active complaints, empty historical complaints, and no rent records each show appropriate empty states',
      (tester) async {
        final complaintRepo = InMemoryComplaintRepository(
          initialComplaints: const [],
        );
        final rentRepo = FakeRentRepository(items: const []);

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              complaintRepository: complaintRepo,
              rentRepository: rentRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('tenant_active_complaints_empty')),
          findsOneWidget,
        );
        expect(find.text('No active complaints'), findsOneWidget);

        expect(
          find.byKey(const Key('tenant_historical_complaints_empty')),
          findsOneWidget,
        );
        expect(find.text('No past complaints'), findsOneWidget);

        expect(find.byKey(const Key('tenant_rent_empty')), findsOneWidget);
        expect(find.text('No rent records'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Rent records with follow-ups display the available history',
      (tester) async {
        final rentRepo = FakeRentRepository(items: [sampleRentWithFollowUps]);

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              rentRepository: rentRepo,
              referenceNow: DateTime(2026, 10, 10),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Rent item details
        expect(find.text('Rent & Follow-Up History (1)'), findsOneWidget);
        expect(find.text('October 2026'), findsOneWidget);
        expect(find.text('Amount due: ₹25,000'), findsOneWidget);
        expect(find.text('Overdue'), findsWidgets);

        // Follow-up history
        expect(find.text('Follow-up history (1)'), findsOneWidget);
        expect(find.text('Call'), findsOneWidget);
        expect(find.text('Promised to pay'), findsOneWidget);
        expect(
          find.text('Spoke with tenant; salary credited on 8th.'),
          findsOneWidget,
        );
        expect(
          find.text('Response: Will transfer by October 9th morning.'),
          findsOneWidget,
        );
        expect(find.text('Promised ₹25,000 by 9 Oct 2026'), findsOneWidget);
        expect(find.text('By Riya Sharma'), findsOneWidget);
      },
    );

    testWidgets(
      '7. Rent records without follow-ups show a follow-up-specific empty state',
      (tester) async {
        final rentRepo = FakeRentRepository(
          items: [sampleRentWithoutFollowUps],
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              rentRepository: rentRepo,
              referenceNow: DateTime(2026, 10, 10),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Rent record is displayed
        expect(find.text('September 2026'), findsOneWidget);
        expect(find.text('Amount due: ₹25,000'), findsOneWidget);

        // Follow-up specific empty state is rendered, NOT the "No rent records" empty state
        expect(find.byKey(const Key('rent_follow_ups_empty')), findsOneWidget);
        expect(find.text('No follow-up history'), findsOneWidget);
        expect(find.byKey(const Key('tenant_rent_empty')), findsNothing);
      },
    );

    testWidgets(
      '8. Tenant loading and section loading states render correctly',
      (tester) async {
        final delayedTenantRepo = InMemoryTenantRepository(
          simulatedDelay: const Duration(seconds: 10),
          initialTenants: [sampleTenantFull],
        );
        final delayedRentRepo = FakeRentRepository(
          delay: const Duration(seconds: 10),
          items: const [],
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              tenantRepository: delayedTenantRepo,
              rentRepository: delayedRentRepo,
            ),
          ),
        );
        // Advance slightly without settling
        await tester.pump();

        expect(find.byKey(const Key('tenant_summary_loading')), findsOneWidget);
        expect(find.byKey(const Key('tenant_rent_loading')), findsOneWidget);

        // Drain pending async timers before ending test
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '9. A failure in one section displays that section error and does not discard other loaded sections',
      (tester) async {
        final tenantRepo = InMemoryTenantRepository(
          initialTenants: [sampleTenantFull],
        );
        final failingRentRepo = FakeRentRepository(
          shouldFail: true,
          items: const [],
        );
        final complaintRepo = InMemoryComplaintRepository(
          initialComplaints: [activeComplaint],
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              tenantRepository: tenantRepo,
              rentRepository: failingRentRepo,
              complaintRepository: complaintRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tenant summary is successfully shown
        expect(find.text('Vikram Malhotra'), findsOneWidget);

        // Complaints are successfully shown
        expect(find.text('Leaking kitchen tap'), findsOneWidget);

        // Rent displays section-specific error
        expect(find.byKey(const Key('tenant_rent_error')), findsOneWidget);
        expect(find.text('Could not load rent history.'), findsOneWidget);
      },
    );

    testWidgets(
      '10. Retry triggers the appropriate repository reload for the failing section',
      (tester) async {
        final failingRentRepo = FakeRentRepository(
          shouldFail: true,
          items: [sampleRentWithFollowUps],
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              rentRepository: failingRentRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tenant_rent_error')), findsOneWidget);
        expect(find.text('October 2026'), findsNothing);

        // Fix failure condition and tap retry
        failingRentRepo.shouldFail = false;
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Now successfully displays rent records
        expect(find.byKey(const Key('tenant_rent_error')), findsNothing);
        expect(find.text('October 2026'), findsOneWidget);
      },
    );

    testWidgets(
      '11. Non-operational roles (technician, tenant) are restricted from accessing tenant context',
      (tester) async {
        // Technician role
        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              userRole: UserRole.technician,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('tenant_context_restricted')),
          findsOneWidget,
        );
        expect(find.text('Access restricted'), findsOneWidget);
        expect(find.text('Vikram Malhotra'), findsNothing);

        // Tenant role
        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              userRole: UserRole.tenant,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('tenant_context_restricted')),
          findsOneWidget,
        );
        expect(find.text('Access restricted'), findsOneWidget);
        expect(find.text('Vikram Malhotra'), findsNothing);
      },
    );

    testWidgets(
      '12. Tapping a complaint opens ComplaintDetailScreen, and tapping View rent details opens RentDetailScreen',
      (tester) async {
        final complaintRepo = InMemoryComplaintRepository(
          initialComplaints: [activeComplaint],
        );
        final rentRepo = FakeRentRepository(items: [sampleRentWithFollowUps]);

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantDetailContextScreen(
              tenantId: 'ten_full',
              initialTenant: sampleTenantFull,
              complaintRepository: complaintRepo,
              rentRepository: rentRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on active complaint card
        await tester.tap(find.text('Leaking kitchen tap'));
        await tester.pumpAndSettle();

        expect(find.byType(ComplaintDetailScreen), findsOneWidget);

        // Go back
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();

        // Tap View rent details
        await tester.ensureVisible(find.text('View rent details'));
        await tester.tap(find.text('View rent details'));
        await tester.pumpAndSettle();

        expect(find.byType(RentDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      '13. TenantPickerScreen onSelected navigates to TenantDetailContextScreen',
      (tester) async {
        final propRepo = InMemoryPropertyRepository(
          loadingDelay: Duration.zero,
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: TenantPickerScreen(
              property: sampleProperty,
              unit: sampleUnit,
              repository: propRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on tenant Priya Patel
        expect(find.text('Priya Patel'), findsOneWidget);
        await tester.tap(find.text('Priya Patel'));
        await tester.pumpAndSettle();

        // Navigates to TenantDetailContextScreen with tenantId 'ten_001'
        expect(find.byType(TenantDetailContextScreen), findsOneWidget);
        expect(find.text('Priya Patel'), findsWidgets);
      },
    );

    testWidgets(
      '14. RentDetailScreen tenant card action navigates to TenantDetailContextScreen',
      (tester) async {
        final rentRepo = FakeRentRepository(items: [sampleRentWithFollowUps]);

        await tester.pumpWidget(
          buildTestWidget(
            child: RentDetailScreen(
              item: sampleRentWithFollowUps,
              repository: rentRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap tenant context badge button
        expect(
          find.byKey(const Key('rent_view_tenant_context_button')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('rent_view_tenant_context_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TenantDetailContextScreen), findsOneWidget);
        expect(find.text('Vikram Malhotra'), findsWidgets);
      },
    );
  });
}

/// Fake [RentRepository] to control success, delay, and failures deterministically.
class FakeRentRepository implements RentRepository {
  FakeRentRepository({
    this.items = const [],
    this.delay = Duration.zero,
    this.shouldFail = false,
  });

  List<RentItem> items;
  Duration delay;
  bool shouldFail;

  @override
  Future<List<RentItem>> list({
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? month,
    RentStatus? status,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (shouldFail) throw StateError('Simulated rent repository failure');
    var results = items;
    if (tenantId != null && tenantId.isNotEmpty) {
      results = results.where((i) => i.record.tenantId == tenantId).toList();
    }
    return results;
  }

  @override
  Future<RentItem?> get(String id) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (shouldFail) throw StateError('Simulated failure');
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Future<RentItem> addFollowUp(RentFollowUp followUp) async {
    throw UnimplementedError();
  }

  @override
  Future<RentItem> markPaid(PaymentRecord payment) async {
    throw UnimplementedError();
  }
}
