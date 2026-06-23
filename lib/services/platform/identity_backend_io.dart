import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:signature_storage/io.dart';
import 'package:signature_storage/signature_storage.dart';

/// Native backend: the identity JSON lives next to the templates, at
/// `<app documents>/watermark/identity.json`.
Future<TemplateStorageBackend> createIdentityBackend() async {
  final dir = await getApplicationDocumentsDirectory();
  return FileTemplateStorageBackend(
      File('${dir.path}/watermark/identity.json'));
}
