# watermark_engine

A pure-Dart library (no Flutter dependency) that embeds **invisible zero-width
Unicode watermarks** into text to prove authorship, and recovers them later.

It is the foundation of the NewWaterMark app: the format handlers (txt, md,
html, docx, xlsx, pptx, pdf) and the UI all sit on top of this engine.

## The scheme

| Symbol | Code point | Meaning |
| ------ | ---------- | ------- |
| `zwsp` | U+200B     | bit `0` |
| `zwnj` | U+200C     | bit `1` |
| `zwj`  | U+200D     | joiner (markers only) |

Each embedded watermark is:

```
marker + payloadBits + marker          // marker = U+200D U+200D
payload = [ schemeVersion , utf8(signature)... ]
```

Every payload byte is written MSB-first as bit characters. A leading
**version byte** lets the decoder reject foreign/older data instead of
misreading it. The bit alphabet excludes `zwj`, so a marker can never be
confused with payload bits.

All three code points are BMP (single UTF-16 units) and are not matched by
`\s`, so whitespace tokenization stays stable when a watermark is present.

> The code points are kept as integers in `lib/src/zero_width.dart` and the
> strings/regex are derived with `String.fromCharCode`, so **no invisible
> character ever appears in the source** and cannot be corrupted by an editor,
> copy-paste, or line-ending conversion.

## API

### Plain signatures (scheme v1)

```dart
String       insertWatermark(String text, String signature, {int every = 2});
List<String> extractSignatures(String text);          // distinct, first-seen order
int          countWatermarks(String text);            // includes duplicates
String       stripWatermarks(String text);            // remove all zero-width ink
List<WatermarkMatch> findWatermarksWithContext(String text, {int contextChars = 60});
DocumentCheck checkDocument(String text, {String? expected});
```

- `insertWatermark` appends a watermark after every `every`th word
  (non-whitespace token). Throws if the signature is empty or `every < 1`.
- Decoding never throws: malformed or foreign data simply yields no signatures.

### Cryptographic seals (scheme v2 — proof of authorship)

```dart
final me = AuthorIdentity.generate('Malcolm');     // or .fromSeed(name, seed)

final sealed = insertSignedWatermark(text, me);    // dense, self-contained seals
final report = verifyDocument(sealed, expectedPublicKey: me.publicKeyBytes);

report.hasGenuineSeal;        // an unforgeable seal is present
report.documentIntact;        // text still matches what was sealed (untampered)
report.matchesExpectedAuthor; // a genuine seal from this exact key is present
report.genuineAuthors;        // {'Malcolm'}
```

Each seal carries the author id, the signer's **public key**, a timestamp, and a
sha256 of the document's visible text, all covered by an **Ed25519 signature**.
Because the seal is self-contained and repeated throughout the text, a copied
excerpt pasted into another document still verifies as yours.

What it does and does not do:

- ✅ **Unforgeable** — only the private-key holder can produce a valid seal.
- ✅ **Tamper-evident** — editing the visible text makes `documentIntact` false.
- ✅ **Survives** copy-paste, reformatting, "clear formatting", and format
  conversion, because it is invisible *characters*, not styling.
- ⚠️ **Not removal-proof** — anyone who knows about zero-width characters can
  deliberately strip them (or retype the text). This is strong evidence that
  survives normal handling and casual theft, not an unbreakable lock.

> Persisting the private key is the app layer's job. The only secret worth
> storing is `identity.seed` (32 bytes); the keypair regenerates from it.

## Running the tests

```bash
cd packages/watermark_engine
dart pub get
dart test
```
