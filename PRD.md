# GrihSetu
## Product Requirements Document (PRD)

**Product Name:** GrihSetu  
**Product Type:** Property Operations & Maintenance Management Mobile Application  
**Platform:** Cross-platform Mobile Application  
**Technology:** Flutter + Firebase  
**Primary Target:** Android  
**Document Version:** v1.1  
**Status:** Draft for Mentor Review  
**Sprint:** Kalvium Simulated Work Integration — Sprint 2  

---

# 1. Executive Summary

GrihSetu is a mobile application designed for property management firms that manage multiple residential buildings and coordinate tenant complaints, maintenance activities, technician visits, and rent follow-ups.

The current operational problem is not simply that complaints or rent records are stored inefficiently. The larger issue is that the **office team and field technicians do not share a common operational audit trail**.

Because information is fragmented:

- Complaints may return unresolved.
- The office may not know what happened during a technician's previous visit.
- Repeat technician visits may go unnoticed.
- Responsibility for unresolved complaints becomes unclear.
- Rent follow-ups may be missed or repeated without context.
- Management cannot reliably calculate complaint response and resolution times.
- Property owners cannot receive accurate performance information.

GrihSetu creates a single shared operational record for each complaint, maintenance visit, and rent follow-up.

Every important action is timestamped and attributable to a user so the organization can answer:

- Who handled the issue?
- What action was taken?
- When was the action taken?
- Was the problem actually resolved?
- Has this property already required previous visits?
- Why did the complaint return?
- How quickly did the team respond?
- How long did resolution take?
- What rent follow-ups have already occurred?

The MVP focuses on three operational roles:

1. **Property Operations**
2. **Complaint Operations**
3. **Technician Operations**

The central principle of GrihSetu is:

> **Every operational action should leave a trace.**

---

# 2. Problem Statement

A property management firm handles maintenance, rent follow-ups, and tenant complaints across several residential buildings, but field technicians and the office share no audit trail.

As a result:

- Complaints cycle back unresolved.
- Repeat technician visits go undetected.
- Previous technician actions are difficult to verify.
- Office staff do not have a reliable view of field activity.
- Rent follow-up history can become fragmented.
- Management cannot calculate accurate response and resolution times.
- Property owners cannot receive reliable operational reports.

The root problem is therefore:

> **The absence of a shared, structured and timestamped operational history between office staff and field technicians.**

GrihSetu must solve this traceability gap.

---

# 3. Product Vision

> **GrihSetu will create one shared source of truth for property operations by connecting tenant complaints, technician assignments, field visits, unresolved issues, rent follow-ups and performance metrics in a traceable mobile workflow.**

A property manager should be able to open any complaint and immediately understand:

- When the complaint was created.
- Who created it.
- Which technician was assigned.
- When the technician responded.
- How many visits occurred.
- What happened during every visit.
- Whether the problem was resolved.
- Whether it returned after resolution.
- Why another visit was required.
- How long the team took to respond.
- How long the team took to resolve it.

---

# 4. Product Goals

## Goal 1 — Build a Shared Audit Trail

The office and field technicians must work from the same complaint history.

Every important action must be traceable.

---

## Goal 2 — Prevent Complaints From Cycling Unresolved

Unresolved, reopened and follow-up-required complaints must remain visible until appropriately closed.

---

## Goal 3 — Detect Repeat Visits

The system must automatically identify when a complaint has required multiple technician visits.

---

## Goal 4 — Improve Technician Accountability

Each technician visit must clearly record:

- Who visited.
- When they visited.
- What they observed.
- What they did.
- Whether the issue was resolved.
- Whether another visit is required.

---

## Goal 5 — Track Rent Follow-Ups

The firm should be able to see:

- Which tenants require rent follow-up.
- What previous communication occurred.
- Who performed each follow-up.
- When the next follow-up is required.

---

## Goal 6 — Produce Reliable Operational Metrics

The firm should be able to calculate:

- First response time.
- Resolution time.
- Number of repeat visits.
- Open complaint volume.
- Reopened complaint volume.

These metrics can then be communicated accurately to property owners.

---

# 5. Non-Goals

GrihSetu is not intended to become a complete property management ERP during the sprint.

The following features are outside the MVP:

- Tenant-facing mobile application.
- Property-owner login portal.
- Online rent payment.
- Accounting or bookkeeping.
- Lease management.
- Automated invoice generation.
- Vendor billing.
- Inventory management.
- GPS technician tracking.
- AI complaint classification.
- AI technician assignment.
- Predictive maintenance.
- WhatsApp integration.
- SMS integration.
- Full web admin portal.
- Advanced financial reporting.

