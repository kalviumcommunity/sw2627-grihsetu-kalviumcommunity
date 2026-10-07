import 'package:flutter/material.dart';

import '../core/models/user.dart';
import '../theme/app_palette.dart';

/// Lightweight profile header for the authenticated application shell.
///
/// Visibly displays the authenticated user's name, role (using
/// [NullableUserRoleLabel.displayLabel]), and an avatar circle.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  final AppUser profile;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final trimmedName = profile.name.trim();
    final displayName = trimmedName.isNotEmpty ? trimmedName : 'User';
    final initial = trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border, width: 1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.accentSoft,
            child: Text(
              initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.role.displayLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
