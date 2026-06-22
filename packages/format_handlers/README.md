# format_handlers

Offline, pure-Dart document format handlers for the NewWaterMark app. Each
handler embeds/recovers a watermark (plain or cryptographic) via the
`watermark_engine`, working identically on every platform — including web,
because handlers are **pure byte transforms** (bytes in, bytes out) and never
touch the filesystem.

## Supported formats

| Format | Extensions | What gets watermarked |
| ------ | ---------- | --------------------- |
| Text   | txt, md, markdown, rst, text, log | the whole UTF-8 string |
| HTML   | html, htm, xhtml | visible text nodes only (skips script/style/title/meta/head + comments) |
| DOCX   | docx | every `<w:t>` run in `word/document.xml` (body + tables) |
| XLSX   | xlsx | every `<t>` in shared strings + inline worksheet strings |
| PPTX   | pptx | every `<a:t>` run across `ppt/slides/slide*.xml` |
| PDF    | pdf  | **app layer only** — see below |

## Usage

```dart
final registry = FormatRegistry();

final marked = await registry.mark(bytes, 'report.docx', SignedWatermarker(identity));
final text   = await registry.extractText(marked, 'report.docx');
final report = verifyDocument(text, expectedPublicKey: identity.publicKeyBytes);
```

A whole-document seal is built once and sprinkled into every text run, so a
copied excerpt still verifies as yours.

## PDF is intentionally not here

Real PDF support needs `syncfusion_flutter_pdf` (which depends on Flutter) plus a
bundled Unicode font asset, so it lives in the Flutter app layer and is built
last. Until the app calls `registry.register(realPdfHandler)`, PDF throws
`PdfHandlerNotWired` — surfaced as explicitly unavailable, never failing
silently. PDF marking is also inherently lossy (text is regenerated; original
layout/fonts/images are not preserved).

## Design note

The handler interface is `mark(bytes) -> bytes` and `extractText(bytes) -> text`,
not file-path based. File I/O belongs to the storage layer, and web has no
filesystem, so byte transforms keep every handler portable and unit-testable.

## Tests

```bash
cd packages/format_handlers
dart pub get
dart test
```
