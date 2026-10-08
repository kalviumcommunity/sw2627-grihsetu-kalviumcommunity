import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared conversion helpers for Firestore-backed domain models.
///
/// Persisted dates are Firestore [Timestamp] values. [FieldValue] server
/// timestamps belong in repository write payloads, not in domain models.
DateTime? dateTimeFromFirestore(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Timestamp? timestampFromDateTime(DateTime? value) {
  if (value == null) return null;
  return Timestamp.fromDate(value.toUtc());
}

/// Adds authoritative server timestamps to a create payload.
Map<String, dynamic> withServerCreateTimestamps(Map<String, dynamic> data) => {
  ...data,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// Adds an authoritative server timestamp to an update payload.
Map<String, dynamic> withServerUpdateTimestamp(Map<String, dynamic> data) => {
  ...data,
  'updatedAt': FieldValue.serverTimestamp(),
};
