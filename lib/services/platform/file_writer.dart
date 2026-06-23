// Writes bytes to an absolute path on native platforms (used by the desktop
// "Save" dialog). On web there is no filesystem, so the unsupported shim is
// selected and this code path is never taken.
export 'file_writer_unsupported.dart'
    if (dart.library.io) 'file_writer_io.dart';
