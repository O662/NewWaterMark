import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:watermark_engine/watermark_engine.dart';
import 'package:xml/xml.dart';

/// Shared machinery for the OOXML (zip-of-XML) formats: DOCX, XLSX, PPTX.
///
/// Each format differs only in *which* archive members to edit and *which*
/// element names hold visible text. Everything else — unzip, parse, watermark
/// the matching elements, re-zip while preserving every other part — is common.

/// Selects which zip members an OOXML format edits.
typedef MemberFilter = bool Function(String name);

/// Watermarks every element whose qualified name is in [tags] (e.g. `w:t`),
/// inside the archive members matched by [isTarget], and returns the rebuilt
/// document bytes. All other parts are copied through unchanged.
Future<Uint8List> markOoxml(
  Uint8List bytes,
  Watermarker watermarker, {
  required MemberFilter isTarget,
  required Set<String> tags,
}) async {
  final archive = ZipDecoder().decodeBytes(bytes);
  final memberNames = _targetMembers(archive, isTarget);

  // Pass 1: parse targets and gather the full visible text (deterministic
  // order) so a whole-document seal can be built once.
  final parsed = <String, XmlDocument>{};
  final runs = <String>[];
  for (final name in memberNames) {
    final document = _parseMember(archive, name);
    parsed[name] = document;
    for (final element in _taggedElements(document, tags)) {
      runs.add(element.innerText);
    }
  }
  final transform = watermarker.prepare(runs.join('\n'));

  // Pass 2: apply the transform to non-empty elements and rebuild the archive.
  final output = Archive();
  for (final file in archive.files) {
    if (file.isFile && isTarget(file.name)) {
      final document = parsed[file.name]!;
      for (final element in _taggedElements(document, tags)) {
        final text = element.innerText;
        if (text.trim().isEmpty) continue;
        element.innerText = transform(text);
      }
      final data = utf8.encode(document.toXmlString());
      output.addFile(ArchiveFile(file.name, data.length, data));
    } else {
      output.addFile(file); // copy every other part verbatim
    }
  }

  final encoded = ZipEncoder().encode(output);
  if (encoded == null) {
    throw StateError('Failed to re-encode the OOXML archive.');
  }
  return Uint8List.fromList(encoded);
}

/// Extracts the visible text of every [tags] element across the target members,
/// joined in the same deterministic order [markOoxml] uses.
Future<String> extractOoxmlText(
  Uint8List bytes, {
  required MemberFilter isTarget,
  required Set<String> tags,
}) async {
  final archive = ZipDecoder().decodeBytes(bytes);
  final runs = <String>[];
  for (final name in _targetMembers(archive, isTarget)) {
    for (final element in _taggedElements(_parseMember(archive, name), tags)) {
      runs.add(element.innerText);
    }
  }
  return runs.join('\n');
}

List<String> _targetMembers(Archive archive, MemberFilter isTarget) =>
    archive.files
        .where((f) => f.isFile && isTarget(f.name))
        .map((f) => f.name)
        .toList()
      ..sort();

XmlDocument _parseMember(Archive archive, String name) =>
    XmlDocument.parse(utf8.decode(archive.findFile(name)!.content as List<int>));

/// The matching elements as a materialised list, so mutating one element's text
/// during pass 2 cannot disturb iteration.
List<XmlElement> _taggedElements(XmlDocument document, Set<String> tags) =>
    document.descendants
        .whereType<XmlElement>()
        .where((e) => tags.contains(e.name.qualified))
        .toList();
