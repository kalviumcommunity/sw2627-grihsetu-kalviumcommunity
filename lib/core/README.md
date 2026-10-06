# GrihSetu Shared Domain Layer (`lib/core`)

This module provides the shared domain foundations for GrihSetu, including type-safe enums, domain constants, lightweight models, and sample fixtures.

---

## 1. Using Enums & Display Labels

All enums provide `.displayLabel` for rendering human-readable text in the UI without magic strings or calling `.toString()`.

```dart
import 'package:grihsetu/core/enums/enums.dart';

// Accessing display labels
final status = ComplaintStatus.inProgress;
print(status.displayLabel); // "In Progress"

final priority = ComplaintPriority.urgent;
print(priority.displayLabel); // "Urgent"

final category = ComplaintCategory.plumbing;
print(category.displayLabel); // "Plumbing"

final role = UserRole.propertyOperations;
print(role.displayLabel); // "Property Operations"

final rentStatus = RentStatus.overdue;
print(rentStatus.displayLabel); // "Overdue"
```

---

## 2. Firebase / Firestore Serialization

Each enum provides a `.value` getter that produces a stable, machine-readable string, and static `tryFromValue()` / `fromValue()` methods to deserialize from Firestore documents safely.

```dart
// To Firestore map:
final data = {
  'status': ComplaintStatus.waitingForParts.value, // 'waiting_for_parts'
  'priority': ComplaintPriority.high.value,       // 'high'
};

// From Firestore document:
final status = ComplaintStatus.fromValue(data['status']); 
// => ComplaintStatus.waitingForParts
```

---

## 3. Using Lightweight Model Stubs

Models are immutable, type-safe, and contain `toMap()` and `fromMap()` helpers:

```dart
import 'package:grihsetu/core/models/models.dart';
import 'package:grihsetu/core/enums/enums.dart';

final complaint = Complaint(
  id: 'cmp_1001',
  tenantId: 'ten_001',
  propertyId: 'prop_001',
  unitId: 'unit_101',
  title: 'Leaking pipe under kitchen sink',
  description: 'Water leaking continuously into cabinet.',
  category: ComplaintCategory.plumbing,
  priority: ComplaintPriority.high,
  status: ComplaintStatus.assigned,
  currentTechnicianId: 'usr_tech_01',
  visitCount: 1,
  createdBy: 'usr_ops_01',
  createdAt: DateTime.now(),
);

// Check domain lifecycle logic
if (complaint.status.isUnresolved) {
  print('Complaint still requires action');
}

// Convert for Firestore
final firestoreMap = complaint.toMap();

// Reconstruct from Firestore document snapshot
final loadedComplaint = Complaint.fromMap(firestoreMap);
```

---

## 4. UI Fixtures for Prototyping

Import `SampleFixtures` to preview mock complaints, rent records, properties, and users without hardcoding test strings:

```dart
import 'package:grihsetu/core/fixtures/fixtures.dart';

final complaints = SampleFixtures.sampleComplaints;
final rentRecords = SampleFixtures.sampleRentRecords;
```
