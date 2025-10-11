import 'package:libmsgr/src/utils/dates.dart';
import 'package:test/test.dart';

void main() {
  group('Date Utils Tests', () {
    test('isLeapYear returns true for leap years', () {
      expect(isLeapYear(2000), isTrue);
      expect(isLeapYear(2004), isTrue);
      expect(isLeapYear(1900), isFalse);
      expect(isLeapYear(2020), isTrue);
    });

    test('daysInMonth returns correct number of days', () {
      expect(daysInMonth(2021, 1), 31);
      expect(daysInMonth(2021, 2), 28);
      expect(daysInMonth(2020, 2), 29); // Leap year
      expect(daysInMonth(2021, 4), 30);
    });

    test('addYears adds the correct number of years', () {
      final date = DateTime.utc(2020, 1, 1);
      expect(addYears(date, 1), DateTime.utc(2021, 1, 1));
      expect(addYears(date, -1), DateTime.utc(2019, 1, 1));
    });

    test('addDays adds the correct number of days', () {
      final date = DateTime.utc(2020, 1, 1);
      expect(addDays(date, 1), DateTime.utc(2020, 1, 2));
      expect(addDays(date, -1), DateTime.utc(2019, 12, 31));
    });

    test('addMonths adds the correct number of months', () {
      final date = DateTime.utc(2020, 1, 31);
      expect(addMonths(date, 1), DateTime.utc(2020, 2, 29)); // Leap year
      expect(addMonths(date, -1), DateTime.utc(2019, 12, 31));
      expect(addMonths(date, 12), DateTime.utc(2021, 1, 31));
      expect(addMonths(date, 13), DateTime.utc(2021, 2, 28));
    });
  });
}
