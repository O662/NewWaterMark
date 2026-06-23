import 'package:signature_storage/signature_storage.dart';

/// Web/other fallback. In-memory for now; a web build can later swap in a
/// localStorage/IndexedDB-backed implementation of [TemplateStorageBackend].
Future<TemplateStorageBackend> createTemplateBackend() async =>
    MemoryTemplateStorageBackend();
