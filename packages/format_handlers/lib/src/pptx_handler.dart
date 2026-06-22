import 'dart:typed_data';

import 'package:watermark_engine/watermark_engine.dart';

import 'format_handler.dart';
import 'ooxml.dart';

/// PowerPoint decks: watermarks every `<a:t>` text run across the slides
/// (`ppt/slides/slide*.xml`).
class PptxHandler implements FormatHandler {
  static bool _isTarget(String name) =>
      name.startsWith('ppt/slides/slide') && name.endsWith('.xml');
  static const _tags = {'a:t'};

  @override
  Set<String> get extensions => const {'pptx'};

  @override
  String get name => 'PowerPoint (PPTX)';

  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) =>
      markOoxml(bytes, watermarker, isTarget: _isTarget, tags: _tags);

  @override
  Future<String> extractText(Uint8List bytes) =>
      extractOoxmlText(bytes, isTarget: _isTarget, tags: _tags);
}
