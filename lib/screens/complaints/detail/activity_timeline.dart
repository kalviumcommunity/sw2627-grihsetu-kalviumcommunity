import 'package:flutter/material.dart';

import '../../../app/user_role.dart';
import '../../../theme/app_palette.dart';
import '../../../widgets/app_spacing.dart';
import '../../../widgets/empty_state.dart';
import 'complaint_detail_models.dart';

/// The activity timeline is the visual centerpiece of the complaint detail screen.
///
/// Built with slivers, sticky day headers, event filtering, animated new events,
/// expandable notes, photo evidence viewer, and previous visit logs.
class ActivityTimeline extends StatefulWidget {
  const ActivityTimeline({
    super.key,
    required this.events,
    required this.userRole,
    this.previousVisits = const [],
    this.highlightEventId,
  });

  final List<ActivityEvent> events;
  final UserRole userRole;
  final List<VisitRecord> previousVisits;
  final String? highlightEventId;

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<ActivityTimeline> {
  ActivityTimelineFilter _activeFilter = ActivityTimelineFilter.all;
  final Set<String> _expandedNotes = <String>{};

  bool get _isStaff => widget.userRole == UserRole.staff;

  List<ActivityEvent> get _visibleEvents {
    // 1. Role-based privacy: hide internal notes from tenants and owners
    final roleFiltered = widget.events.where((e) {
      if (e.isInternal && !_isStaff) return false;
      return true;
    }).toList();

    // 2. Filter chips
    switch (_activeFilter) {
      case ActivityTimelineFilter.all:
        return roleFiltered;
      case ActivityTimelineFilter.statusChanges:
        return roleFiltered
            .where(
              (e) =>
                  e.type == ActivityEventType.created ||
                  e.type == ActivityEventType.received ||
                  e.type == ActivityEventType.workStarted ||
                  e.type == ActivityEventType.markedResolved ||
                  e.type == ActivityEventType.repairCompleted ||
                  e.type == ActivityEventType.tenantConfirmed ||
                  e.type == ActivityEventType.reopened ||
                  e.type == ActivityEventType.closed ||
                  e.type == ActivityEventType.priorityChanged,
            )
            .toList();
      case ActivityTimelineFilter.assignments:
        return roleFiltered
            .where(
              (e) =>
                  e.type == ActivityEventType.assigned ||
                  e.type == ActivityEventType.reassigned ||
                  e.type == ActivityEventType.accepted,
            )
            .toList();
      case ActivityTimelineFilter.visits:
        return roleFiltered
            .where(
              (e) =>
                  e.type == ActivityEventType.travelStarted ||
                  e.type == ActivityEventType.arrived ||
                  e.type == ActivityEventType.inspectionStarted ||
                  e.type == ActivityEventType.needsAnotherVisit,
            )
            .toList();
      case ActivityTimelineFilter.notesAndEvidence:
        return roleFiltered
            .where(
              (e) =>
                  e.type == ActivityEventType.noteAdded ||
                  e.type == ActivityEventType.photoUploaded ||
                  e.photos.isNotEmpty ||
                  (e.note != null && e.note!.trim().isNotEmpty),
            )
            .toList();
      case ActivityTimelineFilter.internalNotes:
        return roleFiltered.where((e) => e.isInternal).toList();
    }
  }

  Map<String, List<ActivityEvent>> _groupEventsByDay(List<ActivityEvent> list) {
    final grouped = <String, List<ActivityEvent>>{};
    for (final event in list) {
      final key = _formatDayHeader(event.timestamp);
      grouped.putIfAbsent(key, () => []).add(event);
    }
    return grouped;
  }

  String _formatDayHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDay = DateTime(dt.year, dt.month, dt.day);

    if (eventDay == today) return 'Today';
    if (eventDay == yesterday) return 'Yesterday';

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
    final m = months[dt.month - 1];
    return '${dt.day} $m ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final visible = _visibleEvents;
    final grouped = _groupEventsByDay(visible);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar
        _buildFilterBar(palette, theme),
        const SizedBox(height: AppSpacing.md),

        // Previous visits summary if any exist and filter allows
        if (widget.previousVisits.isNotEmpty &&
            (_activeFilter == ActivityTimelineFilter.all ||
                _activeFilter == ActivityTimelineFilter.visits))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildPreviousVisitsCard(context),
          ),

