import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/fixtures/sample_fixtures.dart';
import '../core/models/rent_record.dart';
import '../utils/property_metrics.dart';
import 'complaint_store.dart';
import 'property_repository.dart';
import 'rent_repository.dart';

/// Repository for observing and fetching property operational metrics.
///
/// Derived directly from [ComplaintStore], [PropertyRepository], and [RentRepository]
/// without intermediate caching or independent mutation states.
abstract interface class PropertySummaryRepository {
  /// Watches real-time summary for a single property identified by [propertyId].
  Stream<PropertySummary?> watch(
    String propertyId, {
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
    Duration debounce = const Duration(milliseconds: 100),
  });

  /// Watches real-time summaries for all active properties.
  Stream<List<PropertySummary>> watchAll({
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
    Duration debounce = const Duration(milliseconds: 100),
  });

  /// Asynchronously computes a single snapshot for [propertyId].
  Future<PropertySummary?> getSummary(
    String propertyId, {
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
  });

  /// Asynchronously computes summaries for all active properties.
  Future<List<PropertySummary>> getAllSummaries({
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
  });
}

/// Canonical derived implementation of [PropertySummaryRepository].
class DerivedPropertySummaryRepository implements PropertySummaryRepository {
  DerivedPropertySummaryRepository({
    ComplaintStore? complaintStore,
    PropertyRepository? propertyRepository,
    RentRepository? rentRepository,
    this.rentStream,
  }) : _complaintStore = complaintStore ?? ComplaintStore.instance,
       _propertyRepository = propertyRepository ?? InMemoryPropertyRepository(),
       _rentRepository = rentRepository ?? InMemoryRentRepository();

  final ComplaintStore _complaintStore;
  final PropertyRepository _propertyRepository;
  final RentRepository _rentRepository;
  final Stream<List<RentRecord>>? rentStream;

  @override
  Stream<PropertySummary?> watch(
    String propertyId, {
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
    Duration debounce = const Duration(milliseconds: 100),
  }) {
    late StreamController<PropertySummary?> controller;
    StreamSubscription<dynamic>? complaintSub;
    StreamSubscription<dynamic>? rentSub;
    Timer? debounceTimer;

    Future<void> computeAndEmit() async {
      if (controller.isClosed) return;
      try {
        final effectiveNow = now ?? DateTime.now();
        final properties = await _propertyRepository.getProperties();
        final property = properties
            .where((p) => p.id == propertyId)
            .firstOrNull;
        if (property == null) {
          if (!controller.isClosed) controller.add(null);
          return;
        }

        final units = await _propertyRepository.getUnits(propertyId);
        final complaints = _complaintStore.snapshot;
        final rentItems = await _rentRepository.list(propertyId: propertyId);
        final rentRecords = rentItems.map((i) => i.record).toList();

        final summary = calculatePropertySummary(
          property: property,
          units: units,
          complaints: complaints,
          rentRecords: rentRecords,
          periodDays: period.days,
          now: effectiveNow,
        );

        if (!controller.isClosed) {
          controller.add(summary);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    void triggerEmission() {
      debounceTimer?.cancel();
      debounceTimer = Timer(debounce, computeAndEmit);
    }

    controller = StreamController<PropertySummary?>(
      onListen: () {
        // Immediate first calculation
        computeAndEmit();

        complaintSub = _complaintStore.watchAll().listen(
          (_) {
            triggerEmission();
          },
          onError: (Object err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

        if (rentStream != null) {
          rentSub = rentStream!.listen(
            (_) {
              triggerEmission();
            },
            onError: (Object err) {
              if (!controller.isClosed) controller.addError(err);
            },
          );
        }
      },
      onCancel: () {
        debounceTimer?.cancel();
        complaintSub?.cancel();
        rentSub?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  @override
  Stream<List<PropertySummary>> watchAll({
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
    Duration debounce = const Duration(milliseconds: 100),
  }) {
    late StreamController<List<PropertySummary>> controller;
    StreamSubscription<dynamic>? complaintSub;
    StreamSubscription<dynamic>? rentSub;
    Timer? debounceTimer;

    Future<void> computeAndEmit() async {
      if (controller.isClosed) return;
      try {
        final effectiveNow = now ?? DateTime.now();
        final properties = await _propertyRepository.getProperties();
        final complaints = _complaintStore.snapshot;

        final summaries = <PropertySummary>[];
        for (final property in properties) {
          final units = await _propertyRepository.getUnits(property.id);
          final rentItems = await _rentRepository.list(propertyId: property.id);
          final rentRecords = rentItems.map((i) => i.record).toList();

          final summary = calculatePropertySummary(
            property: property,
            units: units,
            complaints: complaints,
            rentRecords: rentRecords,
            periodDays: period.days,
            now: effectiveNow,
          );
          summaries.add(summary);
        }

        if (!controller.isClosed) {
          controller.add(List<PropertySummary>.unmodifiable(summaries));
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    void triggerEmission() {
      debounceTimer?.cancel();
      debounceTimer = Timer(debounce, computeAndEmit);
    }

    controller = StreamController<List<PropertySummary>>(
      onListen: () {
        // Immediate first emission
        computeAndEmit();

        complaintSub = _complaintStore.watchAll().listen(
          (_) {
            triggerEmission();
          },
          onError: (Object err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

        if (rentStream != null) {
          rentSub = rentStream!.listen(
            (_) {
              triggerEmission();
            },
            onError: (Object err) {
              if (!controller.isClosed) controller.addError(err);
            },
          );
        }
      },
      onCancel: () {
        debounceTimer?.cancel();
        complaintSub?.cancel();
        rentSub?.cancel();
      },
    );

    return controller.stream.distinct(listEquals);
  }

  @override
  Future<PropertySummary?> getSummary(
    String propertyId, {
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final properties = await _propertyRepository.getProperties();
    final property = properties.where((p) => p.id == propertyId).firstOrNull;
    if (property == null) return null;

    final units = await _propertyRepository.getUnits(propertyId);
    final complaints = _complaintStore.snapshot.isNotEmpty
        ? _complaintStore.snapshot
        : SampleFixtures.sampleComplaints;
    final rentItems = await _rentRepository.list(propertyId: propertyId);
    final rentRecords = rentItems.map((i) => i.record).toList();

    return calculatePropertySummary(
      property: property,
      units: units,
      complaints: complaints,
      rentRecords: rentRecords,
      periodDays: period.days,
      now: effectiveNow,
    );
  }

  @override
  Future<List<PropertySummary>> getAllSummaries({
    PropertyPeriod period = PropertyPeriod.days30,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final properties = await _propertyRepository.getProperties();
    final complaints = _complaintStore.snapshot.isNotEmpty
        ? _complaintStore.snapshot
        : SampleFixtures.sampleComplaints;

    final summaries = <PropertySummary>[];
    for (final property in properties) {
      final units = await _propertyRepository.getUnits(property.id);
      final rentItems = await _rentRepository.list(propertyId: property.id);
      final rentRecords = rentItems.map((i) => i.record).toList();

      final summary = calculatePropertySummary(
        property: property,
        units: units,
        complaints: complaints,
        rentRecords: rentRecords,
        periodDays: period.days,
        now: effectiveNow,
      );
      summaries.add(summary);
    }
    return summaries;
  }
}
