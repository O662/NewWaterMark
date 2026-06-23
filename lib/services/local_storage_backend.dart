import 'package:signature_storage/signature_storage.dart';
import 'package:web/web.dart' as web;

/// A [TemplateStorageBackend] backed by the browser's `localStorage` (web only).
///
/// Used to persist **non-secret** data — signature templates — across sessions
/// on the web build. Private keys are never stored here (signing is native-only;
/// see the web identity decision).
class LocalStorageBackend implements TemplateStorageBackend {
  LocalStorageBackend(this._key);

  final String _key;

  @override
  Future<String?> read() async => web.window.localStorage.getItem(_key);

  @override
  Future<void> write(String data) async =>
      web.window.localStorage.setItem(_key, data);
}
