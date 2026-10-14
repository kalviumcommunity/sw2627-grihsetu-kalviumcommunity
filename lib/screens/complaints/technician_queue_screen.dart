import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/enums/complaint_priority.dart';
import '../../core/enums/complaint_status.dart';
import '../../core/enums/user_role.dart';
import '../../core/models/complaint.dart';
import '../../core/models/user.dart';
import '../../repositories/complaint_repository.dart';
import '../../repositories/property_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/app_spacing.dart';
import '../../widgets/complaint_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/status_badge.dart';
import 'complaint_detail_screen.dart';
import 'complaint_view_models.dart';
import '../technician/visit/technician_next_step_button.dart';

/// Screen displaying live Firestore stream of active complaints assigned to
/// the currently authenticated field technician.
class TechnicianQueueScreen extends StatefulWidget {
  const TechnicianQueueScreen({
    super.key,
    this.profile,
    this.authService,
    this.complaintRepository,
    this.propertyRepository,
    this.showAppBar = true,
  });

  final AppUser? profile;
  final AuthService? authService;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final bool showAppBar;

  @override
  State<TechnicianQueueScreen> createState() => _TechnicianQueueScreenState();
}

class _TechnicianQueueScreenState extends State<TechnicianQueueScreen> {
  ComplaintRepository? _repository;
  late ComplaintReferenceResolver _resolver;
  Stream<List<Complaint>>? _complaintsStream;
  String? _technicianId;
  bool _isRetrying = false;
  bool _isResolvingReferences = false;

  @override
  void initState() {
    super.initState();
    _initResolver();
    _initStream();
  }

  void _initResolver() {
    _resolver = ComplaintReferenceResolver(
      propertyRepository: widget.propertyRepository,
    );
  }

