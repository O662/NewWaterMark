/// Code points and scheme constants used by the watermark codec.
///
/// The code points are the single source of truth and are kept as integers so
/// that **no literal invisible character ever appears in the source**. The
/// string/regex forms are derived from them at runtime via [String.fromCharCode].
/// For an app whose entire purpose is these characters, that guarantees a stray
/// editor, copy-paste, or line-ending conversion can never silently corrupt them.
///
/// All three code points live in the Basic Multilingual Plane, so each is a
/// single UTF-16 code unit, and none is matched by `\s` — which is what keeps
/// whitespace tokenization stable even when a watermark is embedded.
library;

/// Zero-width space (U+200B) — encodes a binary `0`.
const int zwspCodeUnit = 0x200B;

/// Zero-width non-joiner (U+200C) — encodes a binary `1`.
const int zwnjCodeUnit = 0x200C;

/// Zero-width joiner (U+200D) — used only to build the [marker] delimiter.
const int zwjCodeUnit = 0x200D;

/// Scheme version byte that leads every payload. The decoder routes on this
/// byte and rejects unknown values, so the format can evolve and foreign/older
/// data is refused cleanly instead of being silently misread.
///
/// `0x01` — plain signature: the payload is just a UTF-8 signature string.
const int plainSchemeVersion = 0x01;

/// `0x02` — signed seal: the payload is a cryptographic authorship proof
/// (author id + public key + timestamp + document hash + Ed25519 signature).
const int signedSchemeVersion = 0x02;

/// All zero-width code units the engine treats as its own "ink".
const Set<int> zeroWidthCodeUnits = {zwspCodeUnit, zwnjCodeUnit, zwjCodeUnit};

/// Bit character `0` as a one-unit string.
final String zwsp = String.fromCharCode(zwspCodeUnit);

/// Bit character `1` as a one-unit string.
final String zwnj = String.fromCharCode(zwnjCodeUnit);

/// Joiner as a one-unit string.
final String zwj = String.fromCharCode(zwjCodeUnit);

/// The delimiter that brackets every embedded payload: two consecutive ZWJ.
///
/// The bit alphabet ([zwsp]/[zwnj]) deliberately excludes ZWJ, so payload bits
/// can never be mistaken for a marker.
final String marker = String.fromCharCodes([zwjCodeUnit, zwjCodeUnit]);
