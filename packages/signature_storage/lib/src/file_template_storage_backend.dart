import 'dart:io';

import 'package:path/path.dart' as p;

import 'template_storage_backend.dart';

/// A [TemplateStorageBackend] backed by a JSON file on disk (native platforms).
///
/// This is the only part of the package that imports `dart:io`, so it lives
/// behind the separate `package:signature_storage/io.dart` entrypoint and is
/// never pulled into a web build.
class FileTemplateStorageBackend implements TemplateStorageBackend {
  FileTemplateStorageBackend(this.file);

  /// Builds the backend at `<documentsDirPath>/watermark/signatures.json`.
  ///
  /// On native, `documentsDirPath` comes from
  /// `(await getApplicationDocumentsDirectory()).path` (package:path_provider),
  /// kept in the app layer so this package stays Flutter-free.
  factory FileTemplateStorageBackend.inDocumentsDir(String documentsDirPath) =>
      FileTemplateStorageBackend(
        File(p.join(documentsDirPath, 'watermark', 'signatures.json')),
      );

  /// The JSON file this backend reads and writes.
  final File file;

  @override
  Future<String?> read() async =>
      await file.exists() ? file.readAsString() : null;

  @override
  Future<void> write(String data) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(data);
  }
}
