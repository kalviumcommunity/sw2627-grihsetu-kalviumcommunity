import 'package:flutter/material.dart';

enum UserRole { tenant, technician, staff, owner }

class NavItem {
  const NavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon, selectedIcon;
}

const roleNav = <UserRole, List<NavItem>>{
  UserRole.tenant: [
    NavItem('Home', Icons.home_outlined, Icons.home),
    NavItem('Complaints', Icons.receipt_long_outlined, Icons.receipt_long),
    NavItem('Alerts', Icons.notifications_outlined, Icons.notifications),
    NavItem('Profile', Icons.person_outline, Icons.person),
  ],
  UserRole.technician: [
    NavItem('Today', Icons.today_outlined, Icons.today),
    NavItem('Jobs', Icons.build_outlined, Icons.build),
    NavItem('Alerts', Icons.notifications_outlined, Icons.notifications),
    NavItem('Profile', Icons.person_outline, Icons.person),
  ],
  UserRole.staff: [
    NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    NavItem('Complaints', Icons.receipt_long_outlined, Icons.receipt_long),
    NavItem('Properties', Icons.apartment_outlined, Icons.apartment),
    NavItem('Profile', Icons.person_outline, Icons.person),
  ],
  UserRole.owner: [
    NavItem('Overview', Icons.insights_outlined, Icons.insights),
    NavItem('Properties', Icons.apartment_outlined, Icons.apartment),
    NavItem('Audit log', Icons.history_outlined, Icons.history),
    NavItem('Profile', Icons.person_outline, Icons.person),
  ],
};
