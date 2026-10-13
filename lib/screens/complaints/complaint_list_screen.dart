import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
import '../../widgets/skeleton_box.dart';
import 'complaint_create_screen.dart';
import 'complaint_detail_screen.dart';
import 'complaint_view_models.dart';

/// Screen displaying live Firestore complaints stream with loading, empty, and error states.
class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({
    super.key,
    this.profile,
    this.authService,
    this.complaintRepository,
    this.propertyRepository,
    this.showAppBar = true,
    this.propertyId,
    this.unitId,
    this.tenantId,
  });

  final AppUser? profile;
  final AuthService? authService;
  final ComplaintRepository? complaintRepository;
  final PropertyRepository? propertyRepository;
  final bool showAppBar;
  final String? propertyId;
  final String? unitId;
  final String? tenantId;

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  late ComplaintRepository _repository;
  late ComplaintReferenceResolver _resolver;
  late Stream<List<Complaint>> _complaintsStream;
  bool _isRetrying = false;
  bool _isResolvingReferences = false;

  bool get _canCreateComplaint => widget.profile?.role != UserRole.technician;

  @override
  void initState() {
    super.initState();
    _initRepository();
    _initResolver();
    _initStream();
  }

  void _initRepository() {
    _repository =
        widget.complaintRepository ??
        FirestoreComplaintRepository(identity: widget.authService);
  }

  void _initResolver() {
    _resolver = ComplaintReferenceResolver(
      propertyRepository: widget.propertyRepository,
    );
  }

  void _initStream() {
    _complaintsStream = _repository.watchComplaints(
      propertyId: widget.propertyId,
      unitId: widget.unitId,
      tenantId: widget.tenantId,
    );
  }

  @override
  void didUpdateWidget(ComplaintListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaintRepository != widget.complaintRepository ||
        oldWidget.propertyId != widget.propertyId ||
        oldWidget.unitId != widget.unitId ||
        oldWidget.tenantId != widget.tenantId) {
      _initRepository();
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

  String _userFriendlyErrorMessage(Object? error) {
    if (error is ComplaintFailure) {
      return error.message;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'You do not have permission to view complaints.',
        'unavailable' => 'Complaint service is temporarily unavailable. Check your connection.',
        'not-found' => 'Complaint records could not be found.',
        _ => 'Unable to load complaints. Please try again.',
      };
    }
    return 'Unable to load complaints. Please check your connection and try again.';
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

  void _openCreateComplaint() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintCreateScreen(
          profile: widget.profile,
          authService: widget.authService,
          complaintRepository: _repository,
          propertyRepository: widget.propertyRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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

              // 2. Loading state: waiting and no cached data
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

              final complaints = snapshot.data ?? [];

              // 3. Empty state: resolved with 0 records
              if (complaints.isEmpty) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No complaints yet',
                    message: 'All clear! When complaints are submitted, they will appear here in real time.',
                    actionLabel: _canCreateComplaint
                        ? 'Register complaint'
                        : null,
                    onAction: _canCreateComplaint ? _openCreateComplaint : null,
                  ),
                );
              }

              // Asynchronously resolve unknown property/unit references safely
              _resolveReferencesIfNeeded(complaints);

              // 4. Populated data state
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: complaints.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final complaint = complaints[index];
                  return ComplaintCard(
                    key: Key('complaint-${complaint.id}'),
                    complaint: complaint,
                    propertyName: _resolver.getPropertyName(
                      complaint.propertyId,
                    ),
                    unitNumber: _resolver.getUnitNumber(complaint.unitId),
                    onTap: () => _openDetail(complaint),
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
          ? AppBar(
              title: const Text('Complaints'),
              actions: [
                if (_canCreateComplaint)
                  IconButton(
                    tooltip: 'Register complaint',
                    icon: const Icon(Icons.add),
                    onPressed: _openCreateComplaint,
                  ),
              ],
            )
          : null,
      body: body,
      floatingActionButton: _canCreateComplaint
          ? FloatingActionButton.extended(
              onPressed: _openCreateComplaint,
              icon: const Icon(Icons.add),
              label: const Text('New complaint'),
            )
          : null,
    );
  }
}