These features may be considered in future versions.

---

# 6. Key Stakeholders

## 6.1 Property Operations

Property Operations supervises the firm's overall activity across multiple buildings.

### Responsibilities

- Monitor complaints.
- Monitor unresolved issues.
- Track repeat visits.
- Track reopened complaints.
- Monitor rent follow-ups.
- Review operational performance.
- Review technician activity.
- Generate owner-ready performance information.

### Primary Need

> “I need to know what is happening across every property and whether my team is resolving issues properly and on time.”

---

# 6.2 Complaint Operations

Complaint Operations represents office staff receiving tenant complaints and coordinating resolution.

### Responsibilities

- Register complaints.
- Assign technicians.
- Monitor complaint progress.
- Review technician updates.
- Reassign complaints.
- Reopen complaints.
- Close resolved complaints.
- Search complaint history.

### Primary Need

> “When a complaint returns, I need to see exactly what happened previously instead of starting from zero.”

---

# 6.3 Technician Operations

Technicians perform maintenance work in the field.

### Responsibilities

- View assigned complaints.
- Read previous complaint history.
- Start visits.
- Record observations.
- Record work performed.
- Indicate resolution status.
- Request follow-up visits.
- Complete visits.

### Primary Need

> “Before arriving, I need to understand the complaint history, and after working I need a quick way to record exactly what happened.”

---

# 6.4 Tenant

Tenants report maintenance issues and may require rent follow-ups.

Tenants are stakeholders but will **not authenticate into the MVP**.

Their information will be maintained by office staff.

---

# 6.5 Property Owner

Property owners need reliable operational information concerning their buildings.

They may want information such as:

- Number of complaints.
- Unresolved complaints.
- Average response time.
- Average resolution time.
- Repeat visits.
- Frequently occurring maintenance issues.

Property owners will not require their own account in the MVP.

Instead, Property Operations will access owner-ready metrics and summaries.

---

# 7. Product Principles

## 7.1 Traceability

Important actions cannot happen invisibly.

---

## 7.2 Accountability

Every operational action should identify the responsible staff member.

---

## 7.3 Historical Context

Previous visits and actions must remain available.

---

## 7.4 Resolution Over Activity

The product must distinguish between:

- “A technician visited.”

and

- “The actual problem was resolved.”

A visit alone does not mean a complaint is resolved.

---

## 7.5 Visibility of Failure

Unresolved, reopened and repeatedly visited complaints should become **more visible**, not disappear deeper into the system.

---

## 7.6 Simplicity

A technician in the field should be able to update a visit in a small number of actions.

---

# 8. Core Product Modules

The MVP will contain the following modules:

| Module | Priority |
|---|---|
| Authentication | P0 |
| Role-Based Access | P0 |
| Complaint Management | P0 |
| Technician Assignment | P0 |
| Maintenance Visit Tracking | P0 |
| Shared Audit Trail | P0 |
| Repeat Visit Detection | P0 |
| Reopened Complaint Handling | P0 |
| Rent Follow-Up Tracking | P0 |
| Search & Filtering | P0 |
| Operations Dashboard | P0 |
| Response/Resolution Metrics | P0 |
| Property/Unit Reference Data | P0 |
| Owner Reporting Summary | P1 |
| Image Evidence | P1 |
| Notifications | P2 |

---

# 9. Complaint Lifecycle

The complaint lifecycle is one of the most important parts of GrihSetu.

## Complaint Statuses

```text
OPEN
  ↓
ASSIGNED
  ↓
IN_PROGRESS
  ↓
RESOLVED
  ↓
CLOSED
```

Additional possible states:

```text
WAITING_FOR_PARTS
REOPENED
CANCELLED
```

---

## 9.1 OPEN

A complaint has been registered but no technician has been assigned.

---

## 9.2 ASSIGNED

A technician has been assigned to the complaint.

---

## 9.3 IN_PROGRESS

The technician has started working on the complaint.

---

## 9.4 WAITING_FOR_PARTS

A technician has visited, but resolution cannot continue until equipment, replacement parts or another dependency becomes available.

---

## 9.5 RESOLVED

Technical work has been completed and the issue is believed to be fixed.

---

## 9.6 CLOSED

The office has accepted the resolution and completed the complaint workflow.

---

## 9.7 REOPENED

A previously resolved or closed complaint has returned.

This status is particularly important because the original problem explicitly mentions complaints cycling back unresolved.

When reopened:

- Previous history must remain visible.
- Previous visits must remain visible.
- Previous resolution must remain visible.
- Visit numbering must continue.
- Reopening must generate an audit event.

