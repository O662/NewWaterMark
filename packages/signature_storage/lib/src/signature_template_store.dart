import 'dart:convert';

import 'signature_template.dart';
import 'template_storage_backend.dart';

/// Persists named signature templates with a single default, as JSON:
///
/// ```json
/// { "default": "Work", "templates": { "Work": "Malcolm-2026", "Blog": "MK" } }
/// ```
///
/// Every operation reads the current state from the backend, so the stored file
/// is always the single source of truth (no stale in-memory cache).
class SignatureTemplateStore {
  SignatureTemplateStore(this._backend);

  final TemplateStorageBackend _backend;

  /// All templates, sorted by name.
  Future<List<SignatureTemplate>> list() async {
    final state = await _read();
    return state.templates.entries
        .map((e) => SignatureTemplate(e.key, e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The signature for [name], or `null` if there is no such template.
  Future<String?> get(String name) async => (await _read()).templates[name];

  /// The default template, or `null` if none is set (or it is missing).
  Future<SignatureTemplate?> getDefault() async {
    final state = await _read();
    final name = state.defaultName;
    if (name == null) return null;
    final signature = state.templates[name];
    return signature == null ? null : SignatureTemplate(name, signature);
  }

  /// Saves (or overwrites) the template [name] -> [signature].
  ///
  /// It becomes the default when [makeDefault] is true, or when no default is
  /// set yet. Throws [ArgumentError] for an empty name or signature.
  Future<void> save(
    String name,
    String signature, {
    bool makeDefault = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (signature.isEmpty) {
      throw ArgumentError.value(signature, 'signature', 'must not be empty');
    }
    final state = await _read();
    state.templates[name] = signature;
    if (makeDefault || state.defaultName == null) {
      state.defaultName = name;
    }
    await _write(state);
  }

  /// Deletes the template [name] (a no-op if it does not exist). If it was the
  /// default, the default is reassigned to the next template by name, or cleared
  /// when none remain.
  Future<void> delete(String name) async {
    final state = await _read();
    if (state.templates.remove(name) == null) return;
    if (state.defaultName == name) {
      final remaining = state.templates.keys.toList()..sort();
      state.defaultName = remaining.isEmpty ? null : remaining.first;
    }
    await _write(state);
  }

  /// Marks an existing template as the default. Throws [ArgumentError] if there
  /// is no template named [name].
  Future<void> setDefault(String name) async {
    final state = await _read();
    if (!state.templates.containsKey(name)) {
      throw ArgumentError.value(name, 'name', 'no such template');
    }
    state.defaultName = name;
    await _write(state);
  }

  Future<_State> _read() async {
    final raw = await _backend.read();
    if (raw == null || raw.trim().isEmpty) return _State(null, {});

    final Object? decoded;
    try {
      decoded = json.decode(raw);
    } on FormatException catch (e) {
      throw SignatureStoreException('signatures.json is not valid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw SignatureStoreException('signatures.json must be a JSON object.');
    }

    final defaultName = decoded['default'];
    if (defaultName != null && defaultName is! String) {
      throw SignatureStoreException('"default" must be a string or null.');
    }

    final templates = <String, String>{};
    final rawTemplates = decoded['templates'];
    if (rawTemplates is Map) {
      rawTemplates.forEach((key, value) {
        if (key is! String || value is! String) {
          throw SignatureStoreException('"templates" must map strings to strings.');
        }
        templates[key] = value;
      });
    } else if (rawTemplates != null) {
      throw SignatureStoreException('"templates" must be a JSON object.');
    }

    return _State(defaultName as String?, templates);
  }

  Future<void> _write(_State state) async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'default': state.defaultName,
      'templates': state.templates,
    });
    await _backend.write(json);
  }
}

/// Mutable in-memory view of the stored state for the duration of one operation.
class _State {
  _State(this.defaultName, this.templates);

  String? defaultName;
  final Map<String, String> templates;
}
