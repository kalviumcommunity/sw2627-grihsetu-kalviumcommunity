/// Domain constants for GrihSetu property operations.
abstract final class AppConstants {
  /// Application display name.
  static const String appName = 'GrihSetu';

  /// Application tagline reflecting product problem & mission.
  static const String appTagline =
      'Connecting properties, people, and maintenance through one transparent workflow.';

  /// Minimum number of maintenance visits to qualify as a repeat visit (PRD FR-13).
  static const int repeatVisitThreshold = 1;

  /// Default query page size for lists.
  static const int defaultPageSize = 20;

  /// Maximum photo uploads allowed per visit report (PRD FR-11/P1).
  static const int maxVisitEvidencePhotos = 5;
}
