import 'dart:typed_data';
import 'dart:ui';

import 'package:format_handlers/format_handlers.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:watermark_engine/watermark_engine.dart';

/// The real PDF handler (Flutter-only: needs Syncfusion + a bundled Unicode
/// font). Registered by the app to replace the [PdfHandlerUnavailable] stub.
///
/// **Non-destructive:** the original PDF is preserved exactly — layout, fonts,
/// images and all — and the watermark is *added* to it on two channels:
///
///  1. **Metadata (primary, robust):** the watermarked text is stored in the
///     document Keywords, which always round-trips.
///  2. **Invisible text layer (secondary):** the watermarked text is drawn over
///     the first page with full transparency, so it is invisible to a reader but
///     still present in the text layer and recoverable by extraction.
///
/// [extractText] prefers whichever channel actually carries a watermark.
class PdfHandler implements FormatHandler {
  PdfHandler(this.fontBytes);

  /// Bytes of a Unicode TrueType font (DejaVuSans), injected so the handler
  /// stays testable; the app loads it from assets.
  final List<int> fontBytes;

  @override
  Set<String> get extensions => const {'pdf'};

  @override
  String get name => 'PDF';

  @override
  Future<String> extractText(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final visible = PdfTextExtractor(document).extractText();
      if (countWatermarks(visible) > 0) return visible; // text-layer channel
      final keywords = document.documentInformation.keywords;
      if (keywords.isNotEmpty && countWatermarks(keywords) > 0) {
        return keywords; // metadata channel
      }
      return visible; // nothing embedded — return the plain text
    } finally {
      document.dispose();
    }
  }

  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) async {
    // Load the original document; we modify and re-save it, preserving content.
    final document = PdfDocument(inputBytes: bytes);
    try {
      final clean = stripWatermarks(PdfTextExtractor(document).extractText());
      if (clean.trim().isEmpty) {
        throw const PdfNoTextException();
      }
      final watermarked = watermarker.prepare(clean)(clean);

      // Channel 1: metadata (always recoverable, never alters appearance).
      document.documentInformation.keywords = watermarked;

      // Channel 2: an invisible (fully transparent) text layer on the first
      // page. The reader sees no change; extraction still recovers the text.
      final page = document.pages[0];
      final size = page.getClientSize();
      final state = page.graphics.save();
      page.graphics.setTransparency(0);
      page.graphics.drawString(
        watermarked,
        PdfTrueTypeFont(fontBytes, 11),
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
        bounds: Rect.fromLTWH(0, 0, size.width, size.height),
      );
      page.graphics.restore(state);

      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }
}

/// Thrown when a PDF has no extractable text layer (e.g. scanned images), so
/// there is nothing to derive a watermark from.
class PdfNoTextException implements Exception {
  const PdfNoTextException();

  String get message =>
      'This PDF has no extractable text to watermark (it may be scanned images).';

  @override
  String toString() => 'PdfNoTextException: $message';
}
