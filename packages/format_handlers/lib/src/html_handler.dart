import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:watermark_engine/watermark_engine.dart';

import 'format_handler.dart';

/// HTML family (html, htm, xhtml): watermarks only visible text nodes, leaving
/// markup, scripts, styles, and head metadata untouched.
class HtmlHandler implements FormatHandler {
  /// Text whose immediate parent is one of these is never watermarked.
  static const _skipParents = {'script', 'style', 'title', 'meta', 'head'};

  @override
  Set<String> get extensions => const {'html', 'htm', 'xhtml'};

  @override
  String get name => 'HTML';

  @override
  Future<Uint8List> mark(Uint8List bytes, Watermarker watermarker) async {
    final document = html_parser.parse(utf8.decode(bytes));
    final transform = watermarker.prepare(_collect(document).join('\n'));
    for (final node in _markableTextNodes(document)) {
      node.data = transform(node.data);
    }
    return Uint8List.fromList(utf8.encode(document.outerHtml));
  }

  @override
  Future<String> extractText(Uint8List bytes) async {
    final document = html_parser.parse(utf8.decode(bytes));
    return _collect(document).join('\n');
  }

  /// The text of every markable node, in document order.
  List<String> _collect(Document document) =>
      [for (final node in _markableTextNodes(document)) node.data];

  /// All text nodes eligible for watermarking: non-empty (ignoring zero-width
  /// ink), not inside script/style/title/meta/head, and not comments.
  List<Text> _markableTextNodes(Document document) {
    final result = <Text>[];
    void walk(Node node) {
      for (final child in node.nodes) {
        if (child is Text) {
          final parentTag = child.parent?.localName?.toLowerCase();
          if (parentTag != null && _skipParents.contains(parentTag)) continue;
          if (child.data.trim().isEmpty) continue; // whitespace-only
          result.add(child);
        } else if (child is Element) {
          walk(child);
        }
        // Comment and other node types are intentionally skipped.
      }
    }

    walk(document);
    return result;
  }
}
