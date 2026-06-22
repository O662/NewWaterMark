import 'dart:convert';

import 'zero_width.dart';

/// Low-level conversion between payload bytes and their zero-width encoding.
///
/// Wire format of one watermark:
///
/// ```
/// marker  +  payloadBytes as bits  +  marker
/// ```
///
/// Each payload byte is emitted as 8 bits, most-significant-bit first, with bit
/// `0` -> [zwspCodeUnit] and bit `1` -> [zwnjCodeUnit]. The first payload byte
/// is always a scheme version (see [plainSchemeVersion]/[signedSchemeVersion]),
/// which lets the decoder route and reject foreign data without misreading it.
///
/// The byte primitives ([wrapBytesAsWatermark]/[bitsToBytes]) are shared by both
/// the plain-string scheme and the signed-seal scheme built on top of them.

/// Wraps already-assembled [payloadBytes] as one marker-delimited zero-width
/// group.
String wrapBytesAsWatermark(List<int> payloadBytes) {
  final buffer = StringBuffer()
    ..writeCharCode(zwjCodeUnit)
    ..writeCharCode(zwjCodeUnit);
  for (final byte in payloadBytes) {
    for (var i = 7; i >= 0; i--) {
      buffer.writeCharCode(((byte >> i) & 1) == 0 ? zwspCodeUnit : zwnjCodeUnit);
    }
  }
  return (buffer
        ..writeCharCode(zwjCodeUnit)
        ..writeCharCode(zwjCodeUnit))
      .toString();
}

/// Converts a captured bit group back into its payload bytes, or `null` when the
/// group is not byte-aligned or contains a non-bit character. Never throws.
List<int>? bitsToBytes(String bits) {
  if (bits.isEmpty || bits.length % 8 != 0) return null;

  final bytes = <int>[];
  for (var i = 0; i < bits.length; i += 8) {
    var value = 0;
    for (var j = 0; j < 8; j++) {
      value <<= 1;
      final unit = bits.codeUnitAt(i + j);
      if (unit == zwnjCodeUnit) {
        value |= 1;
      } else if (unit != zwspCodeUnit) {
        return null; // not a bit character — refuse rather than guess
      }
    }
    bytes.add(value);
  }
  return bytes;
}

/// Encodes [signature] as a plain-string (scheme v1) zero-width watermark.
///
/// Uses UTF-8 (not UTF-16 units) so the full Unicode range round-trips.
String encodePayload(String signature) =>
    wrapBytesAsWatermark(<int>[plainSchemeVersion, ...utf8.encode(signature)]);

/// Decodes a captured bit group as a plain-string (scheme v1) signature, or
/// `null` when it is not a v1 payload or not valid UTF-8. Never throws.
///
/// Signed seals (scheme v2) are intentionally ignored here; they are handled by
/// the signing layer's verification, not by plain-signature extraction.
String? decodeBits(String bits) {
  final bytes = bitsToBytes(bits);
  if (bytes == null || bytes.isEmpty || bytes.first != plainSchemeVersion) {
    return null;
  }
  try {
    return utf8.decode(bytes.sublist(1)); // throws on malformed UTF-8
  } on FormatException {
    return null;
  }
}

/// Matches a single watermark of any scheme: `marker ( bits ) marker`, with the
/// bits captured non-greedily so adjacent watermarks split cleanly. Built from
/// code points so no invisible character appears in source.
final RegExp watermarkPattern = RegExp('$marker([$zwsp$zwnj]+?)$marker');
