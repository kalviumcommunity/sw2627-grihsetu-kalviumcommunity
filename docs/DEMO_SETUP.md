# GrihSetu — Deterministic Demo Dataset, Staff Roles, and Reset Guide (GRIH-048)

This guide documents the reproducible demo scenario, staff account provisioning process, walkthrough checklist, and reset/reseed procedures for mentor evaluations and stakeholder reviews.

---

## 1. Architectural Overview & Data Boundaries

To avoid confusion during demonstrations, it is critical to understand the architecture and data boundaries of GrihSetu:

| Module / Domain | Data Persistence Mechanism | Demo Data Source | Reseed / Reset Method |
| :--- | :--- | :--- | :--- |
| **Properties & Units** | `InMemoryPropertyRepository` *(default local/dev)* or Cloud Firestore `properties`, `units` collections | `SampleFixtures.sampleProperties`, `SampleFixtures.sampleUnits` | In-memory: App restart.<br>Firestore: In-app Developer Tools (`ReferenceDataSeedScreen`). |
| **Tenants** | `InMemoryPropertyRepository` or Cloud Firestore `tenants` collection | `SampleFixtures.sampleTenants` | In-memory: App restart.<br>Firestore: `ReferenceDataSeedScreen`. |
| **Complaints & Timeline** | `InMemoryComplaintRepository` *(default local/dev)* or Cloud Firestore `complaints`, audit subcollections | `SampleFixtures.sampleComplaints` & generated audit events | In-memory: App restart.<br>Firestore: Live app actions by authorized staff. |
| **Maintenance Visits** | `InMemoryComplaintRepository` *(embedded)* or Cloud Firestore subcollections | `SampleFixtures.sampleMaintenanceVisits` | In-memory: App restart.<br>Firestore: Technician completes visit via `VisitStepperScreen`. |
| **Rent Collection & Follow-Ups** | `InMemoryRentRepository` *(per PRD & REPOSITORY_CONTRACTS.md; Firestore adapter planned in future sprint)* | `SampleFixtures.sampleRentRecords` + follow-up history entries | In-memory: App restart restores starting records and follow-ups. |
| **User Authentication** | Firebase Authentication (`auth`) | Provisioned via Firebase Console | Admin creates users in Firebase Console or Firebase CLI. |
| **Authoritative Roles** | Cloud Firestore `users/{uid}` profile document | Provisioned via Firestore Console or Admin SDK | Admin sets `role: "<role_string>"` in `users/{uid}`. |

> [!IMPORTANT]
> **Data Persistence Notice:**
> - Rent tracking and follow-up history run against `InMemoryRentRepository` by design. Do not claim or expect rent follow-ups to sync with Firestore in the current application release.
> - `SampleFixtures` are deterministic in-memory fixtures. Adding or editing fixtures does **not** create Firebase Auth accounts or remotely write to Firestore unless explicitly seeded using `ReferenceDataSeedService`.

---

## 2. Deterministic Demo Scenario (PRD Section 26)

The walkthrough scenario is centered on:

- **Property:** Green Heights (`prop_003`)
  - Address: Sector 45, Gurugram, Haryana 122003
  - Structure: 8 floors, 32 units total
- **Unit:** Flat A-204 (`unit_gh_204`)
  - Floor: 2, Block: A
  - Occupancy: `occupied`
- **Tenant:** Kabir Mehta (`ten_004`)
  - Phone: `+91 98111 20401`
  - Email: `kabir.mehta@example.com`
  - Assigned Unit: `unit_gh_204` at `prop_003`

### Linked Scenario Entities

