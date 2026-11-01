import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/utils/display_formatters.dart';

void main() {
  test('plural uses singular only for one', () {
    expect(plural(0, 'job'), '0 jobs');
    expect(plural(1, 'job'), '1 job');
    expect(plural(2, 'job'), '2 jobs');
    expect(plural(2, 'property', pluralForm: 'properties'), '2 properties');
  });

  test('human duration uses readable compact units', () {
    expect(formatHumanDuration(const Duration(minutes: 39)), '39 min');
    expect(formatHumanDuration(const Duration(minutes: 390)), '6.5 hrs');
    expect(formatHumanDuration(const Duration(hours: 38)), '1.6 days');
  });
}
