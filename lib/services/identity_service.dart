import 'package:flutter/foundation.dart';
import 'package:watermark_engine/watermark_engine.dart';

import 'identity_store.dart';

/// App-wide state for the author's signing identity (the cryptographic "stamp").
class IdentityService extends ChangeNotifier {
  IdentityService(this._store);

  final IdentityStore _store;

  AuthorIdentity? _identity;
  bool _loading = true;
  Object? _error;

  AuthorIdentity? get identity => _identity;
  bool get hasIdentity => _identity != null;
  bool get isLoading => _loading;
  Object? get error => _error;

  /// Whether this platform can hold a private signing identity. The web cannot
  /// store a key securely (a browser has no keychain), so on web identities are
  /// not created here — signing happens on the desktop/mobile apps, while the
  /// web build still verifies seals (which needs no secret).
  bool get canManageIdentity => !kIsWeb;

  Future<void> load() async {
    try {
      _identity = await _store.load();
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Generates and persists a fresh identity for [authorId], replacing any
  /// existing one. A no-op where identities cannot be managed (web).
  Future<void> create(String authorId) async {
    if (!canManageIdentity) return;
    final identity = AuthorIdentity.generate(authorId);
    await _store.save(identity);
    _identity = identity;
    notifyListeners();
  }

  /// Forgets the current identity (new documents can no longer be signed until
  /// a new identity is created).
  Future<void> reset() async {
    await _store.clear();
    _identity = null;
    notifyListeners();
  }
}
