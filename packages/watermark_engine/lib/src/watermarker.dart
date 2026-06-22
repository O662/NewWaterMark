import 'engine.dart';
import 'identity.dart';
import 'signing.dart';

/// A strategy for embedding a watermark into the text runs of a document.
///
/// Marking is two-phase so that a *single* watermark can be built for a whole
/// document and then sprinkled into each of its text runs:
///
/// 1. [prepare] is called once with the document's full visible text and returns
///    a per-run transform.
/// 2. The transform is applied to each individual run (paragraph, cell, text
///    node, ...), inserting the watermark in place.
///
/// This matters for signed seals, whose fingerprint covers the entire document:
/// every run then carries the same whole-document proof, so any copied excerpt
/// remains verifiable.
abstract interface class Watermarker {
  /// Returns a transform that embeds this watermarker's mark into one run, given
  /// the document's complete visible text (run order joined as the caller sees
  /// it). Implementations that don't need the full text may ignore it.
  String Function(String run) prepare(String fullVisibleText);
}

/// Embeds a plain-string signature (scheme v1) into each run.
class PlainWatermarker implements Watermarker {
  PlainWatermarker(this.signature, {this.every = 2}) {
    if (signature.isEmpty) {
      throw ArgumentError.value(signature, 'signature', 'must not be empty');
    }
    if (every < 1) {
      throw ArgumentError.value(every, 'every', 'must be at least 1');
    }
  }

  final String signature;
  final int every;

  @override
  String Function(String run) prepare(String fullVisibleText) {
    return (run) =>
        insertWatermark(run, signature, every: every);
  }
}

/// Embeds a cryptographic seal (scheme v2) into each run. The seal is built once
/// over the whole document, so every run proves authorship of the same document.
class SignedWatermarker implements Watermarker {
  SignedWatermarker(this.identity, {this.every = 4, this.timestamp}) {
    if (every < 1) {
      throw ArgumentError.value(every, 'every', 'must be at least 1');
    }
  }

  final AuthorIdentity identity;
  final int every;
  final DateTime? timestamp;

  @override
  String Function(String run) prepare(String fullVisibleText) {
    final seal = buildSignedSeal(identity, fullVisibleText, timestamp: timestamp);
    return (run) =>
        sprinkleWatermark(run, seal, every: every, ensureAtLeastOne: true);
  }
}