---

## 9.8 CANCELLED

The complaint is no longer valid or required.

A cancellation reason should be stored.

---

# 10. Functional Requirements

# FR-01 — Authentication

All internal users must authenticate.

The system shall:

- Allow authorized staff to log in.
- Reject invalid credentials.
- Persist valid login sessions where appropriate.
- Identify the authenticated user's role.
- Provide logout functionality.
- Prevent unauthenticated access to operational data.

---

# FR-02 — Role-Based Access

The system must support three primary roles:

- Property Operations
- Complaint Operations
- Technician Operations

Capabilities must depend on role.

Role checks must not exist only in the UI.

Firebase Security Rules must also protect restricted operations.

---

# FR-03 — Property and Unit Reference

Complaints must be associated with the correct residential location.

Each complaint should reference:

- Property/building.
- Unit.
- Tenant.

Property information may include:

- Property name.
- Address.
- Active status.

Unit information may include:

- Unit number.
- Floor.
- Property.
- Current tenant.

Complex property-management CRUD is **not** the focus of the MVP.

The primary purpose of these records is to give complaints and rent cases operational context.

---

# FR-04 — Tenant Record

The system should maintain basic tenant information.

Required information:

- Name.
- Phone/contact information.
- Property.
- Unit.
- Occupancy status.

A tenant record may display:

- Active complaints.
- Historical complaints.
- Rent follow-ups.

Tenant authentication is outside the MVP.

---

# FR-05 — Complaint Creation

Complaint Operations must be able to register tenant complaints.

### Required Fields

- Tenant.
- Property.
- Unit.
- Complaint title.
- Description.
- Category.
- Priority.
- Created timestamp.
- Created by.

### Categories

Examples:

- Plumbing.
- Electrical.
- Structural.
- Appliance.
- Security.
- Cleaning.
- Common area.
- Other.

### Priority

- Low.
- Medium.
- High.
- Urgent.

A newly created complaint receives:

```text
OPEN
```

---

# FR-06 — Technician Assignment

Office staff must be able to assign technicians to complaints.

An assignment should record:

- Technician.
- Complaint.
- Assigned by.
- Assigned timestamp.
- Optional instruction.

After assignment:

```text
OPEN → ASSIGNED
```

The assignment must create an audit event.

---

# FR-07 — Technician Reassignment

Complaints may need to be reassigned.

Reassignment must not overwrite historical information.

The system must record:

- Previous technician.
- New technician.
- Person making reassignment.
- Timestamp.
- Optional reason.

This information becomes part of the complaint timeline.

---

# FR-08 — Technician Work Queue

Technicians require a simplified work-focused interface.

The technician dashboard should contain:

- New assignments.
- High-priority work.
- In-progress complaints.
- Follow-up-required complaints.
- Recently completed visits.

Each card should show:

- Complaint title.
- Property.
- Unit.
- Priority.
- Status.

---

# FR-09 — Complaint History Before Visit

Before starting work, technicians should be able to see:

- Complaint description.
- Priority.
- Previous technician visits.
- Previous observations.
- Actions previously performed.
- Whether replacement parts were previously required.
- Reopening history.

This requirement directly prevents technicians from repeating previous unsuccessful work without context.

---

# FR-10 — Start Maintenance Visit

A technician should be able to select:

**Start Visit**

The system records:

- Technician.
- Complaint.
- Visit number.
- Start timestamp.

Complaint status becomes:

```text
IN_PROGRESS
```

An audit event is created.

---

# FR-11 — Complete Maintenance Visit

Before completing a visit, the technician should record:

### Observation

What was found?

### Work Performed

What action was taken?

### Outcome

What happened after the work?

### Issue Resolved?

- Yes.
- No.

### Follow-Up Required?

- Yes.
- No.

### Optional Note

Additional operational information.

### Completion Time

Automatically captured.

---

# FR-12 — Visit Outcome Logic

## Case A — Issue Resolved

If:

```text
Issue Resolved = YES
```

Complaint may become:

```text
RESOLVED
```

---

## Case B — Issue Not Resolved

If:

```text
Issue Resolved = NO
Follow-Up Required = YES
```

Complaint remains active.

Possible state:

```text
IN_PROGRESS
```

or:

```text
WAITING_FOR_PARTS
```

It must not disappear from operational dashboards.

---

# FR-13 — Repeat Visit Detection

Repeat visits are a core product requirement.

Every maintenance visit should have a sequential number:

```text
Visit #1
Visit #2
Visit #3
...
```

If:

```text
visitCount > 1
```

