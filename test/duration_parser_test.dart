import 'package:flutter_test/flutter_test.dart';
import 'package:delicious/recipe_duration_parser.dart';

void main() {
  group('RecipeDurationParser Tests', () {
    test('extracts duration from range expression (10-12 minutes)', () {
      final res = RecipeDurationParser.extractDuration('cool for 10-12 minutes');
      expect(res.hasMatch, isTrue);
      expect(res.duration, equals(const Duration(minutes: 10)));
      expect(res.matchedText, equals('10-12 minutes'));
    });

    test('extracts duration amidst temperatures (bake at 350 for 25 min)', () {
      final res = RecipeDurationParser.extractDuration('bake at 350 for 25 min');
      expect(res.hasMatch, isTrue);
      expect(res.duration, equals(const Duration(minutes: 25)));
      expect(res.matchedText, equals('25 min'));
    });

    test('ignores non-duration counts (repeat 3 times)', () {
      final res = RecipeDurationParser.extractDuration('repeat 3 times');
      expect(res.hasMatch, isFalse);
      expect(res.duration, isNull);
    });

    test('extracts large hour durations (rest 24 hours)', () {
      final res = RecipeDurationParser.extractDuration('rest 24 hours');
      expect(res.hasMatch, isTrue);
      expect(res.duration, equals(const Duration(hours: 24)));
      expect(res.matchedText, equals('24 hours'));
    });

    test('extracts combined units (roast for 1 hour and 30 minutes)', () {
      final res = RecipeDurationParser.extractDuration('roast for 1 hour and 30 minutes');
      expect(res.hasMatch, isTrue);
      expect(res.duration, equals(const Duration(hours: 1, minutes: 30)));
      expect(res.matchedText, equals('1 hour and 30 minutes'));
    });

    test('extracts seconds duration (sear 45 secs per side)', () {
      final res = RecipeDurationParser.extractDuration('sear 45 secs per side');
      expect(res.hasMatch, isTrue);
      expect(res.duration, equals(const Duration(seconds: 45)));
      expect(res.matchedText, equals('45 secs'));
    });

    test('extracts microwave seconds (microwave for 30 seconds)', () {
      final res = RecipeDurationParser.extractDuration('microwave for 30 seconds');
      expect(res.hasMatch, isTrue);
      expect(res.duration, equals(const Duration(seconds: 30)));
      expect(res.matchedText, equals('30 seconds'));
    });

    test('parses ISO 8601 strings (PT15M, PT1H30M)', () {
      expect(RecipeDurationParser.parseIso8601('PT15M'), equals(const Duration(minutes: 15)));
      expect(RecipeDurationParser.parseIso8601('PT1H30M'), equals(const Duration(hours: 1, minutes: 30)));
      expect(RecipeDurationParser.parseIso8601('PT45S'), equals(const Duration(seconds: 45)));
    });
  });
}
