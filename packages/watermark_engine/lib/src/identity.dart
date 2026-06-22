import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'text_utils.dart';

/// An author's signing identity: a human-readable [authorId] plus an Ed25519
/// keypair. The private key is the "stamp" only this author holds; the public
/// key is what anyone uses to verify a seal.
///
/// This class holds the keys in memory and knows how to (de)serialize them, but
/// it does **not** persist them — storing the private key securely is the app
/// layer's job (e.g. platform secure storage). The recommended thing to persist
/// is the 32-byte [seed]; the full keypair is regenerated from it on load.
class AuthorIdentity {
  AuthorIdentity({
    required this.authorId,
    required ed.PrivateKey privateKey,
    required ed.PublicKey publicKey,
  })  : edPrivateKey = privateKey,
        edPublicKey = publicKey;

  /// Generates a brand-new random identity for [authorId].
  factory AuthorIdentity.generate(String authorId) {
    final pair = ed.generateKey();
    return AuthorIdentity(
      authorId: authorId,
      privateKey: pair.privateKey,
      publicKey: pair.publicKey,
    );
  }

  /// Recreates an identity deterministically from a stored 32-byte [seed].
  factory AuthorIdentity.fromSeed(String authorId, List<int> seed) {
    if (seed.length != 32) {
      throw ArgumentError.value(seed.length, 'seed.length', 'must be 32 bytes');
    }
    final privateKey = ed.newKeyFromSeed(Uint8List.fromList(seed));
    return AuthorIdentity(
      authorId: authorId,
      privateKey: privateKey,
      publicKey: ed.public(privateKey),
    );
  }

  final String authorId;
  final ed.PrivateKey edPrivateKey;
  final ed.PublicKey edPublicKey;

  /// The 32-byte public key bytes.
  List<int> get publicKeyBytes => edPublicKey.bytes;

  /// The 32-byte seed — the only secret worth persisting; the rest derives from
  /// it. Keep this somewhere safe (platform secure storage).
  List<int> get seed => edPrivateKey.bytes.sublist(0, 32);

  /// Lowercase hex of the public key, for one-time out-of-band sharing so other
  /// people can recognise this identity's seals as yours.
  String get publicKeyHex => toHex(publicKeyBytes);

  /// A short, human-glanceable fingerprint of the public key.
  String get fingerprint => toHex(publicKeyBytes.take(4));

  @override
  String toString() => 'AuthorIdentity($authorId, key: $fingerprint)';
}