the complaint must automatically be marked as having repeat visits.

Example:

```text
Total Visits: 3
Repeat Visit: Yes
```

The UI may display:

**Visit #2 — Repeat Visit**

or:

**Repeat Visit Case**

No employee should have to manually remember whether a technician visited previously.

---

# FR-14 — Repeat Visit History

Each repeat visit should preserve:

- Visit number.
- Technician.
- Visit time.
- Observation.
- Work performed.
- Outcome.
- Follow-up requirement.

Previous visits must never be overwritten.

---

# FR-15 — Complaint Reopening

Office staff should be able to reopen a complaint.

Example:

```text
RESOLVED → REOPENED
```

or:

```text
CLOSED → REOPENED
```

When reopening:

- Existing complaint history remains unchanged.
- Previous visits remain visible.
- Reopen timestamp is saved.
- Reopened by user is saved.
- Optional reason is collected.
- Audit event is created.
- Visit numbering continues.

A reopened complaint should be clearly visible on dashboards.

---

# FR-16 — Shared Complaint Audit Trail

The audit trail is the central capability of GrihSetu.

Every significant complaint action should generate an activity event.

Examples:

- Complaint created.
- Priority changed.
- Technician assigned.
- Technician reassigned.
- Visit started.
- Visit completed.
- Follow-up requested.
- Status changed.
- Waiting for parts.
- Complaint resolved.
- Complaint closed.
- Complaint reopened.

Each activity should contain:

- Event type.
- Timestamp.
- User responsible.
- User role.
- Relevant details.
- Previous state where applicable.
- New state where applicable.

Example:

```text
10:12 AM
Complaint Created
Created by Riya Sharma — Complaint Operations

10:26 AM
Technician Assigned
Aman Verma assigned by Riya Sharma

11:04 AM
Visit #1 Started
Aman Verma

11:47 AM
Visit #1 Completed
Issue not resolved.
Replacement valve required.

11:48 AM
Status Changed
IN_PROGRESS → WAITING_FOR_PARTS
```

Audit events should be immutable during normal operations.

---

# FR-17 — Complaint Timeline UI

The complaint detail screen must contain a chronological activity timeline.

Newest-first or oldest-first presentation can be selected based on UX testing, but chronology must remain clear.

The timeline should allow the office to reconstruct the entire complaint lifecycle.

---

# FR-18 — Unresolved Complaint Detection

The system must make unresolved complaints easy to identify.

A complaint is unresolved when its status is not:

```text
RESOLVED
CLOSED
CANCELLED
```

Dashboards should surface:

- Open complaints.
- Assigned complaints.
- In-progress complaints.
- Waiting-for-parts complaints.
- Reopened complaints.

---

# FR-19 — Long-Running Complaints

Complaints that remain unresolved for an unusually long period should be distinguishable.

For the MVP this can be implemented using elapsed time.

Example:

```text
Open for: 3 days 7 hours
```

A future version may implement formal SLA thresholds.

---

# FR-20 — Rent Follow-Up Record

Rent follow-up is explicitly part of the original operational problem.

The MVP should track rent collection activity without becoming a payment platform.

Each rent record should include:

- Tenant.
- Property.
- Unit.
- Rental month.
- Amount due.
- Due date.
- Current status.
- Last follow-up date.
- Next follow-up date.

---

# FR-21 — Rent Statuses

Supported statuses:

```text
DUE
CONTACTED
PROMISED
OVERDUE
PAID
```

---

# FR-22 — Rent Follow-Up Activity

Each contact attempt should create a follow-up record containing:

- Staff member.
- Date/time.
- Contact method.
- Tenant response.
- Notes.
- Next follow-up date.

Example:

```text
2 Oct, 11:15 AM
Phone Call
Handled by Priya

Tenant promised payment by 5 Oct.
Next Follow-Up: 6 Oct
```

---

# FR-23 — Rent Audit History

Previous follow-ups must remain visible.

Staff should be able to understand:

- Who contacted the tenant.
- When.
- What the tenant said.
- What was agreed.
- When the next action is due.

A new note should not overwrite the previous one.

---

# FR-24 — Follow-Ups Due Today

Property Operations should see a list of:

- Follow-ups due today.
- Overdue follow-ups.
- Promised payments reaching their promised date.

This prevents follow-ups from depending on employee memory.

---

# FR-25 — Search

Office users should be able to search complaints using:

- Complaint ID.
- Complaint title.
- Tenant.
- Unit.
- Property.

---

# FR-26 — Filters

Complaint filters should support:

- Status.
- Priority.
- Property.
- Technician.
- Category.
- Repeat visit.
- Reopened status.

