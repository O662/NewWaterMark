import 'dart:convert';

import 'package:test/test.dart';
import 'package:watermark_engine/src/codec.dart';
import 'package:watermark_engine/src/zero_width.dart';

/// Wraps arbitrary bytes as a marker-delimited zero-width group, bypassing the
/// version/UTF-8 rules in [encodePayload] so the decoder can be tested against
/// hand-crafted (including invalid) payloads.
String wrapBytes(List<int> bytes) {
  final buffer = StringBuffer()
    ..writeCharCode(zwjCodeUnit)
    ..writeCharCode(zwjCodeUnit);
  for (final byte in bytes) {
    for (var i = 7; i >= 0; i--) {
      buffer.writeCharCode(((byte >> i) & 1) == 0 ? zwspCodeUnit : zwnjCodeUnit);
    }
  }
  return (buffer
        ..writeCharCode(zwjCodeUnit)
        ..writeCharCode(zwjCodeUnit))
      .toString();
}

/// Extracts the captured bit group from an encoded single watermark.
String bitsOf(String encoded) => watermarkPattern.firstMatch(encoded)!.group(1)!;

void main() {
  group('encodePayload', () {
    test('contains only zero-width characters', () {
      final encoded = encodePayload('hello');
      expect(stripToVisible(encoded), isEmpty);
    });

    test('begins and ends with the two-ZWJ marker', () {
      final encoded = encodePayload('x');
      expect(encoded.startsWith(marker), isTrue);
      expect(encoded.endsWith(marker), isTrue);
    });

    test('writes the version byte as the first 8 payload bits', () {
      final bits = bitsOf(encodePayload('A'));
      final firstByte = bits.substring(0, 8);
      // schemeVersion (0x01) MSB-first => seven zwsp then one zwnj.
      expect(firstByte, '$zwsp$zwsp$zwsp$zwsp$zwsp$zwsp$zwsp$zwnj');
    });
  });

  group('decodeBits', () {
    test('round-trips an ASCII signature', () {
      expect(decodeBits(bitsOf(encodePayload('Malcolm-2026'))), 'Malcolm-2026');
    });

    test('round-trips a multi-byte UTF-8 signature', () {
      expect(decodeBits(bitsOf(encodePayload('Jose-OK-lock'))), 'Jose-OK-lock');
      const tricky = 'José-✓-\u{1F512}';
      expect(decodeBits(bitsOf(encodePayload(tricky))), tricky);
    });

    test('returns null when bit length is not a multiple of 8', () {
      final bits = bitsOf(encodePayload('A')); // 16 bits
      expect(decodeBits(bits.substring(0, 15)), isNull);
      expect(decodeBits('$zwsp$zwnj$zwsp'), isNull); // 3 bits
    });

    test('returns null on an empty group', () {
      expect(decodeBits(''), isNull);
    });

    test('returns null when the version byte does not match', () {
      // 0xEE is a foreign/unknown scheme version; the v1 decoder must reject it.
      expect(decodeBits(bitsOf(wrapBytes([0xEE, 0x41]))), isNull);
      // The signed scheme (v2) is also not a plain signature.
      expect(decodeBits(bitsOf(wrapBytes([signedSchemeVersion, 0x41]))), isNull);
    });

    test('returns null on invalid UTF-8 after a valid version byte', () {
      // 0xFF is never a valid standalone UTF-8 byte.
      expect(
          decodeBits(bitsOf(wrapBytes([plainSchemeVersion, 0xFF, 0xFE]))), isNull);
    });

    test('decodes a hand-built valid payload', () {
      final bytes = <int>[plainSchemeVersion, ...utf8.encode('Hi')];
      expect(decodeBits(bitsOf(wrapBytes(bytes))), 'Hi');
    });
  });
}

/// Returns [text] with every zero-width code unit removed (test-local helper so
/// this file does not depend on the public engine API).
String stripToVisible(String text) {
  final buffer = StringBuffer();
  for (final unit in text.codeUnits) {
    if (!zeroWidthCodeUnits.contains(unit)) buffer.writeCharCode(unit);
  }
  return buffer.toString();
}
