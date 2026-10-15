import 'package:flutter/material.dart';

import 'package:grihsetu/core/enums/complaint_category.dart';
import 'package:grihsetu/repositories/assignment_repository.dart';
import 'package:grihsetu/theme/app_palette.dart';
import 'package:grihsetu/widgets/app_spacing.dart';
import 'package:grihsetu/widgets/repeat_indicator.dart';
import 'package:grihsetu/widgets/status_badge.dart';

/// Card row representing a selectable technician option.
class TechnicianCard extends StatefulWidget {
  const TechnicianCard({
    super.key,
    required this.technician,
    required this.isSelected,
    required this.onSelect,
    this.complaintCategory,
  });

  final TechnicianOption technician;
  final bool isSelected;
  final VoidCallback onSelect;
  final ComplaintCategory? complaintCategory;

  @override
  State<TechnicianCard> createState() => _TechnicianCardState();
}

class _TechnicianCardState extends State<TechnicianCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final tech = widget.technician;
    final isSelected = widget.isSelected;

    final fill = isSelected
        ? palette.accentSoft
        : _hovered
        ? palette.raised
        : palette.surface;

    final borderColor = isSelected || _focused
        ? palette.accent
        : palette.border;
    final borderWidth = isSelected || _focused ? 2.0 : 1.0;

    return FocusableActionDetector(
      onShowFocusHighlight: (val) => setState(() => _focused = val),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onSelect(),
        ),
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSelect,
              borderRadius: BorderRadius.circular(12),
              focusColor: palette.accentSoft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar initials circle
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.accent
                                  : palette.accentSoft,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tech.initials,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isSelected
                                    ? palette.surface
                                    : palette.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: AppSpacing.xs + 2,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      tech.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: palette.ink,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (tech.isBestMatch)
                                      const StatusBadge(
                                        label: 'Best match',
                                        tone: StatusBadgeTone.accent,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tech.phone,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _AvailabilityBadge(availability: tech.availability),
                          const SizedBox(width: AppSpacing.xs + 2),
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isSelected ? palette.accent : palette.muted,
                            size: 22,
                            semanticLabel: isSelected
                                ? 'Selected technician'
                                : 'Select technician',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Specialties chips
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final specialty in tech.specialties)
                            _SpecialtyChip(
                              label: specialty.displayLabel,
                              isHighlighted:
                                  specialty == widget.complaintCategory,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Workload bar
                      _WorkloadBar(jobCount: tech.todayJobCount),
                      // Repeat visit note
                      if (tech.previousVisitsToUnit > 0) ...[
                        const SizedBox(height: AppSpacing.xs + 2),
                        RepeatIndicator(
                          count: tech.previousVisitsToUnit >= 2
                              ? tech.previousVisitsToUnit
                              : 2,
                          label:
                              'Previously visited (${tech.previousVisitsToUnit}x)',
                          tooltip:
                              'Previously visited this unit ${tech.previousVisitsToUnit} times',
                        ),
                      ],
                      // Off duty inline notice
                      if (tech.availability ==
                          TechnicianAvailability.offDuty) ...[
                        const SizedBox(height: AppSpacing.xs + 2),
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: palette.warning,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Technician is currently off duty',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.availability});

  final TechnicianAvailability availability;

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (availability) {
      TechnicianAvailability.available => (
        StatusBadgeTone.success,
        'Available',
      ),
      TechnicianAvailability.onJob => (StatusBadgeTone.neutral, 'On a job'),
      TechnicianAvailability.offDuty => (StatusBadgeTone.warning, 'Off duty'),
    };
    return StatusBadge(label: label, tone: tone);
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label, required this.isHighlighted});

  final String label;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted ? palette.accentSoft : palette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted ? palette.accent : palette.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          color: isHighlighted ? palette.accent : palette.ink,
        ),
      ),
    );
  }
}

class _WorkloadBar extends StatelessWidget {
  const _WorkloadBar({required this.jobCount});

  final int jobCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final ratio = (jobCount / 8.0).clamp(0.0, 1.0);
    final isHigh = jobCount > 5;
    final barColor = isHigh ? palette.warning : palette.accent;

    return Row(
      children: [
        Text(
          'Today: $jobCount jobs',
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.muted,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 4,
              color: palette.shimmer,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(color: barColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
