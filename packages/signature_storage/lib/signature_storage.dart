/// Offline persistence for named signature templates with a single default.
///
/// The default export is web-safe (no `dart:io`). For the native file backend,
/// import `package:signature_storage/io.dart` as well.
///
/// ```dart
/// final store = SignatureTemplateStore(
///     FileTemplateStorageBackend.inDocumentsDir(documentsDirPath));
/// await store.save('Work', 'Malcolm-2026'); // first save becomes default
/// final fallback = await store.getDefault();
/// ```
library;

export 'src/signature_template.dart'
    show SignatureStoreException, SignatureTemplate;
export 'src/signature_template_store.dart' show SignatureTemplateStore;
export 'src/template_storage_backend.dart'
    show MemoryTemplateStorageBackend, TemplateStorageBackend;
