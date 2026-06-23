import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signature_storage/signature_storage.dart';

/// A [TemplateStorageBackend] that keeps its value in the operating system's
/// secure credential store via `flutter_secure_storage`:
///
///  - Android: Keystore-backed EncryptedSharedPreferences
///  - iOS / macOS: Keychain (Secure Enclave)
///  - Windows: DPAPI (encrypted, bound to the user account)
///  - Linux: libsecret (GNOME Keyring / KWallet)
///  - Web: the plugin's browser storage — persistent, but not truly secure
///
/// Used for the author's private key so it is encrypted at rest rather than
/// living in a plain file. Writing an empty value clears the entry.
class SecureStorageBackend implements TemplateStorageBackend {
  SecureStorageBackend(this._key, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String data) =>
      _storage.write(key: _key, value: data.isEmpty ? null : data);
}
