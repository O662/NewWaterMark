import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:watermark_engine/src/codec.dart';
import 'package:watermark_engine/src/signed_payload.dart';
import 'package:watermark_engine/watermark_engine.dart';

/// A deterministic identity whose keypair is derived from [name], so signing is
/// reproducible across runs yet distinct names get distinct keys.
AuthorIdentity _fixedIdentity(String name) =>
    AuthorIdentity.fromSeed(name, sha256.convert(utf8.encode('seed:$name')).bytes);

/// The raw payload bytes of the first seal in a watermarked string.
List<int> _firstSealBytes(String text) =>
    bitsToBytes(watermarkPattern.firstMatch(text)!.group(1)!)!;

const _research =
    'My research shows the measured signal clearly exceeds the predicted '
    'baseline across every trial we ran during the long winter study period.';

void main() {
  group('seal a document and verify it', () {
    test('an intact sealed document verifies as genuine and untampered', () {
      final me = _fixedIdentity('Malcolm');
      final sealed = insertSignedWatermark(_research, me);
      final report = verifyDocument(sealed, expectedPublicKey: me.publicKeyBytes);

      expect(report.found, isTrue);
      expect(report.hasGenuineSeal, isTrue);
      expect(report.documentIntact, isTrue);
      expect(report.matchesExpectedAuthor, isTrue);
      expect(report.genuineAuthors, contains('Malcolm'));
    });

    test('the visible text is unchanged and fully recoverable', () {
      final sealed = insertSignedWatermark(_research, _fixedIdentity('Malcolm'));
      expect(sealed, isNot(_research));
      expect(stripWatermarks(sealed), _research);
    });

    test('at least one seal is embedded even when words < every', () {
      final me = _fixedIdentity('Malcolm');
      final sealed = insertSignedWatermark('hi there', me, every: 10);
      final report = verifyDocument(sealed, expectedPublicKey: me.publicKeyBytes);
      expect(report.hasGenuineSeal, isTrue);
    });

    test('signing is deterministic for a fixed identity and timestamp', () {
      final me = _fixedIdentity('Malcolm');
      final ts = DateTime.utc(2026, 1, 1, 12);
      final a = insertSignedWatermark(_research, me, timestamp: ts);
      final b = insertSignedWatermark(_research, me, timestamp: ts);
      expect(a, b);
    });
  });

  group('forgery resistance', () {
    test('a different key is not accepted as the expected author', () {
      final me = _fixedIdentity('Malcolm');
      final imposter = _fixedIdentity('Imposter');
      final sealed = insertSignedWatermark(_research, me);

      final report =
          verifyDocument(sealed, expectedPublicKey: imposter.publicKeyBytes);
      expect(report.matchesExpectedAuthor, isFalse);
      expect(report.genuineAuthors, contains('Malcolm'));
      expect(report.genuineAuthors, isNot(contains('Imposter')));
    });

    test('corrupting the signature is detected (not genuine)', () {
      final me = _fixedIdentity('Malcolm');
      final sealed = insertSignedWatermark(_research, me, every: 100);
      final bytes = List<int>.of(_firstSealBytes(sealed));
      bytes[bytes.length - 1] ^= 0x01; // flip one bit of the signature

      final report = verifyDocument(wrapBytesAsWatermark(bytes));
      expect(report.found, isTrue);
      expect(report.hasGenuineSeal, isFalse);
      expect(report.seals.single.seal.signatureValid, isFalse);
    });

    test('tampering with a signed field (authorId) invalidates the seal', () {
      final me = _fixedIdentity('Malcolm');
      final sealed = insertSignedWatermark(_research, me, every: 100);
      final bytes = List<int>.of(_firstSealBytes(sealed));
      bytes[2] ^= 0x01; // first byte of authorId is covered by the signature

      final report = verifyDocument(wrapBytesAsWatermark(bytes));
      expect(report.hasGenuineSeal, isFalse);
    });
  });

  group('tamper detection on the document text', () {
    test('editing a visible word keeps the seal genuine but no longer intact',
        () {
      final me = _fixedIdentity('Malcolm');
      final sealed = insertSignedWatermark(_research, me, every: 3);
      final edited = sealed.replaceFirst('measured', 'fabricated');

      final report = verifyDocument(edited, expectedPublicKey: me.publicKeyBytes);
      expect(report.hasGenuineSeal, isTrue); // signature itself is still valid
      expect(report.documentIntact, isFalse); // but text != what was sealed
      expect(report.seals.any((o) => o.matchesCurrentText), isFalse);
    });
  });

  group('copy-paste theft scenario', () {
    test('a fragment pasted elsewhere still carries a verifiable seal', () {
      final me = _fixedIdentity('Malcolm');
      final sealed = insertSignedWatermark(_research, me, every: 2);

      // Someone copies a chunk from the middle into their own document.
      final fragment =
          sealed.substring(sealed.length ~/ 4, (sealed.length * 3) ~/ 4);
      final theirDoc =
          'Here is my completely original analysis: $fragment ... as I wrote.';

      final report =
          verifyDocument(theirDoc, expectedPublicKey: me.publicKeyBytes);
      expect(report.hasGenuineSeal, isTrue,
          reason: 'the copied seal proves it came from Malcolm');
      expect(report.matchesExpectedAuthor, isTrue);
      expect(report.genuineAuthors, contains('Malcolm'));
      // It is a fragment, not the original whole document.
      expect(report.documentIntact, isFalse);
    });
  });

  group('separation between plain and signed schemes', () {
    test('a signed document exposes no plain signatures', () {
      final sealed = insertSignedWatermark(_research, _fixedIdentity('Malcolm'));
      expect(extractSignatures(sealed), isEmpty);
      expect(verifyDocument(sealed).hasGenuineSeal, isTrue);
    });

    test('a plain-signature document exposes no signed seals', () {
      final plain = insertWatermark(_research, 'Malcolm-2026');
      expect(verifyDocument(plain).found, isFalse);
      expect(extractSignatures(plain), ['Malcolm-2026']);
    });
  });

  group('parseSignedSeal structural safety', () {
    test('rejects too-short and non-v2 byte runs without throwing', () {
      expect(parseSignedSeal([signedSchemeVersion, 0x00]), isNull);
      expect(parseSignedSeal(List<int>.filled(300, 0)), isNull);
      expect(parseSignedSeal([plainSchemeVersion, 0x41, 0x42]), isNull);
    });
  });

  group('identity', () {
    test('fromSeed is deterministic and exposes the seed back', () {
      final seed = List<int>.generate(32, (i) => i * 2 % 256);
      final a = AuthorIdentity.fromSeed('X', seed);
      final b = AuthorIdentity.fromSeed('X', seed);
      expect(a.publicKeyHex, b.publicKeyHex);
      expect(a.seed, seed);
      expect(a.publicKeyBytes, hasLength(32));
    });

    test('rejects a seed of the wrong length', () {
      expect(() => AuthorIdentity.fromSeed('X', [1, 2, 3]), throwsArgumentError);
    });
  });

  group('argument validation', () {
    test('throws on content-free text', () {
      expect(() => insertSignedWatermark('   \n\t ', _fixedIdentity('M')),
          throwsArgumentError);
    });

    test('throws when every is less than 1', () {
      expect(() => insertSignedWatermark(_research, _fixedIdentity('M'), every: 0),
          throwsArgumentError);
    });
  });
}