Useful predefined filters:

```text
Needs Assignment
Open
In Progress
Reopened
Repeat Visits
Waiting for Parts
Urgent
Resolved
```

---

# FR-27 — Operations Dashboard

Property Operations requires an overview of operational activity.

### Required KPI Cards

- Open complaints.
- Unassigned complaints.
- High/Urgent complaints.
- Reopened complaints.
- Repeat-visit complaints.
- Average first response time.
- Average resolution time.
- Pending rent follow-ups.

### Operational Lists

- Recently created complaints.
- Complaints requiring assignment.
- Reopened complaints.
- Long-running complaints.
- Repeat-visit cases.
- Follow-ups due today.

---

# FR-28 — First Response Time

Because the original problem explicitly requires accurate response reporting, GrihSetu must use a consistent definition.

For the MVP:

> **First Response Time = First technician assignment timestamp − Complaint creation timestamp**

Example:

```text
Complaint Created: 10:00 AM
Technician Assigned: 10:24 AM

First Response Time = 24 minutes
```

Using a defined system event prevents employees from estimating response times manually.

---

# FR-29 — Resolution Time

For the MVP:

> **Resolution Time = First RESOLVED timestamp − Complaint creation timestamp**

Example:

```text
Complaint Created:
10:00 AM

Resolved:
3:45 PM

Resolution Time:
5 hours 45 minutes
```

---

# FR-30 — Reopened Complaint Reporting

Reopened complaints should retain their original resolution timestamp.

The system should also record:

- Reopened timestamp.
- Additional visits.
- Final subsequent resolution.

This prevents a reopened issue from erasing evidence that the first resolution failed.

---

# FR-31 — Owner Reporting Summary

Property Operations should be able to view property-level metrics suitable for communicating to property owners.

Required information:

- Total complaints.
- Open complaints.
- Resolved complaints.
- Average response time.
- Average resolution time.
- Repeat-visit count.
- Reopened complaint count.

The MVP does not require a separate owner login.

The purpose is to ensure that the firm's reported figures are derived from recorded operational events rather than estimates.

---

# 11. Role Permission Matrix

| Capability | Property Ops | Complaint Ops | Technician |
|---|:---:|:---:|:---:|
| View operations dashboard | ✓ | Limited | ✕ |
| View complaints | ✓ | ✓ | Assigned |
| Create complaint | ✓ | ✓ | ✕ |
| Assign technician | ✓ | ✓ | ✕ |
| Reassign technician | ✓ | ✓ | ✕ |
| Start visit | ✕ | ✕ | ✓ |
| Record visit | ✕ | ✕ | ✓ |
| View visit history | ✓ | ✓ | Assigned |
| Resolve complaint | ✓ | ✓ | Workflow input |
| Close complaint | ✓ | ✓ | ✕ |
| Reopen complaint | ✓ | ✓ | ✕ |
| View audit trail | ✓ | ✓ | Assigned |
| Track rent follow-ups | ✓ | ✓/Limited | ✕ |
| View response metrics | ✓ | ✓ | ✕ |
| View owner reporting | ✓ | Limited | ✕ |

---

# 12. Primary User Workflows

# Workflow A — New Complaint to Resolution

### Step 1

Tenant reports a problem to the office.

### Step 2

Complaint Operations registers the complaint.

```text
Status = OPEN
```

Audit:

```text
Complaint Created
```

### Step 3

Office assigns a technician.

```text
OPEN → ASSIGNED
```

Audit:

```text
Technician Assigned
```

### Step 4

Technician opens the complaint.

Technician can see:

- Description.
- Property.
- Unit.
- Priority.
- Historical visits.

### Step 5

Technician starts visit.

```text
ASSIGNED → IN_PROGRESS
```

Audit:

```text
Visit #1 Started
```

### Step 6

Technician completes work.

Technician enters:

- Observation.
- Work completed.
- Result.
- Follow-up required.

### Step 7

Issue is resolved.

```text
IN_PROGRESS → RESOLVED
```

### Step 8

Office reviews.

```text
RESOLVED → CLOSED
```

The complete history remains visible.

---

# Workflow B — Failed First Visit

A technician visits but cannot solve the problem.

Visit #1 is completed.

Technician selects:

```text
Resolved = No
Follow-Up = Yes
```

Complaint remains active.

Possible status:

```text
WAITING_FOR_PARTS
```

Later another technician visit occurs.

System automatically creates:

```text
Visit #2
Repeat Visit = Yes
```

The previous visit remains visible.

---

# Workflow C — Complaint Cycles Back

Complaint was marked resolved.

