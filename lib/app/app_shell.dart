import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/enums/user_role.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dev/widget_gallery.dart';
import '../screens/property/property_browser_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialRole = UserRole.technician});

  final UserRole initialRole;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late UserRole _role = widget.initialRole;
  int _index = 0;

  static const double _railBreakpoint = 840;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _roleNavigation[_role]!;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= _railBreakpoint;
    final selected = items[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Switch role',
            icon: const Icon(Icons.swap_horiz),
            onSelected: (value) {
              if (value == 'gallery') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WidgetGalleryScreen(),
                  ),
                );
                return;
              }
              final role = UserRole.values.firstWhere(
                (item) => item.name == value,
              );
              setState(() {
                _role = role;
                _index = 0;
              });
            },
            itemBuilder: (context) => [
              for (final role in UserRole.values)
                PopupMenuItem(value: role.name, child: Text(role.displayLabel)),
              if (kDebugMode) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'gallery',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.widgets_outlined),
                    title: Text('Widget gallery'),
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                extended: width >= 1100,
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
            Expanded(
              child: _SectionPlaceholder(
                key: ValueKey('${_role.name}-$_index'),
                role: _role,
                item: selected,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const Map<UserRole, List<_NavigationItem>> _roleNavigation = {
  UserRole.propertyOperations: [
    _NavigationItem('Overview', Icons.dashboard_outlined, Icons.dashboard),
    _NavigationItem('Properties', Icons.apartment_outlined, Icons.apartment),
    _NavigationItem('Complaints', Icons.report_outlined, Icons.report),
    _NavigationItem('Team', Icons.groups_outlined, Icons.groups),
  ],
  UserRole.complaintOperations: [
    _NavigationItem('Overview', Icons.dashboard_outlined, Icons.dashboard),
    _NavigationItem('Complaints', Icons.report_outlined, Icons.report),
    _NavigationItem('Tenants', Icons.people_outline, Icons.people),
  ],
  UserRole.technician: [
    _NavigationItem('My jobs', Icons.build_outlined, Icons.build),
    _NavigationItem(
      'Schedule',
      Icons.calendar_month_outlined,
      Icons.calendar_month,
    ),
    _NavigationItem('History', Icons.history, Icons.history),
  ],
  UserRole.propertyOwner: [
    _NavigationItem('Overview', Icons.dashboard_outlined, Icons.dashboard),
    _NavigationItem('Properties', Icons.apartment_outlined, Icons.apartment),
    _NavigationItem('Reports', Icons.analytics_outlined, Icons.analytics),
  ],
  UserRole.tenant: [
    _NavigationItem('Home', Icons.home_outlined, Icons.home),
    _NavigationItem('Complaints', Icons.report_outlined, Icons.report),
    _NavigationItem('Rent', Icons.receipt_long_outlined, Icons.receipt_long),
    _NavigationItem('Profile', Icons.person_outline, Icons.person),
  ],
};

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
    required this.role,
    required this.item,
    super.key,
  });

  final UserRole role;
  final _NavigationItem item;

  @override
  Widget build(BuildContext context) {
    if (item.label == 'Properties') {
      return const PropertyBrowserScreen(showAppBar: false);
    }
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.selectedIcon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(item.label, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${role.displayLabel} workspace'),
          ],
        ),
      ),
    );
  }
}
