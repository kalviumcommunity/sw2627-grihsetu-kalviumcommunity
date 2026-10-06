import 'package:flutter/material.dart';

import 'core/constants/constants.dart';
import 'core/enums/enums.dart';
import 'core/fixtures/sample_fixtures.dart';
import 'core/models/models.dart';

class GrihSetuApp extends StatelessWidget {
  const GrihSetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Rich Indigo
          brightness: Brightness.light,
        ),
      ),
      home: const DomainPreviewScreen(),
    );
  }
}

/// Demonstrates type-safe domain models, enums, display labels, and constants.
class DomainPreviewScreen extends StatelessWidget {
  const DomainPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complaints = SampleFixtures.sampleComplaints;
    final rentRecords = SampleFixtures.sampleRentRecords;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                AppConstants.appTagline,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF1E3A8A),
            unselectedLabelColor: Color(0xFF64748B),
            indicatorColor: Color(0xFF1E3A8A),
            tabs: [
              Tab(icon: Icon(Icons.assignment_outlined), text: 'Complaints'),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Rent Follow-Ups',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ComplaintsListView(complaints: complaints),
            _RentRecordsListView(rentRecords: rentRecords),
          ],
        ),
      ),
    );
  }
}

class _ComplaintsListView extends StatelessWidget {
  final List<Complaint> complaints;

  const _ComplaintsListView({required this.complaints});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: complaints.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final complaint = complaints[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusChip(status: complaint.status),
                    const SizedBox(width: 8),
                    _PriorityChip(priority: complaint.priority),
                    const Spacer(),
                    if (complaint.isRepeatVisit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          'Repeat Visit #${complaint.visitCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  complaint.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  complaint.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      complaint.category.displayLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.pin_drop_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Unit ${complaint.unitId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RentRecordsListView extends StatelessWidget {
  final List<RentRecord> rentRecords;

  const _RentRecordsListView({required this.rentRecords});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rentRecords.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = rentRecords[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.month,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Amount Due: ₹${record.amountDue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unit: ${record.unitId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                _RentStatusChip(status: record.status),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ComplaintStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = switch (status) {
      ComplaintStatus.open => (
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
      ),
      ComplaintStatus.assigned => (
        const Color(0xFFF5F3FF),
        const Color(0xFF6D28D9),
      ),
      ComplaintStatus.inProgress => (
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
      ),
      ComplaintStatus.waitingForParts => (
        const Color(0xFFFFF7ED),
        const Color(0xFFC2410C),
      ),
      ComplaintStatus.resolved => (
        const Color(0xFFF0FDF4),
        const Color(0xFF15803D),
      ),
      ComplaintStatus.closed => (
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
      ),
      ComplaintStatus.reopened => (
        const Color(0xFFFEF2F2),
        const Color(0xFFB91C1C),
      ),
      ComplaintStatus.cancelled => (
        const Color(0xFFF8FAFC),
        const Color(0xFF94A3B8),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final ComplaintPriority priority;

  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = switch (priority) {
      ComplaintPriority.low => (
        const Color(0xFFF0FDF4),
        const Color(0xFF16A34A),
      ),
      ComplaintPriority.medium => (
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
      ),
      ComplaintPriority.high => (
        const Color(0xFFFFF7ED),
        const Color(0xFFEA580C),
      ),
      ComplaintPriority.urgent => (
        const Color(0xFFFEF2F2),
        const Color(0xFFDC2626),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.displayLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _RentStatusChip extends StatelessWidget {
  final RentStatus status;

  const _RentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = switch (status) {
      RentStatus.due => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
      RentStatus.contacted => (
        const Color(0xFFF5F3FF),
        const Color(0xFF6D28D9),
      ),
      RentStatus.promised => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      RentStatus.overdue => (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      RentStatus.paid => (const Color(0xFFF0FDF4), const Color(0xFF15803D)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