Tenant later reports that the problem persists.

Complaint Operations selects:

```text
Reopen Complaint
```

Status:

```text
RESOLVED → REOPENED
```

The system preserves:

- Previous resolution.
- Previous technician.
- Previous visits.
- Previous actions.

A new technician visit becomes:

```text
Visit #2
```

The dashboard identifies:

```text
Reopened Complaint
Repeat Visit
```

This directly addresses the “complaints cycle back unresolved” problem.

---

# Workflow D — Rent Follow-Up

A tenant has rent due.

Rent record:

```text
Status = DUE
```

Due date passes.

```text
DUE → OVERDUE
```

Office calls tenant.

A follow-up activity is created.

```text
Status = CONTACTED
```

Tenant promises payment.

```text
Status = PROMISED
```

A follow-up date is recorded.

If paid:

```text
PROMISED → PAID
```

Every interaction remains visible.

---

# 13. Complaint Detail Screen

The Complaint Detail screen should act as the **single source of truth**.

## Header

- Complaint ID.
- Title.
- Status.
- Priority.
- Repeat visit indicator.
- Reopened indicator.

## Tenant & Location

- Tenant.
- Property.
- Unit.
- Contact information.

## Complaint Description

Original problem description.

## Current Assignment

- Technician.
- Assignment timestamp.

## Performance

- Age of complaint.
- First response time.
- Resolution time when applicable.

## Visit Summary

Example:

```text
Total Visits: 3
Repeat Visits: 2
Last Visit: 1 Oct, 2:45 PM
```

## Audit Timeline

Complete chronological history.

## Available Actions

Role and status dependent.

---

# 14. Technician Visit Screen

The visit screen should prioritize speed.

## Information Displayed

- Complaint.
- Property.
- Unit.
- Tenant.
- Previous visit summary.

## Required Fields

### Observation

“What did you find?”

### Action Taken

“What work did you perform?”

### Issue Resolved?

```text
Yes / No
```

### Follow-Up Required?

```text
Yes / No
```

### Additional Notes

Optional.

### Complete Visit

Primary action.

The application should avoid requiring technicians to complete unnecessarily long forms.

---

# 15. Dashboard UX

The dashboard should answer:

> “What needs attention right now?”

rather than simply displaying generic statistics.

Suggested order:

### Needs Immediate Attention

- Urgent complaints.
- Reopened complaints.

### Needs Assignment

- Open unassigned complaints.

### Repeat Visits

- Complaints with >1 visit.

### Waiting

- Waiting for parts.
- Follow-ups pending.

### Performance

- Response time.
- Resolution time.

### Rent

- Follow-ups due.

---

# 16. Data Entities

## User

```text
id
name
email
role
isActive
createdAt
```

---

## Property

```text
id
name
address
isActive
createdAt
```

---

## Unit

```text
id
propertyId
unitNumber
floor
tenantId
occupancyStatus
```

---

## Tenant

```text
id
name
phone
propertyId
unitId
isActive
```

---

## Complaint

```text
id
tenantId
propertyId
unitId

title
description
category
priority
status

currentTechnicianId

visitCount
isRepeatVisit
reopenCount

createdBy
createdAt

firstAssignedAt
resolvedAt
closedAt
updatedAt
```

---

## Technician Assignment

```text
id
complaintId
technicianId

assignedBy
assignedAt

reason
```

---

## Maintenance Visit

```text
id
complaintId
technicianId

visitNumber

startedAt
completedAt

observation
actionTaken
outcome

isResolved
followUpRequired
```

---

## Audit Event

```text
id
complaintId

actorId
actorRole

eventType
description

previousValue
newValue

createdAt
```

---

## Rent Record

```text
id
tenantId
propertyId
unitId

month
amountDue
dueDate

status

lastFollowUpAt
nextFollowUpAt
```

---

## Rent Follow-Up

```text
id
rentRecordId

handledBy
contactMethod

notes
tenantResponse

createdAt
nextFollowUpAt
```

---

# 17. Core Relationships

```text
Property
   ↓
Units
   ↓
Tenants
   ↓
Complaints
   ↓
Assignments
   ↓
Maintenance Visits
   ↓
Audit Events
```

Rent workflow:

```text
Tenant
   ↓
Rent Records
   ↓
Rent Follow-Ups
```

---

# 18. Real-Time Requirements

Complaint operations should update in near-real time wherever practical.

Examples:

- Technician receives new assignment.
- Office sees visit begin.
- Office sees visit completion.
- Complaint status updates.
- Reopened complaint appears.
- Dashboard counters update.

