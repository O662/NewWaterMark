import 'package:flutter_test/flutter_test.dart';
import 'package:signature_storage/signature_storage.dart';
import 'package:watermark/services/identity_store.dart';
import 'package:watermark_engine/watermark_engine.dart';

void main() {
  test('identity survives save/load and can still sign + verify', () async {
    final store = IdentityStore(MemoryTemplateStorageBackend());
    expect(await store.load(), isNull);

    final original = AuthorIdentity.generate('Malcolm');
    await store.save(original);

    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.authorId, 'Malcolm');
    expect(loaded.publicKeyBytes, original.publicKeyBytes);
    expect(loaded.seed, original.seed);

    // The reloaded key still produces seals that verify as the same author.
    final sealed = insertSignedWatermark('the original research text here', loaded);
    final report =
        verifyDocument(sealed, expectedPublicKey: original.publicKeyBytes);
    expect(report.hasGenuineSeal, isTrue);
    expect(report.matchesExpectedAuthor, isTrue);
  });

  test('clear removes the identity', () async {
    final store = IdentityStore(MemoryTemplateStorageBackend());
    await store.save(AuthorIdentity.generate('M'));
    await store.clear();
    expect(await store.load(), isNull);
  });

  test('throws on corrupt data rather than discarding the key', () {
    final store = IdentityStore(MemoryTemplateStorageBackend('not json {'));
    expect(store.load(), throwsA(isA<IdentityStoreException>()));
  });
}
