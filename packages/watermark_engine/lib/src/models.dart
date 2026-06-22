/// Value types returned by the watermark engine's inspection functions.
library;

import 'text_utils.dart';

/// A single watermark occurrence located within a document.
class WatermarkMatch {
  const WatermarkMatch({
    required this.signature,
    required this.line,
    required this.column,
    required this.context,
  });

  /// The decoded signature, or `null` when a marker pair was found but its
  /// payload could not be decoded (wrong version, non-byte-aligned length, or
  /// invalid UTF-8). A `null` here means "something is embedded here, but this
  /// engine can't read it" — useful forensic signal, not an error.
  final String? signature;

  /// 1-based line of the watermark's opening marker.
  final int line;

  /// 1-based column (in UTF-16 code units) of the opening marker.
  final int column;

  /// Surrounding text with zero-width characters removed and whitespace
  /// collapsed; bracketed with `...` on either side that was truncated.
  final String context;

  @override
  String toString() =>
      'WatermarkMatch(signature: $signature, line: $line, column: $column)';
}

/// The outcome of inspecting a document with `checkDocument`.
class DocumentCheck {
  const DocumentCheck({
    required this.found,
    required this.count,
    required this.instances,
    this.match,
  });

  /// Whether any watermark instance was detected.
  final bool found;

  /// Number of watermark instances detected, including duplicates and any that
  /// could not be decoded.
  final int count;

  /// Every detected instance, in document order.
  final List<WatermarkMatch> instances;

  /// Whether an expected signature was present among the decoded signatures.
  /// `null` when no expected signature was supplied to the check.
  final bool? match;

  @override
  String toString() =>
      'DocumentCheck(found: $found, count: $count, match: $match)';
}

/// A decoded cryptographic seal (scheme v2) — the parsed contents of one signed
/// watermark, independent of where it was found in a document.
class SignedSeal {
  const SignedSeal({
    required this.authorId,
    required this.publicKey,
    required this.timestamp,
    required this.documentHash,
    required this.signatureValid,
  });

  /// The human-readable author id the signer claimed.
  final String authorId;

  /// The signer's 32-byte Ed25519 public key, carried in the seal so the proof
  /// is self-contained (a copied fragment can be verified on its own).
  final List<int> publicKey;

  /// When the document was sealed (UTC).
  final DateTime timestamp;

  /// sha256 of the original document's visible text at sealing time.
  final List<int> documentHash;

  /// Whether the signature is cryptographically genuine for [publicKey].
  /// `true` means this seal is unforgeable proof made by the holder of that key;
  /// `false` means the seal was forged or corrupted.
  final bool signatureValid;

  /// Short, human-glanceable fingerprint of [publicKey].
  String get publicKeyFingerprint => toHex(publicKey.take(4));

  /// Full lowercase hex of [publicKey], to match against a known identity.
  String get publicKeyHex => toHex(publicKey);

  @override
  String toString() => 'SignedSeal($authorId, key: $publicKeyFingerprint, '
      'valid: $signatureValid)';
}

/// A [SignedSeal] together with where it sits in a document and whether it still
/// matches the document's current text.
class SealOccurrence {
  const SealOccurrence({
    required this.seal,
    required this.matchesCurrentText,
    required this.line,
    required this.column,
  });

  final SignedSeal seal;

  /// `true` when the seal is genuine **and** the document's current visible text
  /// still hashes to the value that was sealed (i.e. untampered, whole original).
  /// `false` for an edited document or a copied fragment — the seal is still
  /// genuine, but the surrounding text is no longer the exact original.
  final bool matchesCurrentText;

  /// 1-based line of the seal's opening marker.
  final int line;

  /// 1-based column of the seal's opening marker.
  final int column;
}

/// The result of verifying a document for cryptographic seals.
class VerificationReport {
  const VerificationReport({required this.seals, this.matchesExpectedAuthor});

  /// Every signed seal found, in document order (genuine or not).
  final List<SealOccurrence> seals;

  /// Whether a seal genuinely signed by the expected public key was present;
  /// `null` when no expected key was supplied.
  final bool? matchesExpectedAuthor;

  /// Whether any seal at all was found.
  bool get found => seals.isNotEmpty;

  /// Whether at least one genuine (unforgeable) seal is present — the document
  /// carries real proof of authorship.
  bool get hasGenuineSeal => seals.any((o) => o.seal.signatureValid);

  /// Whether every genuine seal still matches the current text — i.e. this is an
  /// intact, unedited original rather than an edited copy or a fragment.
  bool get documentIntact =>
      found && seals.every((o) => o.seal.signatureValid && o.matchesCurrentText);

  /// The distinct author ids whose seals verified genuinely.
  Set<String> get genuineAuthors =>
      {for (final o in seals) if (o.seal.signatureValid) o.seal.authorId};

  @override
  String toString() => 'VerificationReport(seals: ${seals.length}, '
      'genuine: $hasGenuineSeal, intact: $documentIntact)';
}
