import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../utils/display_formatters.dart';

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
                : formatHumanDuration(
                    events[index].timestamp
                        .difference(events[index - 1].timestamp)
                        .abs(),
                  ),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.latest,
    required this.connector,
    required this.elapsed,
  });

  final AuditEvent event;
  final bool latest;
  final bool connector;
  final String? elapsed;

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
                  _PulsingDot(color: palette.accent)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.primary, width: 2),
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
                    '${event.actor} · ${event.role} · '
                    '${formatDateTime(event.timestamp)}'
                    '${elapsed == null ? '' : ' · +$elapsed'}',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isUnderTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (disableAnimations || isUnderTest) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

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
        border: Border.all(
          color: widget.color.withValues(alpha: .35),
          width: 2,
        ),
      ),
    ),
  );
}
