import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/utils/date_time_formatters.dart';

void main() {
  group('DateTime Formatters - formatDate', () {
    test(
      'formats deterministic UTC date without local shift when toLocal=false',
      () {
        final dt = DateTime.utc(2026, 10, 15, 14, 30);
        expect(formatDate(dt, toLocal: false), '15 Oct 2026');
      },
    );

    test('formats local DateTime correctly', () {
      final dt = DateTime(2026, 10, 15, 9, 0);
      expect(formatDate(dt), '15 Oct 2026');
    });

    test('handles null with default and custom placeholder', () {
      expect(formatDate(null), 'Not recorded');
      expect(formatDate(null, placeholder: 'Pending'), 'Pending');
      expect(formatDate(null, placeholder: '--'), '--');
    });

    test('handles leap year leap day boundary', () {
      final leapDay = DateTime(2024, 2, 29);
      expect(formatDate(leapDay), '29 Feb 2024');
    });

    test('handles year boundaries and epoch', () {
      expect(formatDate(DateTime(2026, 1, 1)), '1 Jan 2026');
      expect(formatDate(DateTime(2026, 12, 31)), '31 Dec 2026');
      expect(formatDate(DateTime(1970, 1, 1)), '1 Jan 1970');
      expect(formatDate(DateTime(9999, 12, 31)), '31 Dec 9999');
    });
  });

  group('DateTime Formatters - formatTime', () {
    test('formats 12-hour time with AM/PM correctly', () {
      expect(
        formatTime(DateTime.utc(2026, 10, 15, 14, 30), toLocal: false),
        '2:30 PM',
      );
      expect(
        formatTime(DateTime.utc(2026, 10, 15, 0, 0), toLocal: false),
        '12:00 AM',
      );
      expect(
        formatTime(DateTime.utc(2026, 10, 15, 12, 0), toLocal: false),
        '12:00 PM',
      );
      expect(
        formatTime(DateTime.utc(2026, 10, 15, 9, 5), toLocal: false),
        '9:05 AM',
      );
      expect(
        formatTime(DateTime.utc(2026, 10, 15, 23, 59), toLocal: false),
        '11:59 PM',
      );
    });

    test('handles null time with placeholder', () {
      expect(formatTime(null), 'Not recorded');
      expect(formatTime(null, placeholder: '--:--'), '--:--');
    });
  });

  group('DateTime Formatters - formatDateTime', () {
    test('combines date and time with standard separator', () {
      final dt = DateTime.utc(2026, 10, 15, 14, 30);
      expect(formatDateTime(dt, toLocal: false), '15 Oct 2026 · 2:30 PM');
    });

    test('supports custom separator and placeholder', () {
      final dt = DateTime.utc(2026, 10, 15, 9, 15);
      expect(
        formatDateTime(dt, separator: ' at ', toLocal: false),
        '15 Oct 2026 at 9:15 AM',
      );
      expect(formatDateTime(null), 'Not recorded');
      expect(formatDateTime(null, placeholder: 'Pending'), 'Pending');
    });
  });

  group('DateTime Formatters - formatElapsedDuration', () {
    test('handles null and zero duration safely', () {
      expect(formatElapsedDuration(null), 'Pending');
      expect(formatElapsedDuration(null, placeholder: 'Unknown'), 'Unknown');
      expect(formatElapsedDuration(Duration.zero), '0m');
    });

    test('clamps negative duration safely to 0m', () {
      expect(formatElapsedDuration(const Duration(minutes: -15)), '0m');
      expect(formatElapsedDuration(const Duration(days: -2)), '0m');
      expect(formatElapsedDuration(const Duration(seconds: -1)), '0m');
    });

    test('formats sub-minute duration as < 1m', () {
      expect(formatElapsedDuration(const Duration(seconds: 45)), '< 1m');
      expect(formatElapsedDuration(const Duration(seconds: 1)), '< 1m');
    });

    test('formats minutes, hours, and days durations', () {
      expect(formatElapsedDuration(const Duration(minutes: 5)), '5m');
      expect(formatElapsedDuration(const Duration(minutes: 45)), '45m');
      expect(
        formatElapsedDuration(const Duration(hours: 2, minutes: 15)),
        '2h 15m',
      );
      expect(formatElapsedDuration(const Duration(hours: 3)), '3h');
      expect(formatElapsedDuration(const Duration(days: 3, hours: 4)), '3d 4h');
      expect(formatElapsedDuration(const Duration(days: 2)), '2d');
      expect(formatElapsedDuration(const Duration(days: 365)), '365d');
    });
  });

  group('DateTime Formatters - formatBetweenEventsDuration', () {
    test('formats timeline elapsed durations safely', () {
      expect(formatBetweenEventsDuration(null), 'Moments between events');
      expect(
        formatBetweenEventsDuration(Duration.zero),
        'Moments between events',
      );
      expect(
        formatBetweenEventsDuration(const Duration(seconds: -10)),
        'Moments between events',
      );
      expect(
        formatBetweenEventsDuration(const Duration(minutes: 20)),
        '20m between events',
      );
      expect(
        formatBetweenEventsDuration(const Duration(hours: 1)),
        '1h between events',
      );
      expect(
        formatBetweenEventsDuration(const Duration(days: 3)),
        '3d between events',
      );
    });
  });

  group('DateTime Formatters - formatTimerDuration', () {
    test('formats HH:MM:SS timer accurately', () {
      expect(formatTimerDuration(null), '00:00:00');
      expect(formatTimerDuration(const Duration(seconds: -5)), '00:00:00');
      expect(formatTimerDuration(Duration.zero), '00:00:00');
      expect(
        formatTimerDuration(const Duration(hours: 1, minutes: 23, seconds: 45)),
        '01:23:45',
      );
      expect(
        formatTimerDuration(const Duration(minutes: 5, seconds: 9)),
        '00:05:09',
      );
    });
  });

  group('DateTime Formatters - String parsing helpers', () {
    test('parses and formats valid ISO date string', () {
      expect(
        formatDateString('2026-10-15T14:30:00Z', toLocal: false),
        '15 Oct 2026',
      );
      expect(
        formatDateTimeString('2026-10-15T14:30:00Z', toLocal: false),
        '15 Oct 2026 · 2:30 PM',
      );
    });

    test('handles invalid, empty, and null strings without throwing', () {
      expect(formatDateString('not-a-date'), 'Not recorded');
      expect(formatDateString(''), 'Not recorded');
      expect(formatDateString(null), 'Not recorded');
      expect(formatDateTimeString('corrupt-string'), 'Not recorded');
      expect(formatDateTimeString(null, placeholder: 'Missing'), 'Missing');
    });
  });
}
