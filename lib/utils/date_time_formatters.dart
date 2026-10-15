/// Standardized date, time, and duration formatting helpers for GrihSetu.
///
/// Converts UTC and local [DateTime] objects consistently into display strings.
/// By default, timestamps are converted to the device's local timezone ([toLocal] = true)
/// so that UTC timestamps loaded from Firestore are presented in the user's local time.
/// Setting [toLocal] to false preserves the input timezone (useful for tests and UTC logs).
///
/// All functions safely accept nullable inputs and never invoke [DateTime.now]
/// to fabricate missing timestamps.
library;

const List<String> _months = <String>[
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

/// Formats a [DateTime] as a concise date: `15 Oct 2026`.
///
/// Returns [placeholder] (defaults to `'Not recorded'`) if [dateTime] is null.
String formatDate(
  DateTime? dateTime, {
  String placeholder = 'Not recorded',
  bool toLocal = true,
}) {
  if (dateTime == null) return placeholder;
  final dt = toLocal ? dateTime.toLocal() : dateTime;
  final monthIndex = (dt.month - 1).clamp(0, 11);
  return '${dt.day} ${_months[monthIndex]} ${dt.year}';
}

/// Formats a [DateTime] as a 12-hour time with AM/PM: `2:30 PM`.
///
/// Returns [placeholder] (defaults to `'Not recorded'`) if [dateTime] is null.
String formatTime(
  DateTime? dateTime, {
  String placeholder = 'Not recorded',
  bool toLocal = true,
}) {
  if (dateTime == null) return placeholder;
  final dt = toLocal ? dateTime.toLocal() : dateTime;
  final hour24 = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute $period';
}

/// Formats a [DateTime] as date and time: `15 Oct 2026 · 2:30 PM`.
///
/// Returns [placeholder] (defaults to `'Not recorded'`) if [dateTime] is null.
String formatDateTime(
  DateTime? dateTime, {
  String placeholder = 'Not recorded',
  String separator = ' · ',
  bool toLocal = true,
}) {
  if (dateTime == null) return placeholder;
  final date = formatDate(dateTime, placeholder: placeholder, toLocal: toLocal);
  final time = formatTime(dateTime, placeholder: placeholder, toLocal: toLocal);
  return '$date$separator$time';
}

/// Formats an elapsed duration into a concise string such as `2h 15m`, `3d 4h`, `45m`, or `0m`.
///
/// Negative durations are safely clamped to [Duration.zero] (`0m`).
/// Returns [placeholder] (defaults to `'Pending'`) if [duration] is null.
String formatElapsedDuration(
  Duration? duration, {
  String placeholder = 'Pending',
}) {
  if (duration == null) return placeholder;
  if (duration.isNegative || duration == Duration.zero) return '0m';

  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);

  if (days > 0) {
    return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  }
  if (hours > 0) {
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  return '< 1m';
}

/// Formats an elapsed duration between timeline events (e.g., `2h between events`).
///
/// Null, zero, or negative durations safely return `'Moments between events'`.
String formatBetweenEventsDuration(Duration? duration) {
  if (duration == null || duration.isNegative || duration == Duration.zero) {
    return 'Moments between events';
  }
  if (duration.inDays > 0) return '${duration.inDays}d between events';
  if (duration.inHours > 0) return '${duration.inHours}h between events';
  if (duration.inMinutes > 0) return '${duration.inMinutes}m between events';
  return 'Moments between events';
}

/// Formats a [Duration] into an HH:MM:SS live timer string (e.g., `01:23:45`).
///
/// Null or negative durations return `'00:00:00'`.
String formatTimerDuration(Duration? duration) {
  if (duration == null || duration.isNegative) return '00:00:00';
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// Safely parses an ISO date string or returns null if unparseable.
DateTime? parseDateTime(String? dateStr) {
  if (dateStr == null || dateStr.trim().isEmpty) return null;
  return DateTime.tryParse(dateStr.trim());
}

/// Formats an ISO date string into `15 Oct 2026`.
///
/// Returns [placeholder] (defaults to `'Not recorded'`) if unparseable or null.
String formatDateString(
  String? dateStr, {
  String placeholder = 'Not recorded',
  bool toLocal = true,
}) {
  final parsed = parseDateTime(dateStr);
  return formatDate(parsed, placeholder: placeholder, toLocal: toLocal);
}

/// Formats an ISO date string into `15 Oct 2026 · 2:30 PM`.
///
/// Returns [placeholder] (defaults to `'Not recorded'`) if unparseable or null.
String formatDateTimeString(
  String? dateStr, {
  String placeholder = 'Not recorded',
  String separator = ' · ',
  bool toLocal = true,
}) {
  final parsed = parseDateTime(dateStr);
  return formatDateTime(
    parsed,
    placeholder: placeholder,
    separator: separator,
    toLocal: toLocal,
  );
}
