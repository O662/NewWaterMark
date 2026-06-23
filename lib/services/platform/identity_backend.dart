// Selects where the identity (private key seed) is stored per platform, keeping
// dart:io out of the web build: native -> a file in the app documents folder;
// web/other -> in-memory.
export 'identity_backend_fallback.dart'
    if (dart.library.io) 'identity_backend_io.dart';
