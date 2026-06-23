import 'package:signature_storage/signature_storage.dart';

import '../local_storage_backend.dart';

/// Web backend: signature templates persist in the browser's localStorage.
/// (Templates are not secret; the private signing key is never stored on web.)
Future<TemplateStorageBackend> createTemplateBackend() async =>
    LocalStorageBackend('watermark.templates');
