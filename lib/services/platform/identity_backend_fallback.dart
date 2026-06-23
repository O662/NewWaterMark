import 'package:signature_storage/signature_storage.dart';

/// Web/other fallback. In-memory for now; a web build can later store the seed
/// in a web-appropriate (ideally secure) location.
Future<TemplateStorageBackend> createIdentityBackend() async =>
    MemoryTemplateStorageBackend();
