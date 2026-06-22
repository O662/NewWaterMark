/// Pure-Dart engine for embedding and recovering invisible zero-width Unicode
/// watermarks in text, used to prove document authorship.
///
/// The engine has no Flutter dependency so it can be unit-tested in isolation
/// and reused by the format handlers and UI layers built on top of it.
///
/// ```dart
/// final marked = insertWatermark('the original text here', 'Malcolm-2026');
/// extractSignatures(marked); // ['Malcolm-2026']
/// stripWatermarks(marked);   // 'the original text here'
/// ```
library;

export 'src/engine.dart'
    show
        checkDocument,
        countWatermarks,
        extractSignatures,
        findWatermarksWithContext,
        insertWatermark,
        sprinkleWatermark,
        stripWatermarks;
export 'src/identity.dart' show AuthorIdentity;
export 'src/models.dart'
    show
        DocumentCheck,
        SealOccurrence,
        SignedSeal,
        VerificationReport,
        WatermarkMatch;
export 'src/signed_payload.dart' show documentFingerprint;
export 'src/signing.dart'
    show buildSignedSeal, insertSignedWatermark, verifyDocument;
export 'src/watermarker.dart'
    show PlainWatermarker, SignedWatermarker, Watermarker;
export 'src/zero_width.dart' show plainSchemeVersion, signedSchemeVersion;
