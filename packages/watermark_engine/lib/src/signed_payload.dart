import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'codec.dart';
import 'identity.dart';
import 'models.dart';
import 'zero_width.dart';

/// Builds and parses the scheme-v2 "signed seal" payload.
///
/// Byte layout (all big-endian), signed end-to-end:
///
/// ```
/// [0]            version = signedSchemeVersion (0x02)
/// [1]            authorId length L (0..255, UTF-8 byte count)
/// [2 .. 2+L)     authorId, UTF-8
/// [.. +32)       Ed25519 public key (32 bytes)
/// [.. +8)        timestamp, ms since epoch (unsigned, big-endian)
/// [.. +32)       document fingerprint, sha256 of the visible text (32 bytes)
/// [.. +64)       Ed25519 signature over every preceding byte (64 bytes)
/// ```
///
/// The public key travels inside the seal so a copied fragment can be verified
/// on its own. The signature covers the document hash, so any edit to the
/// visible text makes the seal stop matching that text.

const int _pubKeyLen = 32;
const int _timestampLen = 8;
const int _hashLen = 32;
const int _signatureLen = 64;
const int _minSignedLen =
    2 + _pubKeyLen + _timestampLen + _hashLen + _signatureLen; // 138

/// sha256 of [visibleText], used as the document fingerprint. Always 32 bytes.
Uint8List documentFingerprint(String visibleText) =>
    Uint8List.fromList(sha256.convert(utf8.encode(visibleText)).bytes);

/// Builds one signed seal as a marker-delimited zero-width string.
String buildSignedWatermark(
  AuthorIdentity identity, {
  required int timestampMillis,
  required List<int> documentHash,
}) {
  final authorBytes = utf8.encode(identity.authorId);
  if (authorBytes.length > 255) {
    throw ArgumentError.value(
        identity.authorId, 'authorId', 'must be at most 255 UTF-8 bytes');
  }
  if (documentHash.length != _hashLen) {
    throw ArgumentError.value(
        documentHash.length, 'documentHash.length', 'must be $_hashLen bytes');
  }

  final signedPart = (BytesBuilder()
        ..addByte(signedSchemeVersion)
        ..addByte(authorBytes.length)
        ..add(authorBytes)
        ..add(identity.publicKeyBytes)
        ..add(_uint64be(timestampMillis))
        ..add(documentHash))
      .toBytes();

  final signature = ed.sign(identity.edPrivateKey, signedPart);
  final full = (BytesBuilder()
        ..add(signedPart)
        ..add(signature))
      .toBytes();
  return wrapBytesAsWatermark(full);
}

/// Parses [bytes] as a signed seal and verifies its signature, or returns `null`
/// when [bytes] is not a structurally valid v2 payload. A returned seal with
/// `signatureValid == false` means "a seal was here but it is forged/corrupt".
/// Never throws.
SignedSeal? parseSignedSeal(List<int> bytes) {
  if (bytes.length < _minSignedLen) return null;
  if (bytes[0] != signedSchemeVersion) return null;

  final authorLen = bytes[1];
  final expectedLen =
      2 + authorLen + _pubKeyLen + _timestampLen + _hashLen + _signatureLen;
  if (bytes.length != expectedLen) return null;

  var offset = 2;
  final String authorId;
  try {
    authorId = utf8.decode(bytes.sublist(offset, offset + authorLen));
  } on FormatException {
    return null;
  }
  offset += authorLen;

  final publicKey = bytes.sublist(offset, offset + _pubKeyLen);
  offset += _pubKeyLen;
  final timestampMillis = _readUint64be(bytes, offset);
  offset += _timestampLen;
  final documentHash = bytes.sublist(offset, offset + _hashLen);
  offset += _hashLen;
  final signature = bytes.sublist(offset, offset + _signatureLen);
  final signedPart = bytes.sublist(0, expectedLen - _signatureLen);

  bool valid;
  try {
    valid = ed.verify(
      ed.PublicKey(publicKey),
      Uint8List.fromList(signedPart),
      Uint8List.fromList(signature),
    );
  } catch (_) {
    valid = false; // malformed key/signature bytes -> simply not genuine
  }

  return SignedSeal(
    authorId: authorId,
    publicKey: publicKey,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true),
    documentHash: documentHash,
    signatureValid: valid,
  );
}

/// Big-endian 8-byte encoding. Uses integer division (not bit shifts) so it is
/// correct on the web, where ints are JS doubles and bitwise ops are 32-bit.
Uint8List _uint64be(int value) {
  final out = Uint8List(8);
  var v = value;
  for (var i = 7; i >= 0; i--) {
    out[i] = v % 256;
    v = v ~/ 256;
  }
  return out;
}

int _readUint64be(List<int> bytes, int offset) {
  var v = 0;
  for (var i = 0; i < 8; i++) {
    v = v * 256 + bytes[offset + i];
  }
  return v;
}
