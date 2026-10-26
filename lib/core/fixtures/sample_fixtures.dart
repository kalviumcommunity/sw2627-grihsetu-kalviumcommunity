import '../enums/complaint_category.dart';
import '../enums/complaint_priority.dart';
import '../enums/complaint_status.dart';
import '../enums/maintenance_visit_outcome.dart';
import '../enums/rent_status.dart';
import '../enums/user_role.dart';
import '../models/complaint.dart';
import '../models/maintenance_visit.dart';
import '../models/property.dart';
import '../models/rent_record.dart';
import '../models/tenant.dart';
import '../models/user.dart';

/// Centralized sample fixtures for UI development, testing, and mock states.
/// Eliminates magic strings and demonstrates type-safe domain models.
abstract final class SampleFixtures {
  /// Reference clock date used across demo fixtures for deterministic timelines.
  static final DateTime demoReferenceDate = DateTime(2026, 10, 6, 12, 0);

  // --- 1. Internal Demo Roles (Canonical Staff Identities) ---

  static final List<AppUser> sampleUsers = [
    AppUser(
      id: 'usr_001',
      name: 'Riya Sharma',
      email: 'riya.sharma@grihsetu.com',
      role: UserRole.complaintOperations,
      createdAt: DateTime(2026, 1, 15, 9, 30),
    ),
    AppUser(
      id: 'usr_002',
      name: 'Aman Verma',
      email: 'aman.verma@grihsetu.com',
      role: UserRole.technician,
      createdAt: DateTime(2026, 1, 18, 10, 0),
    ),
    AppUser(
      id: 'usr_003',
      name: 'Vikram Malhotra',
      email: 'vikram.m@grihsetu.com',
      role: UserRole.propertyOperations,
      createdAt: DateTime(2026, 1, 10, 8, 45),
    ),
  ];

  static AppUser get complaintOpsUser => sampleUsers[0];
  static AppUser get technicianUser => sampleUsers[1];
  static AppUser get propertyOpsUser => sampleUsers[2];

  // --- 2. Properties (including Green Heights demo property) ---

  static final List<Property> sampleProperties = [
    Property(
      id: 'prop_001',
      name: 'Shanti Heights',
      address: '12 Park Avenue, Sector 14, Gurugram',
      createdAt: DateTime(2025, 6, 1),
    ),
    Property(
      id: 'prop_002',
      name: 'Surya Residency',
      address: '45 MG Road, Indiranagar, Bengaluru',
      createdAt: DateTime(2025, 8, 15),
    ),
    // GRIH-048 / PRD Section 26 Demo Property
    Property(
      id: 'prop_003',
      name: 'Green Heights',
      address: 'Sector 62, Golf Course Extension Road, Gurugram',
      createdAt: DateTime(2025, 5, 20),
    ),
  ];

  static Property get demoGreenHeights => sampleProperties[2];

  // --- 3. Units (including Flat A-204 at Green Heights) ---

  static final List<Unit> sampleUnits = [
    const Unit(
      id: 'unit_101',
      propertyId: 'prop_001',
      unitNumber: 'A-101',
      floor: 1,
      tenantId: 'ten_001',
      occupancyStatus: 'occupied',
    ),
    const Unit(
      id: 'unit_204',
      propertyId: 'prop_001',
      unitNumber: 'B-204',
      floor: 2,
      tenantId: 'ten_002',
      occupancyStatus: 'occupied',
    ),
    const Unit(
      id: 'unit_402',
      propertyId: 'prop_002',
      unitNumber: 'C-402',
      floor: 4,
      tenantId: 'ten_003',
      occupancyStatus: 'occupied',
    ),
    // GRIH-048 / PRD Section 26 Demo Unit
    const Unit(
      id: 'unit_gh_204',
      propertyId: 'prop_003',
      unitNumber: 'A-204',
      floor: 2,
      tenantId: 'ten_004',
      occupancyStatus: 'occupied',
    ),
  ];

  static Unit get demoUnitA204 => sampleUnits[3];

  // --- 4. Tenants (including Kabir Mehta assigned to A-204) ---

  static final List<Tenant> sampleTenants = [
    const Tenant(
      id: 'ten_001',
      name: 'Priya Patel',
      phone: '+91 98765 43210',
      propertyId: 'prop_001',
      unitId: 'unit_101',
    ),
    const Tenant(
      id: 'ten_002',
      name: 'Rajesh Kumar',
      phone: '+91 98123 45678',
      propertyId: 'prop_001',
      unitId: 'unit_204',
    ),
    const Tenant(
      id: 'ten_003',
      name: 'Anita Desai',
      phone: '+91 99887 76655',
      propertyId: 'prop_002',
      unitId: 'unit_402',
    ),
    // GRIH-048 / PRD Section 26 Demo Tenant
    const Tenant(
      id: 'ten_004',
      name: 'Kabir Mehta',
      phone: '+91 98111 22334',
      propertyId: 'prop_003',
      unitId: 'unit_gh_204',
    ),
  ];

