import 'dart:convert';
import 'dart:typed_data';

import 'package:watermark_engine/watermark_engine.dart';

import 'format_handler.dart';

/// Plain-text family (txt, md, markdown, rst, text, log): the whole UTF-8 string
/// is the single text run.
class TextHandler implements FormatHandler {
  @override
  Set<String> get extensions => const {'txt', 'md', 'markdown', 'rst', 'text', 'log'};

  @override
  String get name => 'Plain text';

  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) async {
    final text = utf8.decode(bytes);
    final marked = watermarker.prepare(text)(text);
    return Uint8List.fromList(utf8.encode(marked));
  }

  @override
  Future<String> extractText(Uint8List bytes) async => utf8.decode(bytes);
}
