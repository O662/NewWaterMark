// Selects the storage backend per platform without pulling dart:io into a web
// build: native gets a file-backed store; web/other gets an in-memory fallback.
export 'template_backend_fallback.dart'
    if (dart.library.io) 'template_backend_io.dart';
