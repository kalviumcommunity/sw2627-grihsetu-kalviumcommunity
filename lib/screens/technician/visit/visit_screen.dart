import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/enums/complaint_status.dart';
import '../../../core/models/complaint.dart';
import '../../../core/models/complaint_audit_event.dart';
import '../../../repositories/complaint_repository.dart';
import '../../../services/media_picker.dart';
import '../../../theme/app_palette.dart';
import '../../../utils/visit_validators.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_spacing.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/error_state.dart';
import '../../../widgets/skeleton_box.dart';
import '../../../widgets/status_badge.dart';
import 'visit_completion_form.dart';
import 'visit_models.dart';

/// Full-screen phone-first visit management page for technicians.
class VisitScreen extends StatefulWidget {
  const VisitScreen({
    super.key,
    required this.complaintId,
    this.repository,
    this.mediaPicker,
    this.technicianId = 'usr_002',
    this.technicianName = 'Aman Verma',
  });

  final String complaintId;
  final ComplaintRepository? repository;
  final MediaPicker? mediaPicker;
  final String technicianId;
  final String technicianName;

  static Future<void> open(
    BuildContext context, {
    required String complaintId,
    ComplaintRepository? repository,
    MediaPicker? mediaPicker,
    String technicianId = 'usr_002',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitScreen(
          complaintId: complaintId,
          repository: repository,
          mediaPicker: mediaPicker,
          technicianId: technicianId,
        ),
      ),
    );
  }

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  late final ComplaintRepository _repository;
  late final MediaPicker _mediaPicker;

  StreamSubscription<Complaint?>? _complaintSub;
  StreamSubscription<List<ComplaintAuditEvent>>? _eventsSub;

  Complaint? _complaint;
  List<ComplaintAuditEvent> _events = const [];
  bool _isLoading = true;
  Object? _error;
  bool _isActionInProgress = false;

  Timer? _tickerTimer;
  DateTime _now = DateTime.now();

  // Local tracking of evidence photos uploaded during visit
  final List<String> _beforePhotos = [];
  final List<String> _afterPhotos = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InMemoryComplaintRepository();
    _mediaPicker = widget.mediaPicker ?? const MockMediaPicker();
    _startTicker();
    _loadData();
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _complaintSub?.cancel();
    _eventsSub?.cancel();

    _complaintSub = _repository
        .watchComplaint(widget.complaintId)
        .listen(
          (c) {
            if (!mounted) return;
            setState(() {
              _complaint = c;
              _isLoading = false;
            });
          },
          onError: (err) {
            if (!mounted) return;
            setState(() {
              _error = err;
              _isLoading = false;
            });
          },
        );

    _eventsSub = _repository
        .watchAuditEvents(widget.complaintId)
        .listen(
          (events) {
            if (!mounted) return;
            _populatePhotosFromEvents(events);
            setState(() {
              _events = events;
            });
          },
          onError: (err) {
            if (!mounted) return;
            setState(() {
              _error = err;
            });
          },
        );
  }

  void _populatePhotosFromEvents(List<ComplaintAuditEvent> events) {
    for (final event in events) {
      final raw = (event.rawEventType ?? event.eventType.name).toUpperCase();
      if (raw.contains('PHOTO_UPLOADED')) {
        final url = event.metadata['photoUrl']?.toString();
        final group = event.metadata['group']?.toString().toLowerCase();
        if (url != null) {
          if (group == 'before' && !_beforePhotos.contains(url)) {
            _beforePhotos.add(url);
          } else if (group == 'after' && !_afterPhotos.contains(url)) {
            _afterPhotos.add(url);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _complaintSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }

  bool _isAssignedToCurrentTechnician() {
    if (_complaint == null) return false;
    final assigned = _complaint!.currentTechnicianId;
    return assigned != null &&
        assigned.isNotEmpty &&
        assigned == widget.technicianId;
  }

  Future<void> _advanceStep(VisitWorkflowStep step) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    try {
      await _repository.advanceVisitStep(
        widget.complaintId,
        step,
        actorId: widget.technicianId,
        role: 'technician',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update step: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _pickAndUploadPhoto(String group) async {
    final currentList = group == 'before' ? _beforePhotos : _afterPhotos;
    final countErr = VisitValidators.validateAttachmentsCount(
      currentList.length + 1,
    );
    if (countErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(countErr)));
      return;
    }

    try {
      final picked = await _mediaPicker.pick();
      if (picked != null) {
        final name = '${picked.name}_${DateTime.now().millisecondsSinceEpoch}';
        await _repository.addVisitPhoto(
          widget.complaintId,
          photoUrl: name,
          group: group,
          actorId: widget.technicianId,
          role: 'technician',
        );
        setState(() {
          if (group == 'before') {
            _beforePhotos.add(name);
          } else {
            _afterPhotos.add(name);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
      }
    }
  }

  void _removePhoto(String group, String url) {
    setState(() {
      if (group == 'before') {
        _beforePhotos.remove(url);
      } else {
        _afterPhotos.remove(url);
      }
    });
  }

  Future<void> _openCompletionForm() async {
    final workLog = VisitWorkLog.fromEvents(_events);
    final completed = await VisitCompletionForm.open(
      context,
      complaintId: widget.complaintId,
      repository: _repository,
      mediaPicker: _mediaPicker,
      technicianId: widget.technicianId,
      technicianName: widget.technicianName,
      initialAfterPhotos: _afterPhotos,
      onSiteDuration: workLog.totalOnSiteDuration(_now),
    );

    if (completed == true && mounted) {
      // Completed, pops or re-renders
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(title: const Text('Technician Visit')),
        body: _buildLoadingSkeleton(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(title: const Text('Technician Visit')),
        body: ErrorState(
          title: 'Unable to load visit',
          message: _error.toString(),
          onRetry: _loadData,
        ),
      );
    }

    if (_complaint == null) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(title: const Text('Technician Visit')),
        body: const EmptyState(
          icon: Icons.search_off_outlined,
          title: 'Visit not found',
          message: 'The requested complaint record could not be found.',
        ),
      );
    }

    if (!_isAssignedToCurrentTechnician()) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(title: const Text('Technician Visit')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_person_outlined,
                    size: 48,
                    color: palette.danger,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Access Restricted',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'This complaint is not assigned to you. Only the assigned field technician can access visit workflow operations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.muted, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to queue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final c = _complaint!;
    final nextStep = resolveNextVisitStepFromEvents(_events, c.status.value);
    final workLog = VisitWorkLog.fromEvents(_events);
    final previousVisits = PreviousVisitSummary.deriveFromEvents(_events);
    final isRepeat = c.isRepeatVisit || c.visitCount > 0;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(
          'Visit #${c.id}',
          style: const TextStyle(
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Warning banner for repeat complaints
                    if (isRepeat) ...[
                      _buildRepeatWarningBanner(context),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Job header
                    _buildJobHeader(context, c),
                    const SizedBox(height: AppSpacing.md),

                    // Previous visits accordion
                    if (previousVisits.isNotEmpty || isRepeat) ...[
                      _buildPreviousVisitsCard(context, previousVisits),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Visit workflow stepper
                    _buildStepperCard(context, nextStep),
                    const SizedBox(height: AppSpacing.md),

                    // Work log card with live timer
                    _buildWorkLogCard(context, workLog),
                    const SizedBox(height: AppSpacing.md),

                    // Evidence photo groups (Before & After)
                    _buildEvidenceCard(context),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),

            // Sticky bottom action bar
            _buildStickyActionBar(context, nextStep),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // REPEAT WARNING BANNER
  // -------------------------------------------------------------
  Widget _buildRepeatWarningBanner(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: palette.warning, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repeat complaint for this unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Review previous visit logs below to check what was previously diagnosed.',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // JOB HEADER
  // -------------------------------------------------------------
  Widget _buildJobHeader(BuildContext context, Complaint c) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    label: c.priority.displayLabel,
                    tone: c.priority.value == 'urgent'
                        ? StatusBadgeTone.danger
                        : c.priority.value == 'high'
                        ? StatusBadgeTone.warning
                        : StatusBadgeTone.neutral,
                  ),
                  StatusBadge(
                    label: c.status.displayLabel,
                    tone: c.status == ComplaintStatus.resolved
                        ? StatusBadgeTone.success
                        : StatusBadgeTone.accent,
                  ),
                ],
              ),
              Text(
                '#${c.id}',
                style: TextStyle(
                  color: palette.muted,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            c.title,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.home_work_outlined, size: 16, color: palette.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Unit ${c.unitId} · Property ${c.propertyId}',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: palette.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: palette.accent.withValues(alpha: 0.15),
                child: Icon(
                  Icons.person_outline,
                  size: 16,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  'Tenant (${c.tenantId})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined, size: 20),
                tooltip: 'Call tenant stub',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling tenant... (stub)')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                tooltip: 'Message tenant stub',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Messaging tenant... (stub)')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            c.description,
            style: TextStyle(color: palette.ink, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PREVIOUS VISITS CARD
  // -------------------------------------------------------------
  Widget _buildPreviousVisitsCard(
    BuildContext context,
    List<PreviousVisitSummary> visits,
  ) {
    final palette = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('previous_visits_tile'),
          title: Text(
            'Previous visits (${visits.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: palette.ink,
            ),
          ),
          subtitle: Text(
            'Review past diagnostic notes and attempts',
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          leading: Icon(Icons.history_toggle_off, color: palette.accent),
          children: [
            if (visits.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No previous visit notes logged for this complaint.',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  children: [
                    for (final v in visits) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: palette.canvas,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.event_note,
                              size: 18,
                              color: palette.muted,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        v.technicianName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: palette.ink,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${v.date.day}/${v.date.month}/${v.date.year}',
                                        style: TextStyle(
                                          color: palette.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Outcome: ${v.outcome}',
                                    style: TextStyle(
                                      color: palette.accent,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (v.notes != null &&
                                      v.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      v.notes!,
                                      style: TextStyle(
                                        color: palette.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // VISIT WORKFLOW STEPPER
  // -------------------------------------------------------------
  Widget _buildStepperCard(BuildContext context, VisitWorkflowStep? nextStep) {
    final palette = context.palette;
    final workLog = VisitWorkLog.fromEvents(_events);

    DateTime? getStepTime(VisitWorkflowStep step) {
      return switch (step) {
        VisitWorkflowStep.accepted => workLog.acceptedTime,
        VisitWorkflowStep.travelling => workLog.travelStartTime,
        VisitWorkflowStep.arrived => workLog.arrivalTime,
        VisitWorkflowStep.inspection => workLog.inspectionStartTime,
        VisitWorkflowStep.repairing => workLog.repairStartTime,
        VisitWorkflowStep.completed => workLog.completionTime,
      };
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Visit Stepper',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: palette.ink,
                ),
              ),
              Text(
                nextStep != null ? 'Next: ${nextStep.label}' : 'Completed',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final step in VisitWorkflowStep.values) ...[
            _buildStepRow(
              context: context,
              step: step,
              timestamp: getStepTime(step),
              isNext: nextStep == step,
              isCompleted:
                  getStepTime(step) != null ||
                  (nextStep != null && step.index < nextStep.index),
              onTapNext: () {
                if (step == VisitWorkflowStep.completed) {
                  _openCompletionForm();
                } else {
                  _advanceStep(step);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required BuildContext context,
    required VisitWorkflowStep step,
    required DateTime? timestamp,
    required bool isNext,
    required bool isCompleted,
    required VoidCallback onTapNext,
  }) {
    final palette = context.palette;

    Widget iconWidget;
    if (isCompleted) {
      iconWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    } else if (isNext) {
      iconWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
      );
    } else {
      iconWidget = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.canvas,
          shape: BoxShape.circle,
          border: Border.all(color: palette.border, width: 2),
        ),
        child: Center(
          child: Text(
            '${step.index + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: palette.muted,
            ),
          ),
        ),
      );
    }

    String? timeFormatted;
    if (timestamp != null) {
      final h = timestamp.hour.toString().padLeft(2, '0');
      final m = timestamp.minute.toString().padLeft(2, '0');
      timeFormatted = '$h:$m';
    }

    return InkWell(
      key: Key('stepper_step_${step.name}'),
      // ONLY the next step is tappable. Going backwards is not allowed.
      onTap: isNext ? onTapNext : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: isNext || isCompleted
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isNext
                          ? palette.accent
                          : (isCompleted ? palette.ink : palette.muted),
                      fontSize: 14,
                    ),
                  ),
                  if (isNext)
                    Text(
                      'Tap to: ${step.actionLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (timeFormatted != null)
              Text(
                timeFormatted,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.muted,
                ),
              ),
            if (isNext) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: palette.accent),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // WORK LOG CARD (Read-only, derived from events)
  // -------------------------------------------------------------
  Widget _buildWorkLogCard(BuildContext context, VisitWorkLog log) {
    final palette = context.palette;
    final duration = log.totalOnSiteDuration(_now);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final liveTimerText =
        '${hours.toString().padLeft(2, "0")}:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}';

    String formatTime(DateTime? t) {
      if (t == null) return '--:--';
      return '${t.hour.toString().padLeft(2, "0")}:${t.minute.toString().padLeft(2, "0")}';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Work Log',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: palette.ink,
                ),
              ),
              if (log.isOnSiteInProgress)
                StatusBadge(
                  label: 'Live: $liveTimerText',
                  tone: StatusBadgeTone.accent,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildLogItem(
                  context,
                  label: 'Arrival time',
                  value: formatTime(log.arrivalTime),
                  icon: Icons.login,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildLogItem(
                  context,
                  label: 'Work started',
                  value: formatTime(log.workStartTime),
                  icon: Icons.play_arrow,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildLogItem(
                  context,
                  label: 'Work ended',
                  value: formatTime(log.completionTime),
                  icon: Icons.done_all,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildLogItem(
                  context,
                  label: 'Time on site',
                  value: log.arrivalTime != null ? liveTimerText : '--:--',
                  icon: Icons.timer_outlined,
                  highlight: log.isOnSiteInProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: highlight
            ? palette.accent.withValues(alpha: 0.08)
            : palette.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? palette.accent : palette.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight ? palette.accent : palette.muted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: highlight ? palette.accent : palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // EVIDENCE CARD (Before & After Photo Groups)
  // -------------------------------------------------------------
  Widget _buildEvidenceCard(BuildContext context) {
    final palette = context.palette;
    final totalCount = _beforePhotos.length + _afterPhotos.length;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Evidence Photos',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: palette.ink,
                ),
              ),
              StatusBadge(
                label: '$totalCount/12 uploaded',
                tone: totalCount > 0
                    ? StatusBadgeTone.accent
                    : StatusBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (totalCount == 0)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_camera_back_outlined,
                    size: 24,
                    color: palette.muted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'No photos uploaded yet. Take "Before" photos to document existing conditions.',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          _buildPhotoGroupSection(
            context,
            groupTitle: 'Before Photos',
            groupKey: 'before',
            photos: _beforePhotos,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPhotoGroupSection(
            context,
            groupTitle: 'After Photos',
            groupKey: 'after',
            photos: _afterPhotos,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGroupSection(
    BuildContext context, {
    required String groupTitle,
    required String groupKey,
    required List<String> photos,
  }) {
    final palette = context.palette;
    final canAdd = photos.length < 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              '$groupTitle (${photos.length}/6)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: palette.ink,
              ),
            ),
            if (canAdd)
              TextButton.icon(
                key: Key('add_${groupKey}_photo_button'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: palette.accent,
                ),
                onPressed: () => _pickAndUploadPhoto(groupKey),
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Add photo', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final url in photos)
              _buildPhotoThumbnail(
                context,
                groupKey: groupKey,
                photoUrl: url,
                onRemove: () => _removePhoto(groupKey, url),
              ),
            if (photos.isEmpty)
              Container(
                width: 90,
                height: 70,
                decoration: BoxDecoration(
                  color: palette.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: palette.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Empty',
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context, {
    required String groupKey,
    required String photoUrl,
    required VoidCallback onRemove,
  }) {
    final palette = context.palette;
    return Stack(
      children: [
        Container(
          width: 90,
          height: 70,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 24, color: palette.accent),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  photoUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: palette.ink),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            key: Key('remove_photo_$photoUrl'),
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: Icon(Icons.close, size: 14, color: palette.danger),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STICKY BOTTOM ACTION BAR
  // -------------------------------------------------------------
  Widget _buildStickyActionBar(
    BuildContext context,
    VisitWorkflowStep? nextStep,
  ) {
    final palette = context.palette;

    if (nextStep == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to queue', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    final isCompleteAction = nextStep == VisitWorkflowStep.completed;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56, // 56px large primary buttons
          child: FilledButton.icon(
            key: const Key('sticky_bottom_action_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: isCompleteAction
                  ? palette.success
                  : palette.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isActionInProgress
                ? null
                : () {
                    if (isCompleteAction) {
                      _openCompletionForm();
                    } else {
                      _advanceStep(nextStep);
                    }
                  },
            icon: _isActionInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isCompleteAction
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                    size: 20,
                  ),
            label: Text(
              _isActionInProgress ? 'Saving...' : nextStep.actionLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(height: 120, width: double.infinity),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 140, width: double.infinity),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 80, width: double.infinity),
        ],
      ),
    );
  }
}
