import 'dart:typed_data';

import 'package:format_handlers/format_handlers.dart';
import 'package:watermark_engine/watermark_engine.dart';

/// Bridges the UI to the offline engine + format handlers.
class DocumentService {
  final FormatRegistry _registry = FormatRegistry();

  /// Registers (or replaces) a handler — used by the app to wire in the
  /// Flutter-backed PDF handler at startup.
  void register(FormatHandler handler) => _registry.register(handler);

  /// Whether a file with this name can be watermarked/checked.
  bool supports(String filename) => _registry.supports(filename);

  /// Human-readable list of supported extensions for empty/help states.
  String get supportedExtensionsLabel =>
      (_registry.supportedExtensions.toList()..sort())
          .map((e) => '.$e')
          .join('  ');

  // --- Marking -------------------------------------------------------------

  /// Marks pasted/typed text in one shot.
  String markText(String text, Watermarker watermarker) =>
      watermarker.prepare(text)(text);

  /// Marks a document's bytes, dispatched by [filename]'s extension.
  Future<Uint8List> markFile(
    Uint8List bytes,
    String filename,
    Watermarker watermarker,
  ) =>
      _registry.mark(bytes, filename, watermarker);

  /// Extracts a file's visible text (with watermarks intact) for checking.
  Future<String> extractText(Uint8List bytes, String filename) =>
      _registry.extractText(bytes, filename);

  // --- Checking (pure engine) ---------------------------------------------

  DocumentCheck check(String text, {String? expected}) =>
      checkDocument(text, expected: expected);

  List<WatermarkMatch> contexts(String text) =>
      findWatermarksWithContext(text);

  List<String> signatures(String text) => extractSignatures(text);

  String strip(String text) => stripWatermarks(text);
}
