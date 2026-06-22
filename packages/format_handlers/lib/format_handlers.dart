/// Offline, pure-Dart document format handlers for the NewWaterMark app.
///
/// Each [FormatHandler] is a pure byte transform (bytes in, bytes out) that
/// embeds or recovers a watermark via the `watermark_engine` [Watermarker]
/// strategy, so it works identically on every platform including web.
///
/// Use a [FormatRegistry] to dispatch by file extension:
///
/// ```dart
/// final registry = FormatRegistry();
/// final marked = await registry.mark(bytes, 'report.docx',
///     SignedWatermarker(identity));
/// final text = await registry.extractText(marked, 'report.docx');
/// ```
///
/// PDF is special: real support needs the Flutter app layer (see
/// [PdfHandlerUnavailable]) and is built last.
library;

export 'src/docx_handler.dart' show DocxHandler;
export 'src/format_handler.dart'
    show FormatHandler, UnsupportedDocumentFormat;
export 'src/html_handler.dart' show HtmlHandler;
export 'src/pdf_handler.dart' show PdfHandlerNotWired, PdfHandlerUnavailable;
export 'src/pptx_handler.dart' show PptxHandler;
export 'src/registry.dart' show FormatRegistry;
export 'src/text_handler.dart' show TextHandler;
export 'src/xlsx_handler.dart' show XlsxHandler;
