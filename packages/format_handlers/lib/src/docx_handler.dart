import 'dart:typed_data';

import 'package:watermark_engine/watermark_engine.dart';

import 'format_handler.dart';
import 'ooxml.dart';

/// Word documents: watermarks every `<w:t>` text run in `word/document.xml`,
/// which covers body paragraphs and tables alike.
class DocxHandler implements FormatHandler {
  static bool _isTarget(String name) => name == 'word/document.xml';
  static const _tags = {'w:t'};

  @override
  Set<String> get extensions => const {'docx'};

  @override
  String get name => 'Word (DOCX)';

  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) =>
      markOoxml(bytes, watermarker, isTarget: _isTarget, tags: _tags);

  @override
  Future<String> extractText(Uint8List bytes) =>
      extractOoxmlText(bytes, isTarget: _isTarget, tags: _tags);
}
