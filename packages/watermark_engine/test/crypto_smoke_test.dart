import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:test/test.dart';

/// De-risking probe: confirms the crypto libraries work offline in a plain
/// `dart test` (no Flutter), with the exact API the engine will rely on.
void main() {
  test('Ed25519 sign/verify round-trips and rejects forgery', () {
    final keyPair = ed.generateKey();
    final message = utf8.encode('hello research');

    final signature = ed.sign(keyPair.privateKey, message);
    expect(ed.verify(keyPair.publicKey, message, signature), isTrue);

    // A different key must not verify.
    final attacker = ed.generateKey();
    expect(ed.verify(attacker.publicKey, message, signature), isFalse);

    // Tampered message must not verify.
    final tampered = utf8.encode('hello stolen');
    expect(ed.verify(keyPair.publicKey, tampered, signature), isFalse);
  });

  test('deterministic key from seed (for reproducible tests)', () {
    final seed = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final a = ed.newKeyFromSeed(seed);
    final b = ed.newKeyFromSeed(seed);
    expect(ed.public(a).bytes, ed.public(b).bytes);
    expect(ed.public(a).bytes, hasLength(32));
  });

  test('sha256 fingerprint is stable and 32 bytes', () {
    final digest = sha256.convert(utf8.encode('the original text'));
    expect(digest.bytes, hasLength(32));
    expect(sha256.convert(utf8.encode('the original text')).bytes, digest.bytes);
  });
}