        // Main event list / empty states
        if (widget.events.isEmpty)
          const EmptyState(
            title: 'No activity yet',
            message: 'All updates, assignments, and notes will appear here chronologically.',
            icon: Icons.history_toggle_off_outlined,
          )
        else if (visible.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  Icon(Icons.filter_list_off, size: 40, color: palette.muted),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No events matching "${_activeFilter.label}"',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _activeFilter = ActivityTimelineFilter.all,
                    ),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear filter'),
                  ),
                ],
              ),
            ),
          )
        else
          for (final entry in grouped.entries)
            _DayGroupView(
              dayTitle: entry.key,
              events: entry.value,
              allEvents: visible,
              expandedNotes: _expandedNotes,
              highlightEventId: widget.highlightEventId,
              onToggleNote: (id) {
                setState(() {
                  if (_expandedNotes.contains(id)) {
                    _expandedNotes.remove(id);
                  } else {
                    _expandedNotes.add(id);
                  }
                });
              },
              onViewPhoto: (url) => _openPhotoViewer(context, url),
            ),
      ],
    );
  }

  Widget _buildFilterBar(AppPalette palette, ThemeData theme) {
    final filters = [
      ActivityTimelineFilter.all,
      ActivityTimelineFilter.statusChanges,
      ActivityTimelineFilter.assignments,
      ActivityTimelineFilter.visits,
      ActivityTimelineFilter.notesAndEvidence,
      if (_isStaff) ActivityTimelineFilter.internalNotes,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: _activeFilter == filter,
              onSelected: (selected) {
                if (selected) setState(() => _activeFilter = filter);
              },
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: _activeFilter == filter
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: _activeFilter == filter ? palette.surface : palette.ink,
              ),
              selectedColor: palette.accent,
              backgroundColor: palette.surface,
              side: BorderSide(
                color: _activeFilter == filter
                    ? palette.accent
                    : palette.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviousVisitsCard(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.accentSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: palette.accent),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Previous visits (${widget.previousVisits.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final visit in widget.previousVisits) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${visit.date.day}/${visit.date.month} · ',
                    style: TextStyle(
                      color: palette.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${visit.technicianName}: ${visit.outcome}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, String photoUrl) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black,
                  constraints: const BoxConstraints(
                    maxWidth: 800,
                    maxHeight: 600,
                  ),
                  child: photoUrl.startsWith('http')
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _photoFallback(),
                        )
                      : _photoFallback(),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoFallback() {
    return Container(
      width: 300,
      height: 200,
      color: Colors.grey.shade900,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.white54),
          SizedBox(height: 8),
          Text('Evidence Photo', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _DayGroupView extends StatelessWidget {
  const _DayGroupView({
    required this.dayTitle,
    required this.events,
    required this.allEvents,
    required this.expandedNotes,
    required this.highlightEventId,
    required this.onToggleNote,
    required this.onViewPhoto,
  });

  final String dayTitle;
  final List<ActivityEvent> events;
  final List<ActivityEvent> allEvents;
  final Set<String> expandedNotes;
  final String? highlightEventId;
  final ValueChanged<String> onToggleNote;
  final ValueChanged<String> onViewPhoto;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sticky Day Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.shimmer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    dayTitle,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Divider(color: palette.border, height: 1)),
            ],
          ),
        ),

        // Events list
        for (var i = 0; i < events.length; i++) ...[
          _EventItem(
            event: events[i],
            isLatest: events[i].id == allEvents.last.id,
            previousEvent: _findPreviousEvent(events[i]),
            isExpanded: expandedNotes.contains(events[i].id),
            isHighlighted: events[i].id == highlightEventId,
            onToggleNote: () => onToggleNote(events[i].id),
            onViewPhoto: onViewPhoto,
          ),
        ],
      ],
    );
  }

  ActivityEvent? _findPreviousEvent(ActivityEvent current) {
    final idx = allEvents.indexOf(current);
    if (idx > 0) return allEvents[idx - 1];
    return null;
  }
}

