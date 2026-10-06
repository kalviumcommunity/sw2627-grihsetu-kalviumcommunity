import '../enums/complaint_category.dart';
import '../enums/complaint_priority.dart';
import '../enums/complaint_status.dart';
import '../enums/rent_status.dart';
import '../enums/user_role.dart';
import '../models/complaint.dart';
import '../models/property.dart';
import '../models/rent_record.dart';
import '../models/tenant.dart';
import '../models/user.dart';

/// Centralized sample fixtures for UI development, testing, and mock states.
/// Eliminates magic strings and demonstrates type-safe domain models.
abstract final class SampleFixtures {
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
  ];

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
  ];

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
  ];

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
  ];

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
  ];
}
