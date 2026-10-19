# GrihSetu reference-data repository contracts

The contracts in `lib/repositories/reference_data_repositories.dart` are the
application boundary for GRIH-010. UI/controllers depend on these interfaces,
not on `FirebaseFirestore` directly. Concrete adapters can be added in the
CRUD issues without changing screens or domain models.

## Rent workflow (GRIH-031)

`RentRepository` exposes scoped rent reads, status-safe updates, payment
recording, and due/overdue queues. `RentFollowUpRepository` exposes only append
and history reads. `FirestoreRentRepository.addRentFollowUp` is the canonical
write workflow: it validates the trusted authenticated operations actor, reads
the parent rent record, appends one follow-up, and updates the parent in one
transaction. The in-memory implementation is used by domain and widget tests.

Contact and promise statuses must be produced through a follow-up so the
history contains the corresponding action. A paid record is immutable and a
follow-up cannot be added to it. The stored status is not automatically changed
from `promised` to `overdue`; overdue queues derive unpaid/past-due state from
the date while preserving the communication workflow value.

## Contract surface

- `UserProfileRepository`: read-only access to the existing
  `users/{uid}` profile. Authentication, signup bootstrap, role validation,
  and trusted role assignment remain in `AuthService` from GRIH-007.
- `PropertyRepository`: fetch one property, watch active/all properties,
  create with a generated ID, and update.
- `UnitRepository`: fetch a unit, watch units by `propertyId`, create, and
  update.
- `TenantRepository`: fetch a tenant, watch tenants by `propertyId` or
  `unitId`, create, and update.

Deletion is intentionally absent from the first contract. Reference records
are operational context for complaints and rent history; a later lifecycle
decision should choose archival/inactive status rather than silently breaking
historical references.

## Adapter rules

Future Firestore adapters must:

1. Use `FirestoreCollections` for collection names.
2. Read the document ID from `DocumentSnapshot.id` and pass it to `fromMap`.
3. Validate required fields and tenant property/unit relationships before a
   write.
4. Use `FirestoreRepositoryPayloads.forCreate` and `.forUpdate` so server
   timestamps remain authoritative and `createdAt` cannot be overwritten.
5. Keep list queries scoped by the requested foreign key. A query such as
   `units.where('propertyId', isEqualTo: propertyId)` is the canonical unit
   listing contract.
6. Translate Firestore failures at the service boundary rather than exposing
   raw Firebase messages in UI state.

The contracts do not claim that Firestore or the client enforces uniqueness.
Unit-number reservation must be transaction-backed, and cross-document
property/unit validation must be enforced by the eventual trusted write path
and security rules.