```
Green Heights (prop_003)
 └── Flat A-204 (unit_gh_204)
      ├── Tenant: Kabir Mehta (ten_004)
      │
      ├── Complaint #1: cmp_2001 (Persistent kitchen pipe leakage under sink)
      │    ├── Status: REOPENED (reopenCount: 1, isRepeatVisit: true, visitCount: 2)
      │    ├── Assigned to: Aman Verma (usr_002, Technician)
      │    ├── Visit 1 (vis_2001_1): Waiting for Parts (damaged angle valve)
      │    ├── Visit 2 (vis_2001_2): Resolved (valve replaced & tested)
      │    ├── Closed by: Riya Sharma (usr_001, Complaint Operations)
      │    └── Reopened by: Riya Sharma (usr_001) upon recurring pressure leak
      │
      ├── Complaint #2: cmp_2002 (Exhaust fan vibrating noisily in kitchen)
      │    ├── Status: ASSIGNED (visitCount: 0)
      │    ├── Priority: MEDIUM
      │    └── Assigned to: Aman Verma (usr_002, Technician) — ready for active visit demo
      │
      └── Rent Record: rnt_3004 (October 2026, ₹35,000)
           ├── Status: PROMISED (Due Date: 2026-10-10)
           └── Follow-Up (flw_004): Method: Call, Outcome: Promised to Pay
                ├── Actor: Vikram Malhotra (usr_003, Property Operations)
                ├── Promised Date: 2026-10-08
                └── Note: Spoke with tenant Kabir Mehta. Traveling out of station; promised NEFT transfer upon return.
```

### Deterministic Timeline Chronology (Reference Date: Oct 6, 2026)

All demo dates are anchored to `demoReferenceDate = DateTime(2026, 10, 6, 12, 0)`:

| Timestamp | Entity | Actor | Event / Action |
| :--- | :--- | :--- | :--- |
| `2026-10-01 09:00` | `rnt_3004` | System | October 2026 Rent generated (₹35,000, due Oct 10). |
| `2026-10-03 10:15` | `cmp_2001` | Riya Sharma | Complaint created: "Persistent kitchen pipe leakage under sink". |
| `2026-10-03 10:45` | `cmp_2001` | Riya Sharma | Assigned to Technician Aman Verma (`usr_002`). |
| `2026-10-03 14:00` | `vis_2001_1` | Aman Verma | Visit #1 started. |
| `2026-10-03 15:30` | `vis_2001_1` | Aman Verma | Visit #1 completed: Outcome `waitingForParts` (angle valve damaged). |
| `2026-10-04 14:00` | `vis_2001_2` | Aman Verma | Visit #2 started (Repeat Visit). |
| `2026-10-04 16:15` | `vis_2001_2` | Aman Verma | Visit #2 completed: Outcome `resolved` (valve replaced, pressure tested). |
| `2026-10-05 09:30` | `cmp_2001` | Riya Sharma | Office verified repair with tenant and marked complaint `closed`. |
| `2026-10-05 14:00` | `flw_004` | Vikram Malhotra | Rent follow-up call recorded: tenant promised payment on Oct 8. |
| `2026-10-06 08:30` | `cmp_2002` | Riya Sharma | Complaint created: "Exhaust fan vibrating noisily in kitchen". |
| `2026-10-06 09:00` | `cmp_2002` | Riya Sharma | Assigned to Aman Verma (`usr_002`). |
| `2026-10-06 11:30` | `cmp_2001` | Riya Sharma | Tenant reports recurring leak under pressure; complaint **reopened** (`reopenCount: 1`). |

---

## 3. The Three Internal Staff Roles

GrihSetu implements strict role-based access control (RBAC). The demo walkthrough requires three separate internal accounts:

| Canonical Role (`UserRole`) | Serialized String | Recommended Demo Name | Recommended Placeholder Email | Demonstration Scope |
| :--- | :--- | :--- | :--- | :--- |
| `UserRole.propertyOperations` | `property_operations` | Vikram Malhotra | `vikram.m@grihsetu.com` | Property & unit directory (`PropertyBrowserScreen`), rent collection overview, rent follow-up recording, Developer Tools reference data seeding. |
| `UserRole.complaintOperations` | `complaint_operations` | Riya Sharma | `riya.sharma@grihsetu.com` | Operations dashboard, complaint creation, technician assignment, priority setting, reopening closed complaints, full audit trail inspection. |
| `UserRole.technician` | `technician` | Aman Verma | `aman.verma@grihsetu.com` | Assigned work queue (`TechnicianQueueScreen`), site visit execution (`VisitStepperScreen`), observation & photo capture, parts requirement logging, job resolution. |

