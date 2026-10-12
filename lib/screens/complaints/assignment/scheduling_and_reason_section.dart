import 'package:flutter/material.dart';

import 'package:grihsetu/repositories/assignment_repository.dart';
import 'package:grihsetu/theme/app_palette.dart';
import 'package:grihsetu/utils/assignment_validators.dart';
import 'package:grihsetu/widgets/app_spacing.dart';

/// Form section handling reassignment reason, scheduling date/time, and technician note.
class SchedulingAndReasonSection extends StatelessWidget {
  const SchedulingAndReasonSection({
    super.key,
    required this.isReassign,
    this.currentTechnician,
    required this.selectedReason,
    required this.onReasonChanged,
    required this.visitDate,
    required this.onDateSelected,
    required this.selectedSlot,
    required this.onSlotSelected,
    required this.noteController,
    required this.noteLength,
    required this.onNoteChanged,
    required this.warnings,
  });

  final bool isReassign;
  final TechnicianOption? currentTechnician;
  final ReassignmentReason? selectedReason;
  final ValueChanged<ReassignmentReason?> onReasonChanged;
  final DateTime? visitDate;
  final ValueChanged<DateTime?> onDateSelected;
  final AssignmentSlot? selectedSlot;
  final ValueChanged<AssignmentSlot?> onSlotSelected;
  final TextEditingController noteController;
  final int noteLength;
  final ValueChanged<String> onNoteChanged;
  final List<String> warnings;

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[(date.month - 1).clamp(0, 11)]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reassignment Reason Selector
        if (isReassign) ...[
          Text(
            'Reason for reassignment *',
            style: theme.textTheme.titleSmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          DropdownButtonFormField<ReassignmentReason>(
            initialValue: selectedReason,
            key: const Key('reassignment_reason_dropdown'),
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            hint: Text(
              'Select reassignment reason',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
            items: [
              for (final r in ReassignmentReason.values)
                DropdownMenuItem(
                  value: r,
                  child: Text(
                    r.label,
                    style: TextStyle(color: palette.ink, fontSize: 13),
                  ),
                ),
            ],
            onChanged: onReasonChanged,
          ),
          if (selectedReason == ReassignmentReason.other) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              'Please explain the reason in the note below *',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],

        // Optional Scheduling Section
        Text(
          'Schedule visit (optional)',
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('schedule_date_picker_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  side: BorderSide(
                    color: visitDate != null ? palette.accent : palette.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: visitDate != null
                      ? palette.accentSoft
                      : palette.surface,
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: visitDate ?? now,
                    firstDate: now,
                    lastDate: now.add(
                      const Duration(
                        days: AssignmentValidators.maxScheduleDaysAhead,
                      ),
                    ),
                  );
                  if (picked != null) {
                    onDateSelected(picked);
                  }
                },
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: visitDate != null ? palette.accent : palette.muted,
                ),
                label: Text(
                  visitDate == null
                      ? 'Select date'
                      : _formatDate(visitDate!),
                  style: TextStyle(
                    fontSize: 13,
                    color: visitDate != null ? palette.accent : palette.ink,
                    fontWeight: visitDate != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (visitDate != null) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: const Key('clear_schedule_date_button'),
                tooltip: 'Clear date',
                icon: Icon(Icons.clear, size: 18, color: palette.muted),
                onPressed: () {
                  onDateSelected(null);
                  onSlotSelected(null);
                },
              ),
            ],
          ],
        ),

        // Time slot selection (visible / required if date is selected)
        if (visitDate != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Select time slot *',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs,
            children: [
              for (final slot in AssignmentSlot.values)
                ChoiceChip(
                  key: Key('slot_chip_${slot.name}'),
                  label: Text('${slot.label} (${slot.timeRange.split(' - ').first})'),
                  selected: selectedSlot == slot,
                  selectedColor: palette.accentSoft,
                  backgroundColor: palette.surface,
                  side: BorderSide(
                    color: selectedSlot == slot
                        ? palette.accent
                        : palette.border,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selectedSlot == slot ? palette.accent : palette.ink,
                    fontWeight: selectedSlot == slot
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (val) => onSlotSelected(val ? slot : null),
                ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // Optional Note to Technician
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Note to technician',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$noteLength/${AssignmentValidators.maxNoteLength}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: noteLength > AssignmentValidators.maxNoteLength
                    ? palette.danger
                    : palette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: noteController,
          key: const Key('assignment_note_field'),
          maxLength: AssignmentValidators.maxNoteLength,
          maxLines: 3,
          minLines: 2,
          buildCounter: (
            context, {
            required currentLength,
            required isFocused,
            maxLength,
          }) =>
              null, // Counter is shown above
          decoration: InputDecoration(
            hintText: 'e.g. Call tenant 15 minutes before arrival...',
            hintStyle: TextStyle(color: palette.muted, fontSize: 13),
            filled: true,
            fillColor: palette.surface,
            contentPadding: const EdgeInsets.all(AppSpacing.sm + 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.border),
            ),
          ),
          onChanged: onNoteChanged,
        ),

        // Warnings inline banner
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: palette.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: palette.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assignment warning',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: palette.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final w in warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $w',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
