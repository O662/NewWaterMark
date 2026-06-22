/// Small internal helpers shared across the engine, with no dependencies.
library;

/// Returns the 1-based `(line, column)` of [index] within [text]. Columns are
/// counted in UTF-16 code units (the zero-width characters are all single
/// units, so they count as one column each).
(int, int) lineColumnAt(String text, int index) {
  const newline = 0x0A; // '\n'
  var line = 1;
  var lineStart = 0;
  final limit = index < text.length ? index : text.length;
  for (var i = 0; i < limit; i++) {
    if (text.codeUnitAt(i) == newline) {
      line++;
      lineStart = i + 1;
    }
  }
  return (line, index - lineStart + 1);
}

/// Lowercase hex string of [bytes], two chars per byte.
String toHex(Iterable<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Whether two byte lists have identical length and contents.
bool bytesEqual(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
