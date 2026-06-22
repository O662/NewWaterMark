import 'codec.dart';
import 'engine.dart' show sprinkleWatermark, stripWatermarks;
import 'identity.dart';
import 'models.dart';
import 'signed_payload.dart';
import 'text_utils.dart';

/// Builds one self-contained cryptographic seal for a document whose visible
/// text is [documentVisibleText], as a zero-width string ready to be sprinkled
/// into the text (or into each run of a structured document).
///
/// The fingerprint is taken over the document's text with any existing
/// watermarks stripped, so it is stable before and after embedding. Throws
/// [ArgumentError] if there is no visible content. [timestamp] defaults to now
/// (UTC) and is injectable for reproducible builds/tests.
String buildSignedSeal(
  AuthorIdentity identity,
  String documentVisibleText, {
  DateTime? timestamp,
}) {
  final clean = stripWatermarks(documentVisibleText);
  if (clean.trim().isEmpty) {
    throw ArgumentError.value(
        documentVisibleText, 'documentVisibleText', 'has no content to seal');
  }
  return buildSignedWatermark(
    identity,
    timestampMillis:
        (timestamp ?? DateTime.now().toUtc()).millisecondsSinceEpoch,
    documentHash: documentFingerprint(clean),
  );
}

/// Embeds a self-contained cryptographic seal into [text], repeated after every
/// [every]th word so that even a small copied excerpt carries proof.
///
/// The document is stripped of any existing watermarks first, so re-sealing is
/// idempotent. At least one seal is always embedded. Throws [ArgumentError] if
/// [every] < 1 or [text] has no visible content.
///
/// Note: a denser interval (smaller [every]) survives smaller copy-paste thefts
/// but adds more invisible bytes, since each seal is a full ~138-byte proof.
String insertSignedWatermark(
  String text,
  AuthorIdentity identity, {
  int every = 4,
  DateTime? timestamp,
}) {
  if (every < 1) {
    throw ArgumentError.value(every, 'every', 'must be at least 1');
  }
  final seal = buildSignedSeal(identity, text, timestamp: timestamp);
  return sprinkleWatermark(
    stripWatermarks(text),
    seal,
    every: every,
    ensureAtLeastOne: true,
  );
}

/// Verifies [text] for cryptographic seals.
///
/// For each seal it reports whether the signature is genuine (unforgeable proof)
/// and whether the document's current visible text still matches what was sealed
/// (intact original vs. edited copy / fragment). When [expectedPublicKey] is
/// supplied, the report also says whether a genuine seal from that exact key is
/// present. Never throws.
VerificationReport verifyDocument(String text, {List<int>? expectedPublicKey}) {
  final currentHash = documentFingerprint(stripWatermarks(text));
  final seals = <SealOccurrence>[];

  for (final match in watermarkPattern.allMatches(text)) {
    final bytes = bitsToBytes(match.group(1)!);
    if (bytes == null) continue;
    final seal = parseSignedSeal(bytes);
    if (seal == null) continue; // not a signed seal (e.g. a plain signature)

    final (line, column) = lineColumnAt(text, match.start);
    seals.add(SealOccurrence(
      seal: seal,
      matchesCurrentText:
          seal.signatureValid && bytesEqual(seal.documentHash, currentHash),
      line: line,
      column: column,
    ));
  }

  return VerificationReport(
    seals: seals,
    matchesExpectedAuthor: expectedPublicKey == null
        ? null
        : seals.any((o) =>
            o.seal.signatureValid &&
            bytesEqual(o.seal.publicKey, expectedPublicKey)),
  );
}