  String? _resolveAuthenticatedTechnicianId() {
    final profile = widget.profile;
    if (profile == null ||
        !profile.isAuthorized ||
        profile.role != UserRole.technician) {
      return null;
    }
    final trimmedId = profile.id.trim();
    if (trimmedId.isEmpty || trimmedId == 'preview') {
      return null;
    }

    final auth = widget.authService;
    if (auth != null) {
      final user = auth.currentUser;
      if (user == null || user.uid != profile.uid) {
        return null;
      }
    } else if (widget.complaintRepository == null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.uid != profile.uid) {
          return null;
        }
      } catch (_) {
        return null;
      }
    }

    return trimmedId;
  }

  void _initStream() {
    _technicianId = _resolveAuthenticatedTechnicianId();
    if (_technicianId != null) {
      if (widget.complaintRepository != null) {
        _repository = widget.complaintRepository;
      } else {
        try {
          _repository = FirestoreComplaintRepository(
            identity: widget.authService,
          );
        } catch (_) {
          _repository = null;
        }
      }

      if (_repository != null) {
        _complaintsStream = _repository!.watchAssignedComplaints(
          technicianId: _technicianId!,
        );
      } else {
        _complaintsStream = Stream.error(
          const ComplaintFailure(ComplaintFailureCode.network),
        );
      }
    } else {
      _complaintsStream = null;
    }
  }

  @override
  void didUpdateWidget(TechnicianQueueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaintRepository != widget.complaintRepository ||
        oldWidget.profile != widget.profile ||
        oldWidget.authService != widget.authService) {
      _initStream();
    }
    if (oldWidget.propertyRepository != widget.propertyRepository) {
      _initResolver();
    }
  }

  void _retry() {
    setState(() {
      _isRetrying = true;
      _initStream();
    });
  }

  void _resolveReferencesIfNeeded(List<Complaint> complaints) {
    if (_isResolvingReferences) return;
    _isResolvingReferences = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isResolvingReferences = false;
        return;
      }
      _resolver
          .resolveForComplaints(complaints)
          .then((updated) {
            _isResolvingReferences = false;
            if (updated && mounted) {
              setState(() {});
            }
          })
          .catchError((_) {
            _isResolvingReferences = false;
          });
    });
  }

  String _userFriendlyErrorMessage(Object? error) {
    if (error is ComplaintFailure) {
      return error.message;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'You do not have permission to view assigned complaints.',
        'unavailable' => 'Complaint service is temporarily unavailable. Check your connection.',
        'not-found' => 'Assigned complaint records could not be found.',
        _ => 'Unable to load assigned complaints. Please try again.',
      };
    }
    return 'Unable to load assigned complaints. Please check your connection and try again.';
  }

  void _openDetail(Complaint complaint) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintDetailScreen(
          complaint: complaint,
          propertyName: _resolver.getPropertyName(complaint.propertyId),
          unitNumber: _resolver.getUnitNumber(complaint.unitId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Unauthorized or missing technician identity
    if (_technicianId == null || _complaintsStream == null) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: widget.showAppBar
            ? AppBar(title: const Text('Assigned Work'))
            : null,
        body: const SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.md),
              child: EmptyState.restricted(
                title: 'Access restricted',
                message: 'This work queue is only accessible to authorized field technicians.',
              ),
            ),
          ),
        ),
      );
    }

    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: StreamBuilder<List<Complaint>>(
            stream: _complaintsStream,
            builder: (context, snapshot) {
              // 1. Error state
              if (snapshot.hasError) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ErrorState(
                    message: _userFriendlyErrorMessage(snapshot.error),
                    onRetry: _retry,
                    isRetrying: _isRetrying,
                  ),
                );
              }

              // 2. Loading state
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SkeletonList(itemCount: 4),
                );
              }

              // Reset retry state when data arrives
              if (_isRetrying && snapshot.hasData) {
                _isRetrying = false;
              }

              final complaints = snapshot.data ?? const [];

              // 3. Empty state: technician has no assigned active complaints
              if (complaints.isEmpty) {
                return const SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: EmptyState(
                    icon: Icons.task_alt_outlined,
                    title: "You're all caught up",
                    message: 'No active complaints are assigned to you.',
                  ),
                );
              }

              // Asynchronously resolve unknown property/unit references safely
              _resolveReferencesIfNeeded(complaints);

              // 4. Populated queue with field-work grouping:
              // Group 1: Urgent & High Priority
              // Group 2: In-progress work
              // Group 3: Other assigned active work
              final urgentAndHigh = complaints
                  .where((c) => c.priority.isHighOrUrgent)
                  .toList();
              final inProgress = complaints
                  .where(
                    (c) =>
                        !c.priority.isHighOrUrgent &&
                        c.status.isFieldWorkActive,
                  )
                  .toList();
              final otherWork = complaints
                  .where(
                    (c) =>
                        !c.priority.isHighOrUrgent &&
                        !c.status.isFieldWorkActive,
                  )
                  .toList();

              final sections = <_QueueGroupData>[
                if (urgentAndHigh.isNotEmpty)
                  _QueueGroupData(
                    title: 'Urgent & High Priority',
                    badgeTone: StatusBadgeTone.danger,
                    complaints: urgentAndHigh,
                  ),
                if (inProgress.isNotEmpty)
                  _QueueGroupData(
                    title: 'In Progress',
                    badgeTone: StatusBadgeTone.accent,
                    complaints: inProgress,
                  ),
                if (otherWork.isNotEmpty)
                  _QueueGroupData(
                    title: 'Other Assigned Work',
                    badgeTone: StatusBadgeTone.neutral,
                    complaints: otherWork,
                  ),
              ];

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: sections.length,
                itemBuilder: (context, sectionIndex) {
                  final section = sections[sectionIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: SectionHeader(
                            title: section.title,
                            trailing: StatusBadge(
                              label: '${section.complaints.length}',
                              tone: section.badgeTone,
                            ),
                          ),
                        ),
                        for (final complaint in section.complaints) ...[
                          ComplaintCard(
                            key: Key('complaint-${complaint.id}'),
                            complaint: complaint,
                            propertyName: _resolver.getPropertyName(
                              complaint.propertyId,
                            ),
                            unitNumber: _resolver.getUnitNumber(
                              complaint.unitId,
                            ),
                            onTap: () => _openDetail(complaint),
                            bottomAction: _repository != null
                                ? TechnicianNextStepButton(
                                    complaintId: complaint.id,
                                    status: complaint.status,
                                    repository: _repository!,
                                    technicianId: _technicianId ?? 'usr_002',
                                  )
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Assigned Work'))
          : null,
      body: body,
    );
  }
}

class _QueueGroupData {
  const _QueueGroupData({
    required this.title,
    required this.badgeTone,
    required this.complaints,
  });

  final String title;
  final StatusBadgeTone badgeTone;
  final List<Complaint> complaints;
}
