import 'package:path_provider/path_provider.dart';
import 'package:signature_storage/io.dart';
import 'package:signature_storage/signature_storage.dart';

/// Native backend: a JSON file under the app documents directory. This is the
/// only place `path_provider` is used, keeping the storage package Flutter-free.
Future<TemplateStorageBackend> createTemplateBackend() async {
  final dir = await getApplicationDocumentsDirectory();
  return FileTemplateStorageBackend.inDocumentsDir(dir.path);
}
