import 'package:flutter/material.dart';

import '../../../theme/app_palette.dart';
import '../../../utils/date_time_formatters.dart';
import '../../../utils/rent_rules.dart';
import '../../../widgets/app_card.dart';
import '../rent_models.dart';

/// Reusable presentation widget for a single rent follow-up history entry.
///
/// Renders handler, formatted timestamp, contact method badge, outcome,
/// optional promised payment details, optional next follow-up date,
/// notes, and optional tenant response.
class RentFollowUpHistoryItem extends StatelessWidget {
  const RentFollowUpHistoryItem({
    super.key,
    required this.followUp,
    this.elapsed,
  });

  final RentFollowUp followUp;
  final String? elapsed;

  IconData _methodIcon(FollowUpMethod method) {
    return switch (method) {
      FollowUpMethod.call => Icons.phone,
      FollowUpMethod.message => Icons.chat,
      FollowUpMethod.visit => Icons.person_pin_circle,
      FollowUpMethod.email => Icons.email,
    };
  }

  Color _outcomeColor(FollowUpOutcome outcome, AppPalette palette) {
    return switch (outcome) {
      FollowUpOutcome.paid => palette.success,
      FollowUpOutcome.promisedToPay => palette.warning,
      FollowUpOutcome.refusedOrDisputed => palette.danger,
      FollowUpOutcome.spokeToTenant => palette.accent,
      FollowUpOutcome.noAnswer => palette.ink,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final outcomeColor = _outcomeColor(followUp.outcome, palette);
    final actorDisplay = followUp.actor.trim().isNotEmpty
        ? followUp.actor.trim()
        : 'Staff';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Method badge, outcome label, timestamp
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _methodIcon(followUp.method),
                      size: 14,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      followUp.method.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                followUp.outcome.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: outcomeColor,
                ),
              ),
              Text(
                formatDateTime(followUp.timestamp),
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
            ],
          ),

          // Promised payment details banner (when relevant)
          if (followUp.outcome == FollowUpOutcome.promisedToPay &&
              followUp.promisedDate != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, size: 16, color: palette.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Promised ${followUp.promisedAmount != null ? formatIndianCurrency(followUp.promisedAmount!) : ''} by ${formatDate(followUp.promisedDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Next follow-up date (only shown when present)
          if (followUp.nextFollowUpDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_month, size: 14, color: palette.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Next follow-up: ${formatDate(followUp.nextFollowUpDate)}',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ),
              ],
            ),
          ],

          // Tenant response (distinct from notes, only shown when present and non-empty)
          if (followUp.tenantResponse != null &&
              followUp.tenantResponse!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.reply, size: 14, color: palette.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Response: ${followUp.tenantResponse!.trim()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.ink,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Notes (wrapping cleanly without overflow)
          if (followUp.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              followUp.note.trim(),
              style: TextStyle(fontSize: 13, color: palette.ink),
              softWrap: true,
            ),
          ],

          // Footer: Actor/Handler & Elapsed time
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'By $actorDisplay',
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
              if (elapsed != null && elapsed!.isNotEmpty)
                Text(
                  elapsed!,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
