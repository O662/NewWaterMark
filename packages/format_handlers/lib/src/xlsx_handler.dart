import 'dart:typed_data';

import 'package:watermark_engine/watermark_engine.dart';

import 'format_handler.dart';
import 'ooxml.dart';

/// Excel workbooks: watermarks every `<t>` text element in the shared-strings
/// table and in any inline strings inside the worksheets.
///
/// `extractText` covers the same `<t>` elements that are marked (shared strings
/// plus inline), so signed-seal verification of the whole workbook stays
/// consistent.
class XlsxHandler implements FormatHandler {
  static bool _isTarget(String name) =>
      name == 'xl/sharedStrings.xml' ||
      (name.startsWith('xl/worksheets/') && name.endsWith('.xml'));
  static const _tags = {'t'};

  @override
  Set<String> get extensions => const {'xlsx'};

  @override
  String get name => 'Excel (XLSX)';

  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) =>
      markOoxml(bytes, watermarker, isTarget: _isTarget, tags: _tags);

  @override
  Future<String> extractText(Uint8List bytes) =>
      extractOoxmlText(bytes, isTarget: _isTarget, tags: _tags);
}
