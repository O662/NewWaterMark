import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:format_handlers/format_handlers.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';
import 'package:watermark_engine/watermark_engine.dart';

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

AuthorIdentity _author([String name = 'Malcolm']) =>
    AuthorIdentity.generate(name);

/// Builds a zip from name -> UTF-8 content.
Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) {
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

Uint8List _docx(List<String> paragraphs) {
  final body = paragraphs
      .map((p) =>
          '<w:p><w:r><w:t xml:space="preserve">${_esc(p)}</w:t></w:r></w:p>')
      .join();
  return _zip({
    'word/document.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body</w:body></w:document>',
  });
}

Uint8List _xlsx(List<String> strings) {
  final si = strings.map((s) => '<si><t>${_esc(s)}</t></si>').join();
  return _zip({
    'xl/sharedStrings.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'count="${strings.length}" uniqueCount="${strings.length}">$si</sst>',
  });
}

Uint8List _pptx(List<String> runs) {
  final paras = runs
      .map((r) => '<a:p><a:r><a:t>${_esc(r)}</a:t></a:r></a:p>')
      .join();
  return _zip({
    'ppt/slides/slide1.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
            'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
            '<p:cSld><p:spTree>$paras</p:spTree></p:cSld></p:sld>',
  });
}

void main() {
  group('TextHandler', () {
    final handler = TextHandler();
    const original = 'My private research findings are documented here in detail.';

    test('plain round-trip recovers signature and original text', () async {
      final marked = await handler.mark(_utf8(original), PlainWatermarker('Malcolm-2026'));
      final text = await handler.extractText(marked);
      expect(extractSignatures(text), ['Malcolm-2026']);
      expect(stripWatermarks(text), original);
    });

    test('signed round-trip verifies as genuine and intact', () async {
      final me = _author();
      final marked = await handler.mark(_utf8(original), SignedWatermarker(me));
      final report = verifyDocument(await handler.extractText(marked),
          expectedPublicKey: me.publicKeyBytes);
      expect(report.hasGenuineSeal, isTrue);
      expect(report.documentIntact, isTrue);
      expect(report.matchesExpectedAuthor, isTrue);
    });
  });

  group('HtmlHandler', () {
    const html = '<html><head><title>Secret Title</title>'
        '<meta name="author" content="nobody"></head>'
        '<body><h1>My Research</h1>'
        '<p>The measured signal clearly exceeds the predicted baseline today.</p>'
        '<script>var keep = "do not touch this script";</script>'
        '<style>.c { color: red; }</style>'
        '<!-- a comment node --></body></html>';

    test('marks visible body text and verifies', () async {
      final me = _author();
      final marked = await HtmlHandler().mark(_utf8(html), SignedWatermarker(me));
      final text = await HtmlHandler().extractText(marked);
      final report =
          verifyDocument(text, expectedPublicKey: me.publicKeyBytes);
      expect(report.hasGenuineSeal, isTrue);
      expect(report.documentIntact, isTrue);
      // Head/title/meta text is not part of the visible extract.
      expect(text.contains('Secret Title'), isFalse);
      expect(text.contains('My Research'), isTrue);
    });

    test('never watermarks script, style, title, or meta nodes', () async {
      final marked = await HtmlHandler().mark(_utf8(html), PlainWatermarker('sig'));
      final doc = html_parser.parse(utf8.decode(marked));

      final scriptText = doc.getElementsByTagName('script').first.text;
      final styleText = doc.getElementsByTagName('style').first.text;
      final titleText = doc.getElementsByTagName('title').first.text;
      // Unmarked nodes are byte-identical after stripping zero-width ink.
      expect(stripWatermarks(scriptText), scriptText);
      expect(stripWatermarks(styleText), styleText);
      expect(stripWatermarks(titleText), titleText);
      expect(scriptText.contains('do not touch this script'), isTrue);

      // A visible body paragraph *was* marked.
      final pText = doc.getElementsByTagName('p').first.text;
      expect(stripWatermarks(pText), isNot(pText));
    });
  });

  group('DocxHandler', () {
    final handler = DocxHandler();
    final paras = ['My confidential research results.', 'A second paragraph here.'];

    test('plain round-trip across paragraphs', () async {
      final marked = await handler.mark(_docx(paras), PlainWatermarker('Malcolm-2026'));
      final text = await handler.extractText(marked);
      expect(extractSignatures(text), ['Malcolm-2026']);
      expect(stripWatermarks(text), paras.join('\n'));
    });

    test('signed seal survives and verifies as intact', () async {
      final me = _author();
      final marked = await handler.mark(_docx(paras), SignedWatermarker(me));
      final report = verifyDocument(await handler.extractText(marked),
          expectedPublicKey: me.publicKeyBytes);
      expect(report.hasGenuineSeal, isTrue);
      expect(report.documentIntact, isTrue);
    });
  });

  group('XlsxHandler', () {
    final handler = XlsxHandler();
    final strings = ['Revenue', 'Profit margin analysis', 'Secret formula notes'];

    test('signed seal across shared strings verifies', () async {
      final me = _author();
      final marked = await handler.mark(_xlsx(strings), SignedWatermarker(me));
      final text = await handler.extractText(marked);
      expect(stripWatermarks(text), strings.join('\n'));
      expect(
          verifyDocument(text, expectedPublicKey: me.publicKeyBytes).documentIntact,
          isTrue);
    });
  });

  group('PptxHandler', () {
    final handler = PptxHandler();
    final runs = ['Quarterly Review', 'Our results beat the forecast this quarter.'];

    test('signed seal across slide text verifies', () async {
      final me = _author();
      final marked = await handler.mark(_pptx(runs), SignedWatermarker(me));
      final text = await handler.extractText(marked);
      expect(stripWatermarks(text), runs.join('\n'));
      expect(
          verifyDocument(text, expectedPublicKey: me.publicKeyBytes).documentIntact,
          isTrue);
    });
  });

  group('FormatRegistry', () {
    test('dispatches by extension, case-insensitively', () {
      final registry = FormatRegistry();
      expect(registry.handlerFor('notes.txt'), isA<TextHandler>());
      expect(registry.handlerFor('page.HTML'), isA<HtmlHandler>());
      expect(registry.handlerFor('report.docx'), isA<DocxHandler>());
      expect(registry.handlerFor('book.xlsx'), isA<XlsxHandler>());
      expect(registry.handlerFor('deck.pptx'), isA<PptxHandler>());
      expect(registry.supports('a.md'), isTrue);
      expect(registry.supports('archive.zip'), isFalse);
    });

    test('throws UnsupportedDocumentFormat for unknown extensions', () {
      final registry = FormatRegistry();
      expect(() => registry.mark(Uint8List(0), 'a.zip', PlainWatermarker('x')),
          throwsA(isA<UnsupportedDocumentFormat>()));
    });

    test('PDF is surfaced as unavailable, never silent', () async {
      final registry = FormatRegistry();
      expect(registry.handlerFor('paper.pdf'), isA<PdfHandlerUnavailable>());
      await expectLater(registry.extractText(Uint8List(0), 'paper.pdf'),
          throwsA(isA<PdfHandlerNotWired>()));
    });

    test('a real PDF handler can be registered to override the placeholder', () {
      final registry = FormatRegistry()..register(_StubPdf());
      expect(registry.handlerFor('paper.pdf'), isA<_StubPdf>());
    });
  });
}

/// Stand-in for an app-layer PDF handler, used only to prove registration works.
class _StubPdf implements FormatHandler {
  @override
  Set<String> get extensions => const {'pdf'};
  @override
  String get name => 'Stub PDF';
  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) async => bytes;
  @override
  Future<String> extractText(Uint8List bytes) async => '';
}
