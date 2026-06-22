import 'package:test/test.dart';
import 'package:watermark_engine/src/zero_width.dart';
import 'package:watermark_engine/watermark_engine.dart';

const _sample =
    'The quick brown fox jumps over the lazy dog near the riverbank today.';

void main() {
  group('round-trip', () {
    test('extracts the exact ASCII signature that was inserted', () {
      final marked = insertWatermark(_sample, 'Malcolm-2026');
      expect(extractSignatures(marked), ['Malcolm-2026']);
    });

    test('extracts a non-ASCII signature with accents, symbols and emoji', () {
      const signature = 'José-✓-\u{1F512}';
      final marked = insertWatermark(_sample, signature);
      expect(extractSignatures(marked), [signature]);
    });

    test('the visible text is unchanged to a reader', () {
      final marked = insertWatermark(_sample, 'sig');
      // Same number of visible (non-zero-width) characters as the original.
      expect(stripWatermarks(marked), _sample);
    });
  });

  group('reversibility', () {
    test('stripWatermarks recovers the original text exactly', () {
      final marked = insertWatermark(_sample, 'Malcolm-2026');
      expect(marked, isNot(_sample)); // something really was added
      expect(stripWatermarks(marked), _sample);
    });

    test('stripWatermarks is a no-op on clean text', () {
      expect(stripWatermarks(_sample), _sample);
    });
  });

  group('every controls spacing', () {
    test('default every=2 inserts after every second word', () {
      // 13 words -> watermarks after words 2,4,6,8,10,12 -> 6 watermarks.
      expect(countWatermarks(insertWatermark(_sample, 'sig')), 6);
    });

    test('larger every produces fewer watermarks', () {
      expect(countWatermarks(insertWatermark(_sample, 'sig', every: 4)), 3);
      expect(countWatermarks(insertWatermark(_sample, 'sig', every: 12)), 1);
    });

    test('every=1 inserts after every word', () {
      // The sample has 13 words.
      expect(countWatermarks(insertWatermark(_sample, 'sig', every: 1)), 13);
    });

    test('a short copied substring still contains a full instance', () {
      final marked = insertWatermark(_sample, 'sig', every: 1);
      // Copy a slice that starts after the first word — later watermarks remain
      // fully intact, so the signature is still recoverable.
      final slice = marked.substring(marked.indexOf(' '));
      expect(extractSignatures(slice), contains('sig'));
    });
  });

  group('multiple signatures', () {
    test('returns distinct signatures in first-seen order', () {
      final a = insertWatermark('first paragraph of text', 'Alice');
      final b = insertWatermark('second paragraph of text', 'Bob');
      final combined = '$a\n\n$b';
      expect(extractSignatures(combined), ['Alice', 'Bob']);
    });

    test('collapses duplicates while counting every instance', () {
      final marked = insertWatermark(_sample, 'sig'); // 6 instances, 1 signature
      expect(extractSignatures(marked), ['sig']);
      expect(countWatermarks(marked), 6);
    });
  });

  group('findWatermarksWithContext', () {
    test('reports one entry per instance with the decoded signature', () {
      final matches = findWatermarksWithContext(insertWatermark(_sample, 'sig'));
      expect(matches, hasLength(6));
      expect(matches.every((m) => m.signature == 'sig'), isTrue);
    });

    test('reports 1-based line and column', () {
      final marked = insertWatermark('alpha beta', 'sig', every: 1);
      final text = 'header line\n$marked';
      final match = findWatermarksWithContext(text).first;
      expect(match.line, 2); // watermark is on the second line
      expect(match.column, greaterThan(1));
    });

    test('context strips zero-width ink and collapses whitespace', () {
      final marked = insertWatermark(_sample, 'sig');
      final context = findWatermarksWithContext(marked).first.context;
      expect(context.contains(zwsp), isFalse);
      expect(context.contains(zwnj), isFalse);
      expect(context.contains(zwj), isFalse);
      expect(context.contains('  '), isFalse); // no double spaces
    });
  });

  group('checkDocument', () {
    test('reports found/count and no match field without an expectation', () {
      final result = checkDocument(insertWatermark(_sample, 'sig'));
      expect(result.found, isTrue);
      expect(result.count, 6);
      expect(result.instances, hasLength(6));
      expect(result.match, isNull);
    });

    test('match is true when the expected signature is present', () {
      final result =
          checkDocument(insertWatermark(_sample, 'sig'), expected: 'sig');
      expect(result.match, isTrue);
    });

    test('match is false when the expected signature is absent', () {
      final result =
          checkDocument(insertWatermark(_sample, 'sig'), expected: 'other');
      expect(result.match, isFalse);
    });

    test('reports nothing found on clean text', () {
      final result = checkDocument(_sample, expected: 'sig');
      expect(result.found, isFalse);
      expect(result.count, 0);
      expect(result.match, isFalse);
    });
  });

  group('argument validation', () {
    test('throws on an empty signature', () {
      expect(() => insertWatermark(_sample, ''), throwsArgumentError);
    });

    test('throws when every is less than 1', () {
      expect(() => insertWatermark(_sample, 'sig', every: 0), throwsArgumentError);
      expect(
          () => insertWatermark(_sample, 'sig', every: -3), throwsArgumentError);
    });
  });

  group('junk input is safe', () {
    final junk = <String>[
      '',
      'Just a normal sentence with no watermark at all.',
      'Punctuation!?#@\$%^&*() and numbers 1234567890',
      'Unicode without our markers: café ☕ 日本語 \u{1F600}',
      'A lone joiner ‍ in the middle of text',
      'Tabs\tand\nnewlines\r\nand spaces    everywhere',
    ];

    for (final text in junk) {
      test('no false positives in: ${_label(text)}', () {
        expect(extractSignatures(text), isEmpty);
        expect(countWatermarks(text), 0);
        expect(checkDocument(text).found, isFalse);
      });
    }

    test('markers around a non-byte-aligned group decode to no signature', () {
      // Five bits between markers: detected as an instance, but undecodable.
      final text = 'noise $marker$zwsp$zwnj$zwsp$zwnj$zwsp$marker noise';
      expect(extractSignatures(text), isEmpty);
      expect(findWatermarksWithContext(text), hasLength(1));
      expect(findWatermarksWithContext(text).single.signature, isNull);
    });

    test('decoding never throws regardless of input', () {
      for (final text in junk) {
        expect(() => extractSignatures(text), returnsNormally);
        expect(() => findWatermarksWithContext(text), returnsNormally);
        expect(() => checkDocument(text, expected: 'x'), returnsNormally);
      }
    });
  });
}

String _label(String text) {
  final clean = text.replaceAll('\n', '\\n').replaceAll('\t', '\\t');
  return clean.isEmpty
      ? '(empty)'
      : (clean.length <= 30 ? clean : '${clean.substring(0, 30)}...');
}
