import 'dart:convert';

import 'package:signature_storage/signature_storage.dart';
import 'package:watermark_engine/watermark_engine.dart';

/// Persists the author's signing [AuthorIdentity] as JSON over a generic
/// [TemplateStorageBackend] (reused from signature_storage):
///
/// ```json
/// { "authorId": "Malcolm", "seed": "<base64 of the 32-byte seed>" }
/// ```
///
/// Only the 32-byte seed is stored; the keypair is regenerated from it on load.
///
/// Security note: the seed is the private key. The app wires this store to a
/// secure-keychain backend (see SecureStorageBackend), so it is encrypted at
/// rest. This class is backend-agnostic — it only reads/writes a JSON string.
class IdentityStore {
  IdentityStore(this._backend);

  final TemplateStorageBackend _backend;

  /// Loads the saved identity, or `null` if none has been created yet. Throws
  /// [IdentityStoreException] if stored data exists but is unreadable, so a key
  /// is never silently discarded.
  Future<AuthorIdentity?> load() async {
    final raw = await _backend.read();
    if (raw == null || raw.trim().isEmpty) return null;

    final Object? decoded;
    try {
      decoded = json.decode(raw);
    } on FormatException catch (e) {
      throw IdentityStoreException('identity.json is not valid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw IdentityStoreException('identity.json must be a JSON object.');
    }
    final authorId = decoded['authorId'];
    final seedB64 = decoded['seed'];
    if (authorId is! String || seedB64 is! String) {
      throw IdentityStoreException('identity.json is missing authorId or seed.');
    }
    final List<int> seed;
    try {
      seed = base64Decode(seedB64);
    } on FormatException {
      throw IdentityStoreException('identity.json has an invalid seed.');
    }
    try {
      return AuthorIdentity.fromSeed(authorId, seed);
    } on ArgumentError {
      throw IdentityStoreException('identity.json seed is the wrong length.');
    }
  }

  /// Saves [identity] (its author id and seed), replacing any existing one.
  Future<void> save(AuthorIdentity identity) async {
    await _backend.write(json.encode({
      'authorId': identity.authorId,
      'seed': base64Encode(identity.seed),
    }));
  }

  /// Removes the stored identity.
  Future<void> clear() async => _backend.write('');
}

/// Thrown when stored identity data exists but cannot be understood.
class IdentityStoreException implements Exception {
  IdentityStoreException(this.message);

  final String message;

  @override
  String toString() => 'IdentityStoreException: $message';
}