  static Tenant get demoTenant => sampleTenants[3];

  // --- 5. Complaints (including repeat visit / reopened scenario) ---

  static final List<Complaint> sampleComplaints = [
    Complaint(
      id: 'cmp_1001',
      tenantId: 'ten_001',
      propertyId: 'prop_001',
      unitId: 'unit_101',
      title: 'Leaking kitchen pipe under sink',
      description:
          'Continuous water leakage inside cabinet causing floor puddling.',
      category: ComplaintCategory.plumbing,
      priority: ComplaintPriority.high,
      status: ComplaintStatus.assigned,
      currentTechnicianId: 'usr_002',
      visitCount: 1,
      isRepeatVisit: false,
      reopenCount: 0,
      createdBy: 'usr_001',
      createdAt: DateTime(2026, 10, 5, 10, 15),
      firstAssignedAt: DateTime(2026, 10, 5, 10, 30),
    ),
    Complaint(
      id: 'cmp_1002',
      tenantId: 'ten_002',
      propertyId: 'prop_001',
      unitId: 'unit_204',
      title: 'Main circuit breaker tripping repeatedly',
      description: 'Tripping whenever AC and geyser are on simultaneously. Second occurrence this week.',
      category: ComplaintCategory.electrical,
      priority: ComplaintPriority.urgent,
      status: ComplaintStatus.inProgress,
      currentTechnicianId: 'usr_002',
      visitCount: 2,
      isRepeatVisit: true,
      reopenCount: 1,
      createdBy: 'usr_001',
      createdAt: DateTime(2026, 10, 3, 14, 0),
      firstAssignedAt: DateTime(2026, 10, 3, 14, 20),
      updatedAt: DateTime(2026, 10, 5, 11, 0),
    ),
    Complaint(
      id: 'cmp_1003',
      tenantId: 'ten_003',
      propertyId: 'prop_002',
      unitId: 'unit_402',
      title: 'Water heater heating element failure',
      description:
          'Geyser not heating water. Requires replacement heating coil.',
      category: ComplaintCategory.appliance,
      priority: ComplaintPriority.medium,
      status: ComplaintStatus.waitingForParts,
      currentTechnicianId: 'usr_002',
      visitCount: 1,
      isRepeatVisit: false,
      reopenCount: 0,
      createdBy: 'usr_003',
      createdAt: DateTime(2026, 10, 4, 9, 0),
      firstAssignedAt: DateTime(2026, 10, 4, 9, 45),
    ),
    Complaint(
      id: 'cmp_1004',
      tenantId: 'ten_001',
      propertyId: 'prop_001',
      unitId: 'unit_101',
      title: 'Intercom unit buzzing with no audio',
      description: 'Security intercom has high static interference. Fixed wiring terminal.',
      category: ComplaintCategory.security,
      priority: ComplaintPriority.low,
      status: ComplaintStatus.resolved,
      currentTechnicianId: 'usr_002',
      visitCount: 1,
      isRepeatVisit: false,
      reopenCount: 0,
      createdBy: 'usr_001',
      createdAt: DateTime(2026, 10, 1, 16, 20),
      firstAssignedAt: DateTime(2026, 10, 1, 16, 40),
      resolvedAt: DateTime(2026, 10, 2, 12, 10),
    ),
    // GRIH-048 / PRD Section 26 Demo Complaint 1: Repeat Visit & Reopened Case
    Complaint(
      id: 'cmp_2001',
      tenantId: 'ten_004',
      propertyId: 'prop_003',
      unitId: 'unit_gh_204',
      title: 'Persistent kitchen pipe leakage under sink',
      description: 'Continuous water leakage inside cabinet causing floor puddling. Reopened after previous pipe repair due to recurring leak under high pressure.',
      category: ComplaintCategory.plumbing,
      priority: ComplaintPriority.high,
      status: ComplaintStatus.reopened,
      currentTechnicianId: 'usr_002',
      visitCount: 2,
      isRepeatVisit: true,
      reopenCount: 1,
      reopenReason:
          'Recurring leakage under sink cabinet after valve replacement',
      reopenedAt: DateTime(2026, 10, 6, 11, 30),
      reopenedBy: 'usr_001',
      createdBy: 'usr_001',
      createdAt: DateTime(2026, 10, 3, 10, 15),
      firstAssignedAt: DateTime(2026, 10, 3, 10, 45),
      resolvedAt: DateTime(2026, 10, 4, 16, 30),
      closedAt: DateTime(2026, 10, 5, 9, 30),
      closedBy: 'usr_001',
      updatedAt: DateTime(2026, 10, 6, 11, 30),
    ),
    // GRIH-048 / PRD Section 26 Demo Complaint 2: Assigned Active Work for Technician Walkthrough
    Complaint(
      id: 'cmp_2002',
      tenantId: 'ten_004',
      propertyId: 'prop_003',
      unitId: 'unit_gh_204',
      title: 'Exhaust fan vibrating noisily in kitchen',
      description: 'Kitchen exhaust fan creating excessive vibration and rattling noise when turned on. Mounting bracket loose.',
      category: ComplaintCategory.electrical,
      priority: ComplaintPriority.medium,
      status: ComplaintStatus.assigned,
      currentTechnicianId: 'usr_002',
      visitCount: 0,
      isRepeatVisit: false,
      reopenCount: 0,
      createdBy: 'usr_001',
      createdAt: DateTime(2026, 10, 6, 8, 30),
      firstAssignedAt: DateTime(2026, 10, 6, 9, 0),
      updatedAt: DateTime(2026, 10, 6, 9, 0),
    ),
  ];

