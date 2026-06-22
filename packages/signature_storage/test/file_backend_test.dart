@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:signature_storage/io.dart';
import 'package:signature_storage/signature_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sigstore_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('returns null before anything is saved', () async {
    final store = SignatureTemplateStore(
        FileTemplateStorageBackend.inDocumentsDir(tempDir.path));
    expect(await store.list(), isEmpty);
    expect(await store.getDefault(), isNull);
  });

  test('persists to <dir>/watermark/signatures.json and reads it back', () async {
    final backend = FileTemplateStorageBackend.inDocumentsDir(tempDir.path);
    final store = SignatureTemplateStore(backend);

    await store.save('Work', 'Malcolm-2026', makeDefault: true);
    await store.save('Blog', 'MK');

    final expectedPath = p.join(tempDir.path, 'watermark', 'signatures.json');
    expect(File(expectedPath).existsSync(), isTrue,
        reason: 'file should be created at the documented path');

    // A brand-new store over the same directory sees the persisted data.
    final reopened = SignatureTemplateStore(
        FileTemplateStorageBackend.inDocumentsDir(tempDir.path));
    expect((await reopened.getDefault())!.name, 'Work');
    expect((await reopened.list()).map((t) => t.name), ['Blog', 'Work']);
  });

  test('creates the watermark/ directory if it does not exist', () async {
    final nested = p.join(tempDir.path, 'does', 'not', 'exist', 'yet');
    final store = SignatureTemplateStore(
        FileTemplateStorageBackend.inDocumentsDir(nested));
    await store.save('Work', 'sig');
    expect(File(p.join(nested, 'watermark', 'signatures.json')).existsSync(),
        isTrue);
  });
}
