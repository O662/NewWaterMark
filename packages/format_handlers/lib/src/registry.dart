import 'dart:typed_data';

import 'package:watermark_engine/watermark_engine.dart';

import 'docx_handler.dart';
import 'format_handler.dart';
import 'html_handler.dart';
import 'pdf_handler.dart';
import 'pptx_handler.dart';
import 'text_handler.dart';
import 'xlsx_handler.dart';

/// Routes a document to the right [FormatHandler] by file extension.
///
/// The five pure-Dart handlers (text, html, docx, xlsx, pptx) plus the
/// [PdfHandlerUnavailable] placeholder are registered by default. The app layer
/// replaces the PDF placeholder with a real Flutter-backed handler via
/// [register].
class FormatRegistry {
  FormatRegistry({bool registerDefaults = true}) {
    if (registerDefaults) {
      for (final handler in <FormatHandler>[
        TextHandler(),
        HtmlHandler(),
        DocxHandler(),
        XlsxHandler(),
        PptxHandler(),
        PdfHandlerUnavailable(),
      ]) {
        register(handler);
      }
    }
  }

  final Map<String, FormatHandler> _byExtension = {};

  /// Registers [handler] for all of its extensions, replacing any existing
  /// handler for those extensions (this is how the app swaps in real PDF support).
  void register(FormatHandler handler) {
    for (final extension in handler.extensions) {
      _byExtension[extension.toLowerCase()] = handler;
    }
  }

  /// All currently supported extensions (without dots).
  Set<String> get supportedExtensions => _byExtension.keys.toSet();

  /// The handler for [filename]'s extension, or `null` if unsupported.
  FormatHandler? handlerFor(String filename) =>
      _byExtension[_extensionOf(filename)];

  /// Whether [filename]'s extension has a registered handler.
  bool supports(String filename) => handlerFor(filename) != null;

  /// Watermarks [bytes] using the handler for [filename]'s extension.
  /// Throws [UnsupportedDocumentFormat] if the extension is unsupported.
  Future<Uint8List> mark(
    Uint8List bytes,
    String filename,
    Watermarker watermarker,
  ) =>
      _require(filename).mark(bytes, watermarker);

  /// Extracts visible text using the handler for [filename]'s extension.
  /// Throws [UnsupportedDocumentFormat] if the extension is unsupported.
  Future<String> extractText(Uint8List bytes, String filename) =>
      _require(filename).extractText(bytes);

  FormatHandler _require(String filename) {
    final handler = handlerFor(filename);
    if (handler == null) {
      throw UnsupportedDocumentFormat(
          _extensionOf(filename), supportedExtensions);
    }
    return handler;
  }
}

/// Lowercase extension of [filename] without the dot, or `''` if none.
String _extensionOf(String filename) {
  final slash = filename.lastIndexOf(RegExp(r'[\\/]'));
  final base = slash < 0 ? filename : filename.substring(slash + 1);
  final dot = base.lastIndexOf('.');
  if (dot <= 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}
