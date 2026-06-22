/// Where the signatures JSON is read from and written to.
///
/// Keeping persistence behind this interface lets the store's logic stay pure
/// and testable, and lets each platform plug in its own storage (a file on
/// native via the dart:io backend in `io.dart`, something else on web).
abstract interface class TemplateStorageBackend {
  /// Returns the stored JSON, or `null` if nothing has been saved yet.
  Future<String?> read();

  /// Persists [data] (the complete JSON document), replacing any prior content.
  Future<void> write(String data);
}

/// An in-memory backend — used in tests and as a safe default/fallback.
class MemoryTemplateStorageBackend implements TemplateStorageBackend {
  MemoryTemplateStorageBackend([this._data]);

  String? _data;

  /// The current raw contents, for inspection in tests.
  String? get data => _data;

  @override
  Future<String?> read() async => _data;

  @override
  Future<void> write(String data) async => _data = data;
}
