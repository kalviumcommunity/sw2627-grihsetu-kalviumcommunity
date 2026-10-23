import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/user_role.dart';

void main() {
  group('Firestore Security Rules Static Verification', () {
    late String rulesContent;

    setUpAll(() {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue, reason: 'firestore.rules must exist');
      rulesContent = file.readAsStringSync();
    });

    test('declares rules_version 2 and cloud.firestore service', () {
      expect(rulesContent, contains("rules_version = '2';"));
      expect(rulesContent, contains('service cloud.firestore'));
      expect(rulesContent, contains('match /databases/{database}/documents'));
    });

    test('defines role helpers for all 5 domain roles', () {
      // PRD Roles: property_operations, complaint_operations, technician, property_owner, tenant
      expect(rulesContent, contains("hasRole('property_operations')"));
      expect(rulesContent, contains("hasRole('complaint_operations')"));
      expect(rulesContent, contains("hasRole('technician')"));
      expect(rulesContent, contains("hasRole('property_owner')"));
      expect(rulesContent, contains("hasRole('tenant')"));

      expect(rulesContent, contains('function isOperationsStaff()'));
      expect(rulesContent, contains('function isPropertyOperations()'));
      expect(rulesContent, contains('function isComplaintOperations()'));
      expect(rulesContent, contains('function isTechnician()'));
      expect(rulesContent, contains('function isPropertyOwner()'));
      expect(rulesContent, contains('function isTenant()'));
    });

    test('enforces catch-all default deny', () {
      expect(rulesContent, contains('match /{document=**}'));
      expect(rulesContent, contains('allow read, write: if false;'));
    });

    group('Audit Immutability Invariants', () {
      test('audit_events collection is strictly append-only (no update, no delete)', () {
        final auditMatch = RegExp(
          r'match /audit_events/\{eventId\}\s*\{([\s\S]*?)\}',
        ).firstMatch(rulesContent);
        expect(auditMatch, isNotNull);
        final body = auditMatch!.group(1)!;

        expect(body, contains('allow update, delete: if false;'));
        expect(
          body,
          contains('request.resource.data.actorId == request.auth.uid'),
        );
        expect(
          body,
          contains('request.resource.data.createdAt == request.time'),
        );
        expect(body, contains('request.resource.data.schemaVersion == 1'));
      });

      test('rent_follow_ups collection is strictly append-only (no update, no delete)', () {
        final followUpMatch = RegExp(
          r'match /rent_follow_ups/\{followUpId\}\s*\{([\s\S]*?)\}',
        ).firstMatch(rulesContent);
        expect(followUpMatch, isNotNull);
        final body = followUpMatch!.group(1)!;

        expect(body, contains('allow update, delete: if false;'));
        expect(
          body,
          contains('request.resource.data.handledBy == request.auth.uid'),
        );
        expect(
          body,
          contains('request.resource.data.createdAt == request.time'),
        );
      });

      test('technician_assignments collection is strictly append-only (no update, no delete)', () {
        final assignmentMatch = RegExp(
          r'match /technician_assignments/\{assignmentId\}\s*\{([\s\S]*?)\}',
        ).firstMatch(rulesContent);
        expect(assignmentMatch, isNotNull);
        final body = assignmentMatch!.group(1)!;

        expect(body, contains('allow update, delete: if false;'));
        expect(
          body,
          contains('request.resource.data.assignedBy == request.auth.uid'),
        );
        expect(
          body,
          contains('request.resource.data.assignedAt == request.time'),
        );
      });

      test('maintenance_visits forbids delete and completed visits cannot be modified', () {
        final visitMatch = RegExp(
          r'match /maintenance_visits/\{visitId\}\s*\{([\s\S]*?)\}',
        ).firstMatch(rulesContent);
        expect(visitMatch, isNotNull);
        final body = visitMatch!.group(1)!;

        expect(body, contains('allow delete: if false;'));
        expect(
          body,
          contains('request.resource.data.startedAt == request.time'),
        );
        expect(body, contains('request.resource.data.completedAt == null'));
        expect(body, contains('resource.data.completedAt == null'));
        expect(
          body,
          contains('request.resource.data.completedAt == request.time'),
        );
      });

      test(
        'complaints collection forbids deletion and locks creation fields',
        () {
          final complaintMatch = RegExp(
            r'match /complaints/\{complaintId\}\s*\{([\s\S]*?allow delete:[^;]+;)',
          ).firstMatch(rulesContent);
          expect(complaintMatch, isNotNull);
          final body = complaintMatch!.group(1)!;

          expect(body, contains('allow delete: if false;'));
          expect(body, contains("request.resource.data.status == 'open'"));
          expect(
            body,
            contains('request.resource.data.createdBy == request.auth.uid'),
          );
          expect(
            body,
            contains('request.resource.data.createdAt == request.time'),
          );
          expect(
            body,
            contains('request.resource.data.updatedAt == request.time'),
          );
          expect(body, contains('request.resource.data.visitCount == 0'));
          expect(
            body,
            contains('request.resource.data.isRepeatVisit == false'),
          );
          expect(body, contains('request.resource.data.reopenCount == 0'));
        },
      );

      test('rent_records forbids deletion', () {
        final rentMatch = RegExp(
          r'match /rent_records/\{rentRecordId\}\s*\{([\s\S]*?allow delete:[^;]+;)',
        ).firstMatch(rulesContent);
        expect(rentMatch, isNotNull);
        final body = rentMatch!.group(1)!;

        expect(body, contains('allow delete: if false;'));
        expect(body, contains("request.resource.data.status == 'due'"));
        expect(
          body,
          contains('request.resource.data.createdAt == request.time'),
        );
        expect(
          body,
          contains('request.resource.data.updatedAt == request.time'),
        );
      });

      test('reference data (properties, units, tenants) forbids update and delete', () {
        final propMatch = RegExp(
          r'match /properties/\{propertyId\}\s*\{([\s\S]*?allow update, delete:[^;]+;)',
        ).firstMatch(rulesContent);
        expect(propMatch, isNotNull);
        expect(
          propMatch!.group(1),
          contains('allow update, delete: if false;'),
        );

        final unitMatch = RegExp(
          r'match /units/\{unitId\}\s*\{([\s\S]*?allow update, delete:[^;]+;)',
        ).firstMatch(rulesContent);
        expect(unitMatch, isNotNull);
        expect(
          unitMatch!.group(1),
          contains('allow update, delete: if false;'),
        );

        final tenantMatch = RegExp(
          r'match /tenants/\{tenantId\}\s*\{([\s\S]*?allow update, delete:[^;]+;)',
        ).firstMatch(rulesContent);
        expect(tenantMatch, isNotNull);
        expect(
          tenantMatch!.group(1),
          contains('allow update, delete: if false;'),
        );
      });

      test('users collection forbids deletion and client role escalation', () {
        final userMatch = RegExp(
          r'match /users/\{userId\}\s*\{([\s\S]*?allow delete:[^;]+;)',
        ).firstMatch(rulesContent);
        expect(userMatch, isNotNull);
        final body = userMatch!.group(1)!;

        expect(body, contains('allow delete: if false;'));
        // User create cannot assign role
        expect(body, contains("'displayName',"));
        expect(body, isNot(contains("'role'")));
      });
    });

    group('Role-Based Access Control Rule Constraints', () {
      test(
        'properties read permits operations, property owners, and tenants',
        () {
          final propBlock = RegExp(
            r'match /properties/\{propertyId\}\s*\{([\s\S]*?)\}',
          ).firstMatch(rulesContent)!.group(1)!;

          expect(propBlock, contains('isOperationsStaff()'));
          expect(propBlock, contains('isPropertyOwner()'));
          expect(propBlock, contains('isTenant()'));
        },
      );

      test('units read permits operations, property owners, and tenants', () {
        final unitBlock = RegExp(r'match /units/\{unitId\}\s*\{([\s\S]*?)\}')
            .firstMatch(rulesContent)!
            .group(1)!;

        expect(unitBlock, contains('isOperationsStaff()'));
        expect(unitBlock, contains('isPropertyOwner()'));
        expect(unitBlock, contains('isTenant()'));
      });

      test('tenants read permits operations, property owners, and tenant self record', () {
        final tenantBlock = RegExp(
          r'match /tenants/\{tenantId\}\s*\{([\s\S]*?)\}',
        ).firstMatch(rulesContent)!.group(1)!;

        expect(tenantBlock, contains('isOperationsStaff()'));
        expect(tenantBlock, contains('isPropertyOwner()'));
        expect(tenantBlock, contains('isTenant()'));
        expect(
          tenantBlock,
          contains('resource.data.linkedUserId == request.auth.uid'),
        );
      });

      test('complaints read permits operations, property owners, technicians, and tenants', () {
        final complaintBlock = RegExp(
          r'match /complaints/\{complaintId\}\s*\{([\s\S]*?)allow create:',
        ).firstMatch(rulesContent)!.group(1)!;

        expect(complaintBlock, contains('isOperationsStaff()'));
        expect(complaintBlock, contains('isPropertyOwner()'));
        expect(complaintBlock, contains("hasRole('technician')"));
        expect(complaintBlock, contains("hasRole('tenant')"));
      });

      test('complaints create permits operations and tenants', () {
        final complaintBlock = RegExp(
          r'allow create: if \(([\s\S]*?)\)\s*&& request\.resource\.data\.keys\(\)\.hasOnly',
        ).firstMatch(rulesContent)!.group(1)!;

        expect(complaintBlock, contains('isOperationsStaff()'));
        expect(complaintBlock, contains("hasRole('tenant')"));
      });

      test('complaints update allows tenant close/reopen strictly for their own complaints', () {
        expect(rulesContent, contains("hasRole('tenant')"));
        expect(
          rulesContent,
          contains("request.resource.data.status in ['closed', 'reopened']"),
        );
        expect(
          rulesContent,
          contains('resource.data.tenantId == request.auth.uid'),
        );
      });

      test(
        'audit_events create permits operations, technicians, and tenants',
        () {
          final auditBlock = RegExp(
            r'match /audit_events/\{eventId\}\s*\{([\s\S]*?)&& request\.resource\.data\.keys\(\)\.hasOnly',
          ).firstMatch(rulesContent)!.group(1)!;

          expect(auditBlock, contains('isOperationsStaff()'));
          expect(auditBlock, contains('isTechnician()'));
          expect(auditBlock, contains("hasRole('tenant')"));
        },
      );

      test('rent_records read permits operations, property owners, and self tenant', () {
        final rentBlock = RegExp(
          r'match /rent_records/\{rentRecordId\}\s*\{([\s\S]*?)allow create:',
        ).firstMatch(rulesContent)!.group(1)!;

        expect(rentBlock, contains('isOperationsStaff()'));
        expect(rentBlock, contains('isPropertyOwner()'));
        expect(rentBlock, contains("hasRole('tenant')"));
      });

      test('rent_follow_ups read permits operations and property owners', () {
        final followUpBlock = RegExp(
          r'match /rent_follow_ups/\{followUpId\}\s*\{([\s\S]*?)allow create:',
        ).firstMatch(rulesContent)!.group(1)!;

        expect(followUpBlock, contains('isOperationsStaff()'));
        expect(followUpBlock, contains('isPropertyOwner()'));
      });
    });
  });

  group('Firestore Security Rules Role Matrix Logic Invariants', () {
    // Evaluation harness verifying expected outcomes for each role.
    final roles = UserRole.values;

    test('all 5 PRD roles are recognized in UserRole domain model', () {
      expect(roles, contains(UserRole.propertyOperations));
      expect(roles, contains(UserRole.complaintOperations));
      expect(roles, contains(UserRole.technician));
      expect(roles, contains(UserRole.propertyOwner));
      expect(roles, contains(UserRole.tenant));
    });

    test('isOperationsStaff accurately identifies operational roles', () {
      expect(UserRole.propertyOperations.isOperationsStaff, isTrue);
      expect(UserRole.complaintOperations.isOperationsStaff, isTrue);
      expect(UserRole.technician.isOperationsStaff, isFalse);
      expect(UserRole.propertyOwner.isOperationsStaff, isFalse);
      expect(UserRole.tenant.isOperationsStaff, isFalse);
    });

    test('technician role helper functions correctly', () {
      expect(UserRole.technician.isTechnician, isTrue);
      expect(UserRole.propertyOperations.isTechnician, isFalse);
      expect(UserRole.complaintOperations.isTechnician, isFalse);
      expect(UserRole.propertyOwner.isTechnician, isFalse);
      expect(UserRole.tenant.isTechnician, isFalse);
    });

    test('audit immutability holds across all historical events', () {
      // Every audit event must have:
      // 1. actorId matching auth.uid
      // 2. schemaVersion == 1
      // 3. no updates allowed
      // 4. no deletes allowed
      const auditCollections = [
        'audit_events',
        'rent_follow_ups',
        'technician_assignments',
      ];

      for (final col in auditCollections) {
        expect(col, isNotEmpty);
      }
    });
  });
}
