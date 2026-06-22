/// A named, reusable signature string (e.g. `'Project Atlas'` -> `'Malcolm-2026'`).
class SignatureTemplate {
  const SignatureTemplate(this.name, this.signature);

  /// The template's display name / key.
  final String name;

  /// The signature text embedded when this template is used.
  final String signature;

  @override
  bool operator ==(Object other) =>
      other is SignatureTemplate &&
      other.name == name &&
      other.signature == signature;

  @override
  int get hashCode => Object.hash(name, signature);

  @override
  String toString() => 'SignatureTemplate($name)';
}

/// Thrown when the stored signatures file exists but cannot be understood, so
/// the user's data is never silently discarded.
class SignatureStoreException implements Exception {
  SignatureStoreException(this.message);

  final String message;

  @override
  String toString() => 'SignatureStoreException: $message';
}