Firestore real-time listeners can support these workflows.

---

# 19. Security Requirements

The system must:

- Require authentication.
- Enforce role permissions.
- Prevent technicians from editing administrative records.
- Prevent unauthorized users from viewing property data.
- Avoid relying solely on UI restrictions.
- Use Firebase Security Rules.
- Prevent audit entries from being casually edited/deleted.
- Limit technicians primarily to complaints assigned to them.
- Validate writes before saving.

---

# 20. Validation Requirements

## Complaint Creation

Required:

- Property.
- Unit.
- Tenant.
- Title.
- Description.
- Category.
- Priority.

---

## Visit Completion

Required:

- Observation.
- Action performed.
- Resolution status.
- Follow-up status.

---

## Complaint Reopening

Required:

- Reopen reason.

---

## Rent Follow-Up

Required:

- Contact/action type.
- Notes/result.

---

# 21. Error Handling

The system must provide meaningful feedback for:

- Authentication failure.
- Data loading failure.
- Complaint creation failure.
- Technician assignment failure.
- Visit update failure.
- Offline/network errors.
- Permission failure.

The UI should not expose raw Firebase error messages to normal users.

---

# 22. Loading and Duplicate Prevention

Operations such as:

- Create complaint.
- Assign technician.
- Complete visit.
- Reopen complaint.
- Add rent follow-up.

must disable repeated submission while processing.

This prevents duplicate operational records.

---

# 23. Empty States

Examples:

## Technician

```text
No assigned complaints.
You're all caught up.
```

## Repeat Visits

```text
No repeat-visit complaints found.
```

## Rent

```text
No follow-ups are due today.
```

## Search

```text
No complaints match your search.
```

---

# 24. Non-Functional Requirements

## Performance

Common operational screens should load quickly under expected project-scale data.

## Usability

Technicians should be able to record a visit quickly while working in the field.

## Reliability

Important operational updates must not fail silently.

## Maintainability

Flutter UI, business logic and Firebase access should remain separated where practical.

## Scalability

The model should support multiple buildings, tenants, complaints and historical visits.

## Mobile Responsiveness

UI should work correctly across common Android phone sizes.

## Accessibility

The UI should use:

- Readable text.
- Clear status labels.
- Large touch targets.
- Sufficient contrast.
- Icons accompanied by text when meaning may be unclear.

---

# 25. Product Success Metrics

## Audit Coverage

**Target:** 100% of critical complaint actions generate audit events.

---

## Visit Traceability

**Target:** Every completed technician visit records technician and timestamps.

---

## Repeat Visit Visibility

**Target:** Every complaint with more than one visit is automatically identifiable.

---

## Reopen Traceability

**Target:** Every reopened complaint preserves previous history.

---

## Response Time Availability

**Target:** Every complaint with an assignment has a calculable first response time.

---

## Resolution Time Availability

**Target:** Every resolved complaint has calculable resolution time.

---

## Rent Follow-Up Traceability

**Target:** Every rent interaction added through GrihSetu remains available historically.

---

# 26. MVP Demonstration Scenario

The final application should be capable of demonstrating this scenario.

### Step 1

Tenant in:

```text
Green Heights
Flat A-204
```

reports:

```text
Kitchen Pipe Leakage
```

### Step 2

Complaint Operations creates the complaint.

```text
Priority: HIGH
Status: OPEN
```

### Step 3

Technician Aman is assigned.

```text
Status: ASSIGNED
```

Response time begins from the system timestamps.

### Step 4

Aman starts Visit #1.

```text
Status: IN_PROGRESS
```

### Step 5

Aman finds a damaged valve.

The valve cannot immediately be replaced.

He records:

```text
Issue Resolved: No
Follow-Up Required: Yes
```

Complaint becomes:

```text
WAITING_FOR_PARTS
```

### Step 6

A second visit occurs.

The system automatically displays:

```text
Visit #2
Repeat Visit
```

### Step 7

The valve is replaced.

Complaint becomes:

```text
RESOLVED
```

### Step 8

Office closes the complaint.

```text
CLOSED
```

The timeline contains every activity.

### Step 9

The tenant reports another leak two days later.

Office reopens the complaint.

```text
CLOSED → REOPENED
```

The original visits remain visible.

### Step 10

A third visit occurs.

```text
Visit #3
Repeat Visit
```

Property Operations can now see:

```text
Total Visits: 3
Repeat Visit: Yes
Reopened: Yes
First Response Time
Resolution Time
```

This scenario validates the core GrihSetu value proposition.

---

# 27. Prioritization

## P0 — Must Have

