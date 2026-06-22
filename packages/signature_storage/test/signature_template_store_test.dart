import 'dart:convert';

import 'package:signature_storage/signature_storage.dart';
import 'package:test/test.dart';

void main() {
  late MemoryTemplateStorageBackend backend;
  late SignatureTemplateStore store;

  setUp(() {
    backend = MemoryTemplateStorageBackend();
    store = SignatureTemplateStore(backend);
  });

  group('empty store', () {
    test('reports nothing', () async {
      expect(await store.list(), isEmpty);
      expect(await store.get('anything'), isNull);
      expect(await store.getDefault(), isNull);
    });
  });

  group('save and default rules', () {
    test('the first saved template becomes the default', () async {
      await store.save('Work', 'Malcolm-2026');
      expect(await store.get('Work'), 'Malcolm-2026');
      expect(await store.getDefault(), const SignatureTemplate('Work', 'Malcolm-2026'));
    });

    test('a later save does not change the default by itself', () async {
      await store.save('Work', 'Malcolm-2026');
      await store.save('Blog', 'MK');
      expect(await store.getDefault(), const SignatureTemplate('Work', 'Malcolm-2026'));
    });

    test('makeDefault promotes a template to default', () async {
      await store.save('Work', 'Malcolm-2026');
      await store.save('Blog', 'MK', makeDefault: true);
      expect(await store.getDefault(), const SignatureTemplate('Blog', 'MK'));
    });

    test('saving an existing name overwrites its signature', () async {
      await store.save('Work', 'old');
      await store.save('Work', 'new');
      expect(await store.get('Work'), 'new');
      expect(await store.list(), hasLength(1));
    });

    test('rejects empty name or signature', () {
      expect(() => store.save('', 'sig'), throwsArgumentError);
      expect(() => store.save('   ', 'sig'), throwsArgumentError);
      expect(() => store.save('Name', ''), throwsArgumentError);
    });

    test('list is sorted by name', () async {
      await store.save('Zeta', 'z');
      await store.save('Alpha', 'a');
      await store.save('Mu', 'm');
      expect((await store.list()).map((t) => t.name), ['Alpha', 'Mu', 'Zeta']);
    });
  });

  group('setDefault', () {
    test('changes the default to an existing template', () async {
      await store.save('Work', 'w');
      await store.save('Blog', 'b');
      await store.setDefault('Blog');
      expect((await store.getDefault())!.name, 'Blog');
    });

    test('throws for a non-existent template', () {
      expect(() => store.setDefault('Ghost'), throwsArgumentError);
    });
  });

  group('delete', () {
    test('removing a non-default template leaves the default intact', () async {
      await store.save('Work', 'w'); // default
      await store.save('Blog', 'b');
      await store.delete('Blog');
      expect(await store.get('Blog'), isNull);
      expect((await store.getDefault())!.name, 'Work');
    });

    test('removing the default reassigns it to the next template by name', () async {
      await store.save('Work', 'w', makeDefault: true);
      await store.save('Alpha', 'a');
      await store.save('Mu', 'm');
      await store.delete('Work'); // remaining: Alpha, Mu -> Alpha
      expect((await store.getDefault())!.name, 'Alpha');
    });

    test('removing the last template clears the default', () async {
      await store.save('Only', 'o');
      await store.delete('Only');
      expect(await store.getDefault(), isNull);
      expect(await store.list(), isEmpty);
    });

    test('deleting a missing template is a no-op', () async {
      await store.save('Work', 'w');
      await store.delete('Ghost');
      expect((await store.getDefault())!.name, 'Work');
      expect(await store.list(), hasLength(1));
    });
  });

  group('persistence and JSON schema', () {
    test('state survives a fresh store over the same backend', () async {
      await store.save('Work', 'Malcolm-2026');
      await store.save('Blog', 'MK', makeDefault: true);

      final reopened = SignatureTemplateStore(backend);
      expect((await reopened.getDefault())!.name, 'Blog');
      expect((await reopened.list()).map((t) => t.name), ['Blog', 'Work']);
    });

    test('writes the documented schema', () async {
      await store.save('Work', 'Malcolm-2026', makeDefault: true);
      final decoded = json.decode(backend.data!) as Map<String, dynamic>;
      expect(decoded['default'], 'Work');
      expect(decoded['templates'], {'Work': 'Malcolm-2026'});
    });

    test('tolerates an empty object', () async {
      final emptyStore =
          SignatureTemplateStore(MemoryTemplateStorageBackend('{}'));
      expect(await emptyStore.list(), isEmpty);
      expect(await emptyStore.getDefault(), isNull);
    });

    test('throws a clear error on corrupt JSON rather than losing data', () {
      final brokenStore =
          SignatureTemplateStore(MemoryTemplateStorageBackend('not json {'));
      expect(brokenStore.list(), throwsA(isA<SignatureStoreException>()));
    });

    test('throws on a wrong-typed templates field', () {
      final badStore = SignatureTemplateStore(
          MemoryTemplateStorageBackend('{"templates": [1, 2, 3]}'));
      expect(badStore.list(), throwsA(isA<SignatureStoreException>()));
    });
  });
}
