import 'dart:typed_data';

import 'package:watermark_engine/watermark_engine.dart';

import 'format_handler.dart';

/// Placeholder PDF handler registered by default.
///
/// Real PDF support cannot live in this pure-Dart package: it needs
/// `syncfusion_flutter_pdf` (which depends on Flutter) plus a bundled Unicode
/// TrueType font asset, because the zero-width characters are otherwise dropped
/// by many PDF fonts. That implementation belongs in the Flutter app layer and
/// is built last.
///
/// Until the app registers a real handler with [FormatRegistry.register], any
/// attempt to mark or read a PDF throws [PdfHandlerNotWired] — PDF is surfaced
/// as explicitly unavailable rather than failing silently.
class PdfHandlerUnavailable implements FormatHandler {
  @override
  Set<String> get extensions => const {'pdf'};

  @override
  String get name => 'PDF (best-effort — not yet wired)';

  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) async =>
      throw const PdfHandlerNotWired();

  @override
  Future<String> extractText(Uint8List bytes) async =>
      throw const PdfHandlerNotWired();
}

/// Thrown when PDF work is attempted before a real PDF handler is registered.
class PdfHandlerNotWired implements Exception {
  const PdfHandlerNotWired();

  String get message =>
      'PDF support needs the app layer to register a Flutter-backed handler '
      '(syncfusion_flutter_pdf + a bundled Unicode font) via '
      'FormatRegistry.register(...). Note that PDF marking is inherently lossy: '
      'the text is regenerated, so the original layout, fonts, and images are '
      'not preserved.';

  @override
  String toString() => 'PdfHandlerNotWired: $message';
}