- Firebase Authentication.
- Role-based access.
- Property/unit/tenant context.
- Complaint creation.
- Complaint list.
- Complaint detail.
- Technician assignment.
- Technician work queue.
- Maintenance visits.
- Visit history.
- Complaint statuses.
- Audit trail.
- Repeat visit detection.
- Complaint reopening.
- Unresolved complaint visibility.
- Rent follow-up tracking.
- Search.
- Filters.
- Dashboard.
- Response time.
- Resolution time.

---

## P1 — Should Have

- Property-specific reporting.
- Owner-ready summary.
- Charts.
- Image evidence.
- Technician workload summary.
- Better date filters.
- Complaint attachments.

---

## P2 — Stretch

- Push notifications.
- Export PDF/report.
- SLA warnings.
- Automated reminders.
- Advanced analytics.

---

# 28. Key Product Risks

| Risk | Effect | Mitigation |
|---|---|---|
| Building a full ERP | Core workflow remains incomplete | Keep scope around auditability |
| Overbuilding property CRUD | Sprint time wasted | Treat property data mainly as context |
| Poor Firestore model | Difficult queries later | Finalize data structure before UI build |
| Missing audit events | Core problem remains unsolved | Centralize audit creation |
| Status inconsistency | Incorrect reports | Define transitions clearly |
| Overwriting visit data | Historical context lost | Visits must be immutable records |
| Treating visit as resolution | Complaints cycle unresolved | Separate visit completion from complaint resolution |
| Missing reopen workflow | Returning complaints become new disconnected cases | Explicit REOPENED state |
| Manual response-time calculation | Reports remain inaccurate | Derive metrics from timestamps |
| Complex technician forms | Field adoption suffers | Keep visit workflow minimal |
| Too many optional features | P0 incomplete | Complete vertical workflow first |

---

# 29. Assumptions

The MVP assumes:

- The firm manages multiple residential properties.
- Tenants communicate complaints through the existing office process.
- Office staff enter complaints into GrihSetu.
- Technicians have authenticated mobile accounts.
- A complaint may require multiple technician visits.
- A resolved complaint may later be reopened.
- Property owners primarily need reports rather than operational access.
- Rent payments happen outside GrihSetu.
- GrihSetu tracks rent follow-ups rather than processing transactions.
- Property/unit/tenant information can initially be entered or seeded by authorized staff.

---

# 30. Definition of Done — Complaint Feature

A complaint workflow is complete only when:

1. Complaint can be created.
2. Technician can be assigned.
3. Assignment appears for technician.
4. Technician can start visit.
5. Technician can complete visit.
6. Visit remains in historical record.
7. Audit events are generated.
8. Unresolved issue remains visible.
9. Second visit is detected as repeat.
10. Complaint can be resolved.
11. Complaint can be reopened.
12. Reopened history is preserved.
13. Response time can be calculated.
14. Resolution time can be calculated.
15. Permissions are correctly enforced.
16. Workflow has been tested on a device/emulator.

---

# 31. Definition of Done — GrihSetu MVP

The MVP is complete when the team can demonstrate:

```text
Login
↓
View/Create Property Context
↓
Create Complaint
↓
Assign Technician
↓
Technician Receives Assignment
↓
Technician Starts Visit
↓
Technician Records Work
↓
Issue Remains Unresolved
↓
Second Visit Required
↓
System Detects Repeat Visit
↓
Complaint Resolved
↓
Complaint Reopened
↓
Previous History Remains Visible
↓
Audit Timeline Shows Entire Journey
↓
Response & Resolution Metrics Generated
↓
Property Operations Dashboard Updated
```

Additionally:

```text
Create Rent Case
↓
Record Follow-Up
↓
Schedule Next Follow-Up
↓
View Complete Follow-Up History
```

---

# 32. Final Product Statement

GrihSetu is not primarily a complaint-ticketing application.

It is an **operational traceability system for property management**.

Its purpose is to bridge the information gap between office staff and field technicians.

The product must ensure that:

> **A complaint cannot disappear simply because a technician visited.**

> **A repeat visit cannot occur without the previous visit being visible.**

> **A reopened complaint cannot erase its previous history.**

> **A rent follow-up cannot depend entirely on one employee's memory.**

> **A response-time report cannot depend on estimates.**

GrihSetu succeeds when the firm can answer, from recorded data:

**What happened?**

**Who handled it?**

**When did they handle it?**

**Was the issue actually resolved?**

**How many times did technicians visit?**

**Did the complaint return?**

**How quickly did the organization respond?**

**How long did resolution take?**

That shared, timestamped operational history is the core product value of GrihSetu.