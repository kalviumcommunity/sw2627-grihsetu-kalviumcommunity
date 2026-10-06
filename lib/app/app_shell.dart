import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../widgets/placeholder_screen.dart';
import 'user_role.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialRole = UserRole.technician});
  final UserRole initialRole;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late UserRole _role = widget.initialRole;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final items = roleNav[_role]!;
    final wide = MediaQuery.sizeOf(context).width >= AppSpacing.railBreakpoint;
    final body = PlaceholderScreen(title: items[_index].label);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          // TEMPORARY: replaced by real role from Firebase Auth in the auth ticket
          PopupMenuButton<UserRole>(
            tooltip: 'Switch role (dev only)',
            icon: const Icon(Icons.swap_horiz),
            onSelected: (r) => setState(() {
              _role = r;
              _index = 0;
            }),
            itemBuilder: (_) => [
              for (final r in UserRole.values)
                PopupMenuItem(value: r, child: Text(r.name)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                extended: MediaQuery.sizeOf(context).width >= 1100,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final n in items)
                    NavigationRailDestination(
                      icon: Icon(n.icon),
                      selectedIcon: Icon(n.selectedIcon),
                      label: Text(n.label),
                    ),
                ],
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey('$_role-$_index'),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final n in items)
                  NavigationDestination(
                    icon: Icon(n.icon),
                    selectedIcon: Icon(n.selectedIcon),
                    label: n.label,
                  ),
              ],
            ),
    );
  }
}
