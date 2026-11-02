import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/user_role.dart';

import '../support/app_harness.dart';

class ScreenCatalogEntry {
  const ScreenCatalogEntry(this.name, this.role);

  final String name;
  final UserRole role;

  Future<void> setup(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    required Brightness brightness,
  }) => pumpApp(
    tester,
    role: role,
    size: size,
    textScale: textScale,
    brightness: brightness,
  );
}

const screenCatalog = <ScreenCatalogEntry>[
  ScreenCatalogEntry('auth/login', UserRole.tenant),
  ScreenCatalogEntry('auth/signup', UserRole.tenant),
  ScreenCatalogEntry('auth/forgot-password', UserRole.tenant),
  ScreenCatalogEntry('tenant/home', UserRole.tenant),
  ScreenCatalogEntry('tenant/complaints', UserRole.tenant),
  ScreenCatalogEntry('tenant/rent', UserRole.tenant),
  ScreenCatalogEntry('tenant/profile', UserRole.tenant),
  ScreenCatalogEntry('technician/today', UserRole.technician),
  ScreenCatalogEntry('technician/assigned-work', UserRole.technician),
  ScreenCatalogEntry('technician/schedule', UserRole.technician),
  ScreenCatalogEntry('technician/history', UserRole.technician),
  ScreenCatalogEntry('staff/overview', UserRole.complaintOperations),
  ScreenCatalogEntry('staff/complaints', UserRole.complaintOperations),
  ScreenCatalogEntry('staff/rent', UserRole.complaintOperations),
  ScreenCatalogEntry('staff/tenants', UserRole.complaintOperations),
  ScreenCatalogEntry('owner/overview', UserRole.propertyOwner),
  ScreenCatalogEntry('owner/properties', UserRole.propertyOwner),
  ScreenCatalogEntry('owner/complaints', UserRole.propertyOwner),
  ScreenCatalogEntry('owner/rent', UserRole.propertyOwner),
  ScreenCatalogEntry('owner/reports', UserRole.propertyOwner),
  ScreenCatalogEntry('owner/summary-print', UserRole.propertyOwner),
  ScreenCatalogEntry('complaint/create-where', UserRole.tenant),
  ScreenCatalogEntry('complaint/create-what', UserRole.tenant),
  ScreenCatalogEntry('complaint/create-evidence', UserRole.tenant),
  ScreenCatalogEntry('complaint/create-visit', UserRole.tenant),
  ScreenCatalogEntry('complaint/create-review', UserRole.tenant),
  ScreenCatalogEntry('complaint/detail-open', UserRole.complaintOperations),
  ScreenCatalogEntry('complaint/detail-assigned', UserRole.complaintOperations),
  ScreenCatalogEntry(
    'complaint/detail-waiting-parts',
    UserRole.complaintOperations,
  ),
  ScreenCatalogEntry('complaint/detail-resolved', UserRole.tenant),
  ScreenCatalogEntry('complaint/detail-closed', UserRole.tenant),
  ScreenCatalogEntry('complaint/detail-reopened', UserRole.complaintOperations),
  ScreenCatalogEntry(
    'complaint/assignment-sheet',
    UserRole.complaintOperations,
  ),
  ScreenCatalogEntry('visit/stepper', UserRole.technician),
  ScreenCatalogEntry('visit/completion-form', UserRole.technician),
  ScreenCatalogEntry('sheet/close', UserRole.complaintOperations),
  ScreenCatalogEntry('sheet/reopen', UserRole.tenant),
  ScreenCatalogEntry('sheet/waiting-parts', UserRole.technician),
  ScreenCatalogEntry('search/results', UserRole.complaintOperations),
  ScreenCatalogEntry('search/filter-sheet', UserRole.complaintOperations),
  ScreenCatalogEntry('rent/list', UserRole.propertyOperations),
  ScreenCatalogEntry('rent/detail', UserRole.propertyOperations),
  ScreenCatalogEntry('rent/follow-up-sheet', UserRole.propertyOperations),
  ScreenCatalogEntry('property/browser', UserRole.propertyOperations),
  ScreenCatalogEntry('property/summary', UserRole.propertyOwner),
  ScreenCatalogEntry('dashboard/items', UserRole.complaintOperations),
  ScreenCatalogEntry('dashboard/all-clear', UserRole.complaintOperations),
  ScreenCatalogEntry('tenant/detail-context', UserRole.propertyOperations),
  ScreenCatalogEntry('state/empty', UserRole.complaintOperations),
  ScreenCatalogEntry('state/error', UserRole.complaintOperations),
  ScreenCatalogEntry('state/loading', UserRole.complaintOperations),
];
