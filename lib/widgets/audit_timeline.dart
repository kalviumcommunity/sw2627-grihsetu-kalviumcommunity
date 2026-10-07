import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

enum AuditTone { neutral, accent, success, warning, danger }

class AuditEvent {
  const AuditEvent({
    required this.title,
    required this.actor,
    required this.role,
    required this.timestamp,
    this.note,
    this.tone = AuditTone.neutral,
  });

  final String title;
  final String actor;
  final String role;
  final DateTime timestamp;
  final String? note;
  final AuditTone tone;
}

class AuditTimeline extends StatelessWidget {
  const AuditTimeline({super.key, required this.events})
    : assert(events.length >= 1 && events.length <= 30);

  final List<AuditEvent> events;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < events.length; index++)
          _TimelineRow(
            event: events[index],
            latest: index == events.length - 1,
            connector: index < events.length - 1,
            elapsed: index == 0
                ? null
                : _elapsed(
                    events[index].timestamp
                        .difference(events[index - 1].timestamp)
                        .abs(),
                  ),
            color: _toneColor(palette, events[index].tone),
          ),
      ],
    );
  }

  Color _toneColor(AppPalette palette, AuditTone tone) => switch (tone) {
    AuditTone.neutral => palette.muted,
    AuditTone.accent => palette.accent,
    AuditTone.success => palette.success,
    AuditTone.warning => palette.warning,
    AuditTone.danger => palette.danger,
  };

  String _elapsed(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d between events';
    if (duration.inHours > 0) return '${duration.inHours}h between events';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m between events';
    return 'Moments between events';
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.latest,
    required this.connector,
    required this.elapsed,
    required this.color,
  });

  final AuditEvent event;
  final bool latest;
  final bool connector;
  final String? elapsed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (latest)
                  _PulsingDot(color: color)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (connector)
                  Expanded(child: Container(width: 2, color: palette.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.actor} · ${event.role}',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(event.timestamp),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.muted),
                  ),
                  if (event.note != null && event.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      event.note!,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: palette.ink),
                    ),
                  ],
                  if (elapsed != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      elapsed!,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: palette.accent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} · ${two(value.hour)}:${two(value.minute)}';
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.62, end: 1).animate(_controller),
    child: Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.28),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    ),
  );
}
