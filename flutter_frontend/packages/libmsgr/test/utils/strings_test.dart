import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/utils/strings.dart';

void main() {
  group('String Utilities Tests', () {
    test('getOnlyDigits removes non-digit characters', () {
      expect(getOnlyDigits('abc123def456'), '123456');
      expect(getOnlyDigits('no digits here'), '');
      expect(getOnlyDigits('123456'), '123456');
    });

    test('isAllDigits checks if string contains only digits', () {
      expect(isAllDigits('123456'), true);
      expect(isAllDigits('abc123'), false);
      expect(isAllDigits(''), true);
    });

    test('toSnakeCase converts camelCase to snake_case', () {
      expect(toSnakeCase('camelCaseString'), 'camel_case_string');
      expect(toSnakeCase('CamelCaseString'), '_camel_case_string');
      expect(toSnakeCase(''), '');
      expect(toSnakeCase(null), '');
    });

    test('toCamelCase converts snake_case to camelCase', () {
      expect(toCamelCase('snake_case_string'), 'snakeCaseString');
      expect(toCamelCase('Snake_Case_String'), 'snakeCaseString');
      expect(toCamelCase(''), '');
    });

    test('toSpaceCase converts camelCase to space case', () {
      expect(toSpaceCase('camelCaseString'), 'camel case string');
      expect(toSpaceCase('CamelCaseString'), ' camel case string');
      expect(toSpaceCase(''), '');
    });

    test('toTitleCase converts string to Title Case', () {
      expect(toTitleCase('title case string'), 'Title Case String');
      expect(toTitleCase('TitleCaseString'), 'Title Case String');
      expect(toTitleCase('url'), 'URL');
      expect(toTitleCase(''), '');
    });

    test('removeAllHtmlTags removes HTML tags from string', () {
      expect(removeAllHtmlTags('<p>This is a <strong>test</strong>.</p>'),
          'This is a test.');
      expect(removeAllHtmlTags('No HTML here'), 'No HTML here');
      expect(removeAllHtmlTags(''), '');
    });

    test('getFirstName extracts first name from full name', () {
      expect(getFirstName('John Doe'), 'John');
      expect(getFirstName('John'), 'John');
      expect(getFirstName(''), '');
    });

    test('getLastName extracts last name from full name', () {
      expect(getLastName('John Doe'), 'Doe');
      expect(getLastName('John'), '');
      expect(getLastName(''), '');
    });

    test('isValidDate checks if string is a valid date', () {
      expect(isValidDate('2021-01-01'), true);
      expect(isValidDate('invalid date'), false);
      expect(isValidDate(''), false);
    });

    test('printWrapped prints text in chunks', () {
      // This test is more about ensuring no exceptions are thrown
      expect(() => printWrapped('a' * 20001), returnsNormally);
    });

    test('matchesStrings checks if needle matches any haystack', () {
      expect(
          matchesStrings(
              haystacks: ['haystack1', 'haystack2'], needle: 'stack1'),
          true);
      expect(
          matchesStrings(
              haystacks: ['haystack1', 'haystack2'], needle: 'needle'),
          false);
      expect(matchesStrings(haystacks: ['haystack1', 'haystack2'], needle: ''),
          true);
    });

    test('matchesString checks if needle matches haystack', () {
      expect(matchesString(haystack: 'haystack', needle: 'stack'), true);
      expect(matchesString(haystack: 'haystack', needle: 'needle'), false);
      expect(matchesString(haystack: 'haystack', needle: ''), true);
    });

    test('matchesStringsValue returns matching haystack', () {
      expect(
          matchesStringsValue(
              haystacks: ['haystack1', 'haystack2'], needle: 'stack1'),
          'haystack1');
      expect(
          matchesStringsValue(
              haystacks: ['haystack1', 'haystack2'], needle: 'needle'),
          null);
      expect(
          matchesStringsValue(
              haystacks: ['haystack1', 'haystack2'], needle: ''),
          null);
    });

    test('matchesStringValue returns haystack if it matches needle', () {
      expect(matchesStringValue(haystack: 'haystack', needle: 'stack'),
          'haystack');
      expect(matchesStringValue(haystack: 'haystack', needle: 'needle'), null);
      expect(matchesStringValue(haystack: 'haystack', needle: ''), null);
    });

    test('secondToLastIndexOf finds second to last index of pattern', () {
      expect(secondToLastIndexOf('pattern in pattern', 'pattern'), 0);
      expect(secondToLastIndexOf('no pattern here', 'pattern'), -1);
    });

    test('untrimUrl adds https:// if not present', () {
      expect(untrimUrl('example.com'), 'https://example.com');
      expect(untrimUrl('http://example.com'), 'http://example.com');
      expect(untrimUrl('https://example.com'), 'https://example.com');
    });

    test('trimUrl removes http://, https://, and www.', () {
      expect(trimUrl('http://example.com'), 'example.com');
      expect(trimUrl('https://example.com'), 'example.com');
      expect(trimUrl('www.example.com'), 'example.com');
      expect(trimUrl('example.com'), 'example.com');
    });

    test('getRandomString generates a random string of given length', () {
      expect(getRandomString(10).length, 10);
      expect(getRandomString().length, 32);
    });
  });
}