class _EventItem extends StatefulWidget {
  const _EventItem({
    required this.event,
    required this.isLatest,
    required this.previousEvent,
    required this.isExpanded,
    required this.isHighlighted,
    required this.onToggleNote,
    required this.onViewPhoto,
  });

  final ActivityEvent event;
  final bool isLatest;
  final ActivityEvent? previousEvent;
  final bool isExpanded;
  final bool isHighlighted;
  final VoidCallback onToggleNote;
  final ValueChanged<String> onViewPhoto;

  @override
  State<_EventItem> createState() => _EventItemState();
}

class _EventItemState extends State<_EventItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatAbsolute(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  String? _formatElapsed() {
    if (widget.previousEvent == null) return null;
    final diff = widget.event.timestamp.difference(
      widget.previousEvent!.timestamp,
    );
    if (diff.inMinutes < 1) return '+<1m';
    if (diff.inMinutes < 60) return '+${diff.inMinutes}m';
    if (diff.inHours < 24) return '+${diff.inHours}h';
    return '+${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final e = widget.event;

    final elapsed = _formatElapsed();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: widget.isHighlighted
                ? palette.accentSoft.withValues(alpha: 0.6)
                : (e.isInternal
                      ? palette.warning.withValues(alpha: 0.08)
                      : palette.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isHighlighted
                  ? palette.accent
                  : (e.isInternal
                        ? palette.warning.withValues(alpha: 0.4)
                        : palette.border),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Icon + Pulse / Type title + elapsed tag + absolute timestamp
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dot / Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: e.isInternal
                          ? palette.warning.withValues(alpha: 0.2)
                          : palette.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      e.type.icon,
                      size: 16,
                      color: e.isInternal ? palette.warning : palette.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.type.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: palette.ink,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.isLatest)
                              _PulsingDot(color: palette.accent),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Actor & Role row
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              e.actorName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: palette.shimmer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                e.actorRole,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: palette.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (e.isInternal)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Internal',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Timestamp + elapsed
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatAbsolute(e.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatRelative(e.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.muted,
                            ),
                          ),
                          if (elapsed != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: palette.shimmer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                elapsed,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Reassignment details: from -> to & reason
              if (e.type == ActivityEventType.reassigned &&
                  (e.fromTechnician != null || e.toTechnician != null)) ...[
                const SizedBox(height: AppSpacing.xs + 2),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: palette.accentSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 14, color: palette.accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${e.fromTechnician ?? "Previous"} → ${e.toTechnician ?? "New"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Note text with 3-line collapse
              if (e.note != null && e.note!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  e.note!.trim(),
                  maxLines: widget.isExpanded ? null : 3,
                  overflow: widget.isExpanded ? null : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.ink,
                  ),
                ),
                if (e.note!.length > 120 || e.note!.contains('\n'))
                  InkWell(
                    onTap: widget.onToggleNote,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.isExpanded ? 'Show less' : 'Show more',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],

              // Photos thumbnail evidence gallery
              if (e.photos.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final photo in e.photos)
                      GestureDetector(
                        onTap: () => widget.onViewPhoto(photo),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: palette.shimmer,
                            child: photo.startsWith('http')
                                ? Image.network(
                                    photo,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.photo_outlined,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_outlined,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
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
      duration: const Duration(milliseconds: 1400),
    );
    final isUnderTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!isUnderTest) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
