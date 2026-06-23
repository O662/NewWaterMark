@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:watermark/services/pdf/pdf_handler.dart';
import 'package:watermark_engine/watermark_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> fontBytes;

  setUpAll(() {
    fontBytes = File('assets/fonts/DejaVuSans.ttf').readAsBytesSync();
  });

  Future<Uint8List> sourcePdf(String text) async {
    final document = PdfDocument();
    final page = document.pages.add();
    final size = page.getClientSize();
    PdfTextElement(text: text, font: PdfTrueTypeFont(fontBytes, 12)).draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, size.width, size.height),
    );
    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  test('a source PDF round-trips its plain text', () async {
    final pdf = await sourcePdf('The quick brown fox jumps over the lazy dog.');
    final handler = PdfHandler(fontBytes);
    final text = await handler.extractText(pdf);
    expect(text.contains('quick brown fox'), isTrue);
  });

  test('plain watermark survives a round-trip AND preserves the original text',
      () async {
    final pdf = await sourcePdf(
        'My research shows the measured signal clearly exceeds the baseline.');
    final handler = PdfHandler(fontBytes);

    final marked = await handler.mark(pdf, PlainWatermarker('Malcolm-2026'));
    final recovered = await handler.extractText(marked);

    expect(extractSignatures(recovered), contains('Malcolm-2026'));
    // Non-destructive: the original sentence is still there.
    expect(recovered.contains('measured signal'), isTrue);
  });

  test('marking does not add pages or destroy the original document', () async {
    final pdf = await sourcePdf('A single page of original content here.');
    final originalPages = PdfDocument(inputBytes: pdf).pages.count;

    final marked =
        await PdfHandler(fontBytes).mark(pdf, PlainWatermarker('Sig'));

    final markedDoc = PdfDocument(inputBytes: marked);
    expect(markedDoc.pages.count, originalPages, reason: 'no pages added');
    expect(PdfTextExtractor(markedDoc).extractText().contains('original content'),
        isTrue,
        reason: 'original text preserved');
    markedDoc.dispose();
  });

  test('cryptographic seal survives and verifies as genuine', () async {
    final pdf = await sourcePdf(
        'Confidential findings from the long winter study, documented in detail.');
    final me = AuthorIdentity.generate('Malcolm');
    final handler = PdfHandler(fontBytes);

    final marked = await handler.mark(pdf, SignedWatermarker(me));
    final report = verifyDocument(await handler.extractText(marked),
        expectedPublicKey: me.publicKeyBytes);

    expect(report.hasGenuineSeal, isTrue);
  });

  test('reports which channel carried the watermark', () async {
    final pdf = await sourcePdf(
        'A document whose text we will watermark and then inspect closely.');
    final handler = PdfHandler(fontBytes);
    final marked = await handler.mark(pdf, PlainWatermarker('Probe'));

    // Inspect the visible-text channel directly.
    final document = PdfDocument(inputBytes: marked);
    final visible = PdfTextExtractor(document).extractText();
    final keywords = document.documentInformation.keywords;
    document.dispose();

    // Always-true expectation; the prints below tell us what actually survived.
    expect(extractSignatures(keywords), contains('Probe'),
        reason: 'metadata channel must always carry the watermark');
    // ignore: avoid_print
    print('visible-text channel watermarks: ${countWatermarks(visible)}');
    // ignore: avoid_print
    print('metadata channel watermarks:     ${countWatermarks(keywords)}');
  });
}
