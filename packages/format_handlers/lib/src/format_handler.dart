import 'dart:typed_data';

import 'package:watermark_engine/watermark_engine.dart';

/// Reads and writes one family of document formats, embedding/recovering
/// watermarks via the [Watermarker] strategy from `watermark_engine`.
///
/// Handlers are pure byte transforms — bytes in, bytes out — so they behave
/// identically on every platform (including web, which has no filesystem).
/// Reading and writing actual files is the storage layer's job, not the
/// handler's.
abstract interface class FormatHandler {
  /// Lowercase file extensions (without the dot) this handler serves.
  Set<String> get extensions;

  /// Human-readable label for UI and error messages.
  String get name;

  /// Returns a copy of the document [bytes] with [watermarker]'s mark embedded
  /// into its visible text. Structure, formatting, and non-text parts are
  /// preserved.
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker);

  /// Returns the document's visible text in a stable order, with any embedded
  /// watermarks left intact (so it can be passed straight to `verifyDocument`
  /// or `extractSignatures`).
  Future<String> extractText(Uint8List bytes);
}

/// Thrown when no handler is registered for a file's extension.
class UnsupportedDocumentFormat implements Exception {
  UnsupportedDocumentFormat(this.extension, this.supported);

  final String extension;
  final Set<String> supported;

  String get message => extension.isEmpty
      ? 'The file has no extension, so its format is unknown.'
      : 'No handler for ".$extension". '
          'Supported: ${(supported.toList()..sort()).join(', ')}.';

  @override
  String toString() => 'UnsupportedDocumentFormat: $message';
}
