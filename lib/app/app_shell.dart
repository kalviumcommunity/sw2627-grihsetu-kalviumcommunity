import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/enums/user_role.dart';
import '../core/models/user.dart';
import '../repositories/complaint_repository.dart';
import '../repositories/property_repository.dart';
import '../screens/complaints/complaint_create_screen.dart';
import '../screens/dev/reference_data_seed_screen.dart';
import '../screens/dev/widget_gallery.dart';
import '../screens/property/property_browser_screen.dart';
import '../services/auth_failure.dart';
import '../services/auth_service.dart';
import '../services/reference_data_seed_service.dart';
import '../widgets/profile_header.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.profile,
    this.authService,
    this.seedService,
    this.complaintRepository,
    this.propertyRepository,
  });

  final AppUser? profile;
  final AuthService? authService;
  final ReferenceDataSeedService? seedService;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final UserRole _role = widget.profile?.role ?? UserRole.technician;
  int _index = 0;
  bool _isSigningOut = false;

  static const double _railBreakpoint = 840;

  AuthService get _authService => widget.authService ?? AuthService.firebase();

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await _authService.signOut();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
      return;
    }
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
            tooltip: 'Developer tools',
            icon: const Icon(Icons.swap_horiz),
            onSelected: (value) {
              if (value == 'gallery') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WidgetGalleryScreen(),
                  ),
                );
              } else if (value == 'seed_reference') {
                final currentProfile = widget.profile;
                if (currentProfile != null &&
                    currentProfile.isAuthorized &&
                    currentProfile.role.isOperationsStaff) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReferenceDataSeedScreen(
                        profile: currentProfile,
                        seedService: widget.seedService,
                      ),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) {
              final isOpsStaff =
                  widget.profile?.isAuthorized == true &&
                  widget.profile!.role.isOperationsStaff;
              return [
                if (isOpsStaff)
                  const PopupMenuItem(
                    value: 'seed_reference',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.dataset_outlined),
                      title: Text('Seed reference data'),
                    ),
                  ),
                if (kDebugMode) ...[
                  if (isOpsStaff) const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'gallery',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.widgets_outlined),
                      title: Text('Widget gallery'),
                    ),
                  ),
                ],
              ];
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            onPressed: _isSigningOut ? null : _signOut,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.profile != null)
                    ProfileHeader(profile: widget.profile!),
                  Expanded(
                    child: _SectionPlaceholder(
                      key: ValueKey('${_role.name}-$_index'),
                      role: _role,
                      item: selected,
                      profile: widget.profile,
                      authService: widget.authService,
                      complaintRepository: widget.complaintRepository,
                      propertyRepository: widget.propertyRepository,
                    ),
                  ),
                ],
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
    _NavigationItem('Today', Icons.today_outlined, Icons.today),
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
    this.profile,
    this.authService,
    this.complaintRepository,
    this.propertyRepository,
    super.key,
  });

  final UserRole role;
  final _NavigationItem item;
  final AppUser? profile;
  final AuthService? authService;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;

  @override
  Widget build(BuildContext context) {
    if (item.label == 'Properties') {
      return const PropertyBrowserScreen(showAppBar: false);
    }
    if (item.label == 'Complaints') {
      return ComplaintCreateScreen(
        profile: profile,
        authService: authService,
        complaintRepository: complaintRepository,
        propertyRepository: propertyRepository,
        showAppBar: false,
      );
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