  static Complaint get demoReopenedComplaint => sampleComplaints[4];
  static Complaint get demoAssignedComplaint => sampleComplaints[5];

  // --- 6. Maintenance Visits for the Reopened Complaint ---

  static final List<MaintenanceVisit> sampleMaintenanceVisits = [
    MaintenanceVisit(
      id: 'vis_2001_1',
      complaintId: 'cmp_2001',
      technicianId: 'usr_002',
      visitNumber: 1,
      startedAt: DateTime(2026, 10, 3, 14, 0),
      completedAt: DateTime(2026, 10, 3, 15, 30),
      observation:
          'Damaged control angle valve with thread leaking under sink.',
      actionTaken: 'Applied temporary thread seal; replacement 0.5-inch brass angle valve required.',
      outcome: MaintenanceVisitOutcome.waitingForParts,
      isResolved: false,
      followUpRequired: true,
      followUpNotes: 'Need 0.5-inch angle brass valve for sink supply line.',
      resolutionSummary: null,
      operationId: 'op_vis_2001_1',
    ),
    MaintenanceVisit(
      id: 'vis_2001_2',
      complaintId: 'cmp_2001',
      technicianId: 'usr_002',
      visitNumber: 2,
      startedAt: DateTime(2026, 10, 4, 14, 0),
      completedAt: DateTime(2026, 10, 4, 16, 15),
      observation: 'Replacement angle valve parts received and verified.',
      actionTaken: 'Replaced defective angle valve and resealed fitting with PTFE tape. System pressure tested.',
      outcome: MaintenanceVisitOutcome.resolved,
      isResolved: true,
      followUpRequired: false,
      followUpNotes: null,
      resolutionSummary: 'Angle valve replaced successfully and tested for 30 minutes without leakage.',
      operationId: 'op_vis_2001_2',
    ),
  ];

  // --- 7. Rent Records (including Green Heights / A-204 Rent Record) ---

  static final List<RentRecord> sampleRentRecords = [
    RentRecord(
      id: 'rnt_3001',
      tenantId: 'ten_001',
      propertyId: 'prop_001',
      unitId: 'unit_101',
      month: 'October 2026',
      amountDue: 25000.0,
      dueDate: DateTime(2026, 10, 5),
      status: RentStatus.overdue,
      lastFollowUpAt: DateTime(2026, 10, 5, 11, 0),
      nextFollowUpAt: DateTime(2026, 10, 6, 10, 0),
    ),
    RentRecord(
      id: 'rnt_3002',
      tenantId: 'ten_002',
      propertyId: 'prop_001',
      unitId: 'unit_204',
      month: 'October 2026',
      amountDue: 32000.0,
      dueDate: DateTime(2026, 10, 5),
      status: RentStatus.promised,
      lastFollowUpAt: DateTime(2026, 10, 4, 15, 30),
      nextFollowUpAt: DateTime(2026, 10, 7, 10, 0),
    ),
    RentRecord(
      id: 'rnt_3003',
      tenantId: 'ten_003',
      propertyId: 'prop_002',
      unitId: 'unit_402',
      month: 'October 2026',
      amountDue: 28000.0,
      dueDate: DateTime(2026, 10, 5),
      status: RentStatus.paid,
      lastFollowUpAt: DateTime(2026, 10, 2, 17, 0),
    ),
    // GRIH-048 / PRD Section 26 Demo Rent Record
    RentRecord(
      id: 'rnt_3004',
      tenantId: 'ten_004',
      propertyId: 'prop_003',
      unitId: 'unit_gh_204',
      month: 'October 2026',
      amountDue: 35000.0,
      dueDate: DateTime(2026, 10, 10),
      status: RentStatus.promised,
      lastFollowUpAt: DateTime(2026, 10, 5, 14, 0),
      nextFollowUpAt: DateTime(2026, 10, 8, 10, 0),
    ),
  ];

  static RentRecord get demoRentRecord => sampleRentRecords[3];
}
