export 'date_time_formatters.dart';
export 'rent_rules.dart' show formatIndianCurrency;

String plural(int count, String singular, {String? pluralForm}) =>
    '$count ${count == 1 ? singular : (pluralForm ?? '${singular}s')}';

String formatHumanDuration(Duration? duration, {String fallback = 'Pending'}) {
  if (duration == null) return fallback;
  final minutes = duration.inMinutes.abs();
  if (minutes < 60) return '$minutes min';
  final hours = minutes / 60;
  if (hours < 24) return '${_compact(hours)} hrs';
  return '${_compact(hours / 24)} days';
}

String _compact(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
