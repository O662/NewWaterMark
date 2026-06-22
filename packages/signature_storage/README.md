# signature_storage

Offline persistence for **named signature templates** with a single default,
stored as JSON. Pure-Dart logic with the `dart:io` file backend split into a
separate entrypoint so a web build can swap in another backend.

## Schema

`<app documents dir>/watermark/signatures.json`:

```json
{
  "default": "Work",
  "templates": { "Work": "Malcolm-2026", "Blog": "MK" }
}
```

## Operations

```dart
Future<List<SignatureTemplate>> list();                    // sorted by name
Future<String?>           get(String name);
Future<SignatureTemplate?> getDefault();
Future<void> save(String name, String signature, {bool makeDefault = false});
Future<void> delete(String name);
Future<void> setDefault(String name);
```

- `save` becomes the default when `makeDefault` is true **or** no default is set.
- `delete` reassigns the default to the next template by name (or clears it) if
  the deleted one was the default.
- Corrupt JSON throws `SignatureStoreException` instead of silently discarding
  data; a missing file simply reads as empty.

## Wiring (native)

The store is Flutter-free; the app supplies the documents directory path via
`path_provider`:

```dart
import 'package:signature_storage/signature_storage.dart';
import 'package:signature_storage/io.dart';
import 'package:path_provider/path_provider.dart';

final dir = await getApplicationDocumentsDirectory();
final store = SignatureTemplateStore(
    FileTemplateStorageBackend.inDocumentsDir(dir.path));
```

On web, implement `TemplateStorageBackend` with a web-appropriate store
(e.g. `shared_preferences`/IndexedDB) and don't import `io.dart`.

## Tests

```bash
cd packages/signature_storage
dart pub get
dart test
```
