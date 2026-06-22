import 'codec.dart';
import 'models.dart';
import 'text_utils.dart';
import 'zero_width.dart';

/// Splits text into a stream of word and whitespace tokens with no gaps, so the
/// original text is exactly the concatenation of every token.
final RegExp _tokens = RegExp(r'\S+|\s+');

/// True for any token that contains a non-whitespace character (a "word").
final RegExp _isWord = RegExp(r'\S');

/// Inserts a pre-built zero-width [watermark] after every [every]th word
/// (non-whitespace token) of [text].
///
/// This is the shared placement primitive used by both the plain and signed
/// schemes, and by the format handlers (which build one watermark for a whole
/// document and sprinkle it into each text run).
///
/// When [ensureAtLeastOne] is true and [text] contains at least one word, a
/// final watermark is appended if the interval produced none — so even a short
/// run still carries proof. Whitespace never counts toward the interval, so the
/// visible spacing is preserved exactly. Throws [ArgumentError] if [every] < 1
/// or [watermark] is empty.
String sprinkleWatermark(
  String text,
  String watermark, {
  int every = 2,
  bool ensureAtLeastOne = false,
}) {
  if (every < 1) {
    throw ArgumentError.value(every, 'every', 'must be at least 1');
  }
  if (watermark.isEmpty) {
    throw ArgumentError.value(watermark, 'watermark', 'must not be empty');
  }

  final buffer = StringBuffer();
  var wordCount = 0;
  var inserted = 0;
  for (final match in _tokens.allMatches(text)) {
    final token = match.group(0)!;
    buffer.write(token);
    if (_isWord.hasMatch(token)) {
      wordCount++;
      if (wordCount % every == 0) {
        buffer.write(watermark);
        inserted++;
      }
    }
  }
  if (ensureAtLeastOne && inserted == 0 && wordCount > 0) {
    buffer.write(watermark);
  }
  return buffer.toString();
}

/// Embeds a plain-string [signature] into [text] after every [every]th word.
///
/// Throws [ArgumentError] if [signature] is empty or [every] is less than 1.
String insertWatermark(String text, String signature, {int every = 2}) {
  if (signature.isEmpty) {
    throw ArgumentError.value(signature, 'signature', 'must not be empty');
  }
  return sprinkleWatermark(text, encodePayload(signature), every: every);
}

/// Returns the distinct decoded signatures embedded in [text], in first-seen
/// order. Undecodable groups are skipped; never throws on malformed input.
List<String> extractSignatures(String text) {
  final result = <String>[];
  final seen = <String>{};
  for (final match in watermarkPattern.allMatches(text)) {
    final signature = decodeBits(match.group(1)!);
    if (signature != null && seen.add(signature)) {
      result.add(signature);
    }
  }
  return result;
}

/// Counts watermark instances in [text], including duplicates and any instance
/// whose payload could not be decoded.
int countWatermarks(String text) => watermarkPattern.allMatches(text).length;

/// Removes every zero-width character used by the scheme from [text], returning
/// the clean visible text. The inverse of the zero-width chars added by
/// [insertWatermark].
String stripWatermarks(String text) {
  final buffer = StringBuffer();
  for (final unit in text.codeUnits) {
    if (!zeroWidthCodeUnits.contains(unit)) {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Locates every watermark instance in [text] with its decoded signature
/// (nullable), 1-based line/column, and a human-readable [contextChars]-wide
/// snippet of the surrounding visible text.
List<WatermarkMatch> findWatermarksWithContext(
  String text, {
  int contextChars = 60,
}) {
  final results = <WatermarkMatch>[];
  for (final match in watermarkPattern.allMatches(text)) {
    final (line, column) = lineColumnAt(text, match.start);
    results.add(WatermarkMatch(
      signature: decodeBits(match.group(1)!),
      line: line,
      column: column,
      context: _contextSnippet(text, match.start, match.end, contextChars),
    ));
  }
  return results;
}

/// Inspects [text] for watermarks. When [expected] is supplied, the result's
/// `match` reports whether that exact signature is present; otherwise `match`
/// is `null`.
DocumentCheck checkDocument(String text, {String? expected}) {
  final instances = findWatermarksWithContext(text);
  return DocumentCheck(
    found: instances.isNotEmpty,
    count: instances.length,
    instances: instances,
    match: expected == null ? null : extractSignatures(text).contains(expected),
  );
}

/// Builds the trimmed, whitespace-collapsed context snippet around a match,
/// adding `...` on any side that was truncated.
String _contextSnippet(String text, int start, int end, int contextChars) {
  final from = (start - contextChars).clamp(0, text.length);
  final to = (end + contextChars).clamp(0, text.length);
  final snippet = stripWatermarks(text.substring(from, to))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final prefix = from > 0 ? '...' : '';
  final suffix = to < text.length ? '...' : '';
  return '$prefix$snippet$suffix';
}
