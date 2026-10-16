class DurationExtractionResult {
  final Duration? duration;
  final String? matchedText;
  final int? startOffset;
  final int? endOffset;

  const DurationExtractionResult({
    this.duration,
    this.matchedText,
    this.startOffset,
    this.endOffset,
  });

  bool get hasMatch => duration != null && matchedText != null;
}

class RecipeDurationParser {
  /// Parse ISO 8601 duration string like "PT15M", "PT1H30M", "PT45S"
  static Duration? parseIso8601(String isoString) {
    if (isoString.isEmpty) return null;
    final match = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
      caseSensitive: false,
    ).firstMatch(isoString.trim());

    if (match == null) return null;

    int part(int i) => int.tryParse(match.group(i) ?? '') ?? 0;
    final days = part(1);
    final hours = part(2);
    final minutes = part(3);
    final seconds = part(4);

    final totalSec =
        (days * 86400) + (hours * 3600) + (minutes * 60) + seconds;
    return totalSec > 0 ? Duration(seconds: totalSec) : null;
  }

  /// Analyzes raw step direction text to extract duration expressions
  static DurationExtractionResult extractDuration(String text) {
    if (text.trim().isEmpty) {
      return const DurationExtractionResult();
    }

    // 1. Combined units: "1 hour and 30 minutes", "1 hr 15 mins", "2 hours 10m"
    final combinedRegex = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\s*(?:and)?\s*(\d+(?:\.\d+)?)\s*(?:minutes?|mins?|m)\b',
      caseSensitive: false,
    );
    final combinedMatch = combinedRegex.firstMatch(text);
    if (combinedMatch != null) {
      final hours = double.tryParse(combinedMatch.group(1) ?? '0') ?? 0.0;
      final minutes = double.tryParse(combinedMatch.group(2) ?? '0') ?? 0.0;
      final totalSec = (hours * 3600 + minutes * 60).round();
      if (totalSec > 0) {
        return DurationExtractionResult(
          duration: Duration(seconds: totalSec),
          matchedText: combinedMatch.group(0),
          startOffset: combinedMatch.start,
          endOffset: combinedMatch.end,
        );
      }
    }

    // 2. Ranges: "10-12 minutes", "8 to 10 min", "1-2 hours", "30 to 45 seconds"
    final rangeRegex = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:-|to)\s*(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|min|m|seconds?|secs?|sec|s)\b',
      caseSensitive: false,
    );
    final rangeMatch = rangeRegex.firstMatch(text);
    if (rangeMatch != null) {
      final lowerBound = double.tryParse(rangeMatch.group(1) ?? '0') ?? 0.0;
      final unit = (rangeMatch.group(3) ?? '').toLowerCase();
      final totalSec = _toSeconds(lowerBound, unit);
      if (totalSec > 0) {
        return DurationExtractionResult(
          duration: Duration(seconds: totalSec),
          matchedText: rangeMatch.group(0),
          startOffset: rangeMatch.start,
          endOffset: rangeMatch.end,
        );
      }
    }

    // 3. Single duration: "15 minutes", "45 min", "1 hour", "30 seconds", "sear 45 secs"
    final singleRegex = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|min|m|seconds?|secs?|sec|s)\b',
      caseSensitive: false,
    );
    for (final match in singleRegex.allMatches(text)) {
      final value = double.tryParse(match.group(1) ?? '0') ?? 0.0;
      final unit = (match.group(2) ?? '').toLowerCase();

      // Guard against false positives like "350" (temperature) or "1" (step number) unless followed by explicit unit
      final totalSec = _toSeconds(value, unit);
      if (totalSec > 0) {
        return DurationExtractionResult(
          duration: Duration(seconds: totalSec),
          matchedText: match.group(0),
          startOffset: match.start,
          endOffset: match.end,
        );
      }
    }

    return const DurationExtractionResult();
  }

  static int _toSeconds(double val, String unit) {
    if (unit.startsWith('h')) {
      return (val * 3600).round();
    } else if (unit.startsWith('min') || unit == 'm') {
      return (val * 60).round();
    } else if (unit.startsWith('sec') || unit == 's') {
      return val.round();
    }
    return 0;
  }
}
