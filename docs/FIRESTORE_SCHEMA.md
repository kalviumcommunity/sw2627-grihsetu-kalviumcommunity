# GrihSetu Firestore reference-data schema

GRIH-010 establishes the data foundation for property location context. The
implementation uses top-level collections and string ID references because
complaints, maintenance visits, rent records, dashboards, and future reports
will query across properties. A nested `properties/{propertyId}/units`
hierarchy would make those cross-property queries and future collection-group
queries unnecessarily dependent on path shape.

## Conventions

- `users/{uid}` uses the Firebase Authentication UID as its document ID. The
  existing GRIH-007/AuthService profile shape is authoritative: `uid`,
  `email`, optional `displayName` and `phoneNumber`, `createdAt`,
  `updatedAt`, and the trusted `role` after assignment. This issue does not
  rename or rewrite those fields.
- Properties, units, and tenants use Firestore-generated, non-sequential
  document IDs. IDs are stable even when names or display labels change.
- References are plain string IDs (`propertyId`, `unitId`, `tenantId`, and
  `linkedUserId`), matching the current domain model and keeping queries
  straightforward. They are not Firestore `DocumentReference` values.
- Persisted dates are Firestore `Timestamp` values. Creates and updates must
  write `FieldValue.serverTimestamp()` for `createdAt`/`updatedAt`; a client
  clock is never authoritative. Readers safely accept legacy ISO strings and
  Firestore timestamps during migration.
- The document ID is the entity ID. New entity payloads do not add a duplicate
  `id` field. The existing user profile compatibility code is left unchanged
  because GRIH-007 owns that schema.

## Collections

### `users/{uid}`

The authentication/profile collection already exists. Roles are trusted values
validated by `AuthService`; clients cannot self-assign a role. A tenant record
may optionally set `linkedUserId` to this UID, but a tenant does not need an
Auth account and the tenant record remains a separate entity.

### `properties/{propertyId}`

```text
name          string, required
address       string or structured map, required for MVP display
status        "active" | "inactive"
createdAt     Timestamp
updatedAt     Timestamp
```

New code may use the structured address map with optional `line1`, `line2`,
`locality`, `city`, `state`, `postalCode`, and `country` fields. The model also
reads the existing PRD string address shape so no migration is required for
current fixtures/data.

Property access is determined by authenticated role plus the user's approved
property scope in the eventual authorization layer. This issue does not add a
client-writable scope field or weaken the existing `users` rules.

### `units/{unitId}`

```text
propertyId   string, required
unitNumber   string, required
floor        integer, optional
status       "vacant" | "occupied" | "unavailable"
createdAt    Timestamp
updatedAt    Timestamp
```

Each unit has exactly one `propertyId`. A unit number is unique within a
property, not globally. Firestore does not enforce that uniqueness: the future
create/update workflow must reserve/check a deterministic key such as
`unitNumberKeys/{propertyId}_{normalizedUnitNumber}` in a transaction, or use
an equivalent transaction-safe reservation document. Reads should always
filter units by `propertyId`.

The old `tenantId`/`occupancyStatus` shape is still readable for compatibility,
but new writes use `status`. `tenantId` is not persisted by the new model: a
unit can have multiple tenants over time, so a denormalized single-tenant field
must not become a competing source of truth.

### `tenants/{tenantId}`

```text
fullName       string, required
phone          string, optional
email          string, optional
propertyId     string, optional while unassigned
unitId         string, optional while unassigned
linkedUserId   string, optional Firebase Auth UID
occupancyStart Timestamp, optional
occupancyEnd   Timestamp, optional
status         "pending" | "active" | "ended"
createdAt      Timestamp
updatedAt      Timestamp
```

An unassigned tenant has neither location ID. If `unitId` is present,
`propertyId` must also be present, and the referenced unit must belong to that
property. The repository/service layer must validate that relationship before
writing; Firestore rules cannot perform a general cross-document invariant
without an explicit trusted workflow.

Current assignment is represented by the tenant's location IDs for this MVP.
Historical occupancy, multiple occupants in one unit, and a tenant moving
between units are supported by adding a separate `tenancies`/`occupancies`
record in a later issue. That future record should become the historical
source of truth; this issue does not build that subsystem.

Vacant units are represented by `units.status == "vacant"` and no active tenant
assignment. No placeholder tenant is created for a vacancy.

## Downstream relationship contracts

Future operational documents should store IDs rather than copied entity maps:

```text
complaints/{complaintId}
  propertyId, unitId, tenantId, createdBy, currentTechnicianId

maintenance_visits/{visitId}
  complaintId, technicianId, visitNumber

rent_records/{rentRecordId}
  propertyId, unitId, tenantId, tenancyId (when tenancy history exists)
```

This allows a complaint to retain its property/unit/tenant context even when a
tenant later moves, while maintenance visits remain traceable to one complaint
for repeat-visit and response-time reporting. Rent records must keep the
historical tenancy reference once that entity exists rather than inferring old
occupancy from a mutable current tenant document.

Full complaint, maintenance, rent, audit, and property CRUD are outside
GRIH-010.