---

## 4. Account Provisioning Procedure (Security Boundary)

> [!CAUTION]
> **Strict Security Boundary:**
> - Client applications **cannot** assign privileged roles. In `AuthService.signUp()`, any new account is created as an unassigned user (`UserRole.unassigned`) without administrative capabilities.
> - Firestore Security Rules (`firestore.rules`) permit profile reads by owner or staff, but prohibit users from modifying their own `role` field.
> - **Never** hardcode or commit passwords, API keys, or service-account JSON in Git.

Follow these steps to safely provision the demo accounts in your Firebase environment:

### Step 4.1: Create Accounts in Firebase Authentication
1. Open the [Firebase Console](https://console.firebase.google.com/) and navigate to your project.
2. Select **Authentication** > **Users** > **Add user**.
3. Create three separate accounts using strong development passwords:
   - `riya.sharma@grihsetu.com` (Complaint Operations)
   - `aman.verma@grihsetu.com` (Technician)
   - `vikram.m@grihsetu.com` (Property Operations)
4. Copy the unique User UID (`<UID>`) generated for each account.

### Step 4.2: Assign Trusted Role Profiles in Cloud Firestore
1. In the Firebase Console, navigate to **Firestore Database**.
2. Go to the `users` collection (or click **Start collection** > `users` if empty).
3. Create a document with Document ID equal to the respective Firebase Auth `<UID>`:

#### For Complaint Operations (`riya.sharma@grihsetu.com`):
```json
{
  "email": "riya.sharma@grihsetu.com",
  "name": "Riya Sharma",
  "phone": "+91 98765 43210",
  "role": "complaint_operations",
  "isActive": true,
  "createdAt": "2026-10-01T09:00:00Z"
}
```

#### For Technician (`aman.verma@grihsetu.com`):
```json
{
  "email": "aman.verma@grihsetu.com",
  "name": "Aman Verma",
  "phone": "+91 98765 43211",
  "role": "technician",
  "isActive": true,
  "createdAt": "2026-10-01T09:00:00Z"
}
```

#### For Property Operations (`vikram.m@grihsetu.com`):
```json
{
  "email": "vikram.m@grihsetu.com",
  "name": "Vikram Malhotra",
  "phone": "+91 98765 43212",
  "role": "property_operations",
  "isActive": true,
  "createdAt": "2026-10-01T09:00:00Z"
}
```

*(Optional CLI Alternative via Firebase Admin SDK script in an authorized CI/admin environment)*:
```javascript
// admin-seed.js (Run only in authorized administrative environment with service account)
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function setStaffRole(uid, email, name, role) {
  await db.collection('users').doc(uid).set({
    email,
    name,
    role,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
}
```

---

## 5. Walkthrough Execution Guide

### Option A: Local Fixture-Only Walkthrough (Zero Cloud Config Required)
If running locally without a live Firebase backend:
1. Run `flutter run`.
2. When the app launches, sign in or bypass with the desired role test environment.
3. The in-memory repositories automatically load `SampleFixtures.sampleProperties`, `SampleFixtures.sampleUnits`, `SampleFixtures.sampleTenants`, `SampleFixtures.sampleComplaints`, and `SampleFixtures.sampleRentRecords`.

### Option B: Cloud Firestore Walkthrough
If demonstrating against a connected Firebase project:
1. Sign in as **Vikram Malhotra** (`property_operations`).
2. Open the navigation drawer / user menu and select **Developer Tools** > **Seed Reference Data**.
3. Tap **Seed All Reference Data**.
   - This writes `Green Heights` (`prop_003`), `Flat A-204` (`unit_gh_204`), and tenant `Kabir Mehta` (`ten_004`) to Firestore with deterministic IDs.
   - The operation is completely idempotent: re-running it overwrites existing documents with identical keys without creating duplicate records.

---

## 6. Mentor Walkthrough Checklist

Use this checklist during the walkthrough to verify each requirement:

- [ ] **1. Multi-Role Authentication:**
  - Sign in as `riya.sharma@grihsetu.com` (`complaint_operations`) — verify access to dashboard and complaints.
  - Sign in as `aman.verma@grihsetu.com` (`technician`) — verify access to work queue.
  - Sign in as `vikram.m@grihsetu.com` (`property_operations`) — verify access to properties and rent.
- [ ] **2. Green Heights / Flat A-204 Context:**
  - Open Properties tab. Select **Green Heights**.
  - Verify address (Sector 45, Gurugram) and 32 total units.
  - Navigate to unit **A-204**. Verify tenant **Kabir Mehta** (`+91 98111 20401`).
- [ ] **3. Complaint Inspection & Repeat / Reopen Scenario:**
  - As Complaint Operations, open **Complaints** tab.
  - Select complaint `cmp_2001` (*"Persistent kitchen pipe leakage under sink"*).
  - Verify badge displays **REOPENED**.
  - Verify indicator displays **Repeat Visit: Yes** and **Visit Count: 2**.
  - In the Timeline / Activity tab, verify:
    - Visit 1 outcome: `Waiting for Parts` (damaged valve).
    - Visit 2 outcome: `Resolved` (valve replaced).
    - Status history: `CLOSED` then `REOPENED` with reason *"Recurring leakage under sink cabinet after valve replacement"*.
- [ ] **4. Active Technician Work Flow:**
  - As Technician Aman Verma, open **Work Queue**.
  - Inspect assigned complaint `cmp_2002` (*"Exhaust fan vibrating noisily in kitchen"*).
  - Tap **Start Visit** to show the 4-step `VisitStepperScreen`.
- [ ] **5. Rent Follow-Up History:**
  - As Property Operations, open the **Rent** collection screen.
  - Locate unit **A-204** / tenant **Kabir Mehta** (`rnt_3004`).
  - Verify status: **Promised** (₹35,000 due 2026-10-10).
  - Open detail view and verify recorded follow-up:
    - Method: Call
    - Outcome: Promised to Pay (₹35,000 on 2026-10-08)
    - Actor: Vikram Malhotra
    - Note: *"Spoke with tenant Kabir Mehta. Traveling out of station; promised NEFT transfer upon return."*

---

## 7. Repeatable Reset & Reseed Process

### In-Memory State Reset
To return all in-memory data (complaints, visits, rent follow-ups) to the clean demo starting state:
1. Completely close the Flutter application.
2. Relaunch via `flutter run`.
3. All repositories re-seed cleanly from `SampleFixtures`.

### Firestore Reference Data Reseed
If demo data was modified in Firestore and needs to be restored to the initial state:
1. Sign in as `vikram.m@grihsetu.com` (`property_operations`).
2. Navigate to **Developer Tools** > **Seed Reference Data**.
3. Tap **Seed All Reference Data**.
4. The service performs deterministic document sets (`SetOptions(merge: false)` on entity IDs `prop_003`, `unit_gh_204`, `ten_004`), restoring original fields without altering Firebase Auth users or unrelated collections.

> [!WARNING]
> **Production Guard:**
> Never execute seed operations against production Firebase projects. Verify your active environment via `flutter run -d <device> --dart-define=ENVIRONMENT=staging` or by checking the Firebase Project ID in `google-services.json` / `GoogleService-Info.plist`.

---

## 8. Verification & Test Commands

To validate that all demo fixtures, role mappings, relationship invariants, and consumer repositories are healthy:

```bash
# Run the dedicated demo dataset test suite
flutter test test/demo_dataset_test.dart

# Run reference data seed and model unit tests
flutter test test/reference_data_seed_test.dart test/models_test.dart

# Run complaint and rent repository contract tests
flutter test test/complaint_repository_test.dart test/rent_repository_test.dart test/rent_test.dart

# Run technician visit workflow and history tests
flutter test test/visit_workflow_test.dart test/visit_history_test.dart

# Run static code analysis
flutter analyze
```
