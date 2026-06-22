/// Native (dart:io) file backend for [SignatureTemplateStore].
///
/// Import this in addition to `signature_storage.dart` on platforms with a
/// filesystem. A web build should not import this entrypoint.
library;

export 'src/file_template_storage_backend.dart'
    show FileTemplateStorageBackend;
