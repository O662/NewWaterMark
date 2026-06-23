import 'package:flutter/foundation.dart';
import 'package:signature_storage/signature_storage.dart';

/// App-wide state for signature templates, backed by [SignatureTemplateStore].
class TemplateService extends ChangeNotifier {
  TemplateService(this._store);

  final SignatureTemplateStore _store;

  List<SignatureTemplate> _templates = const [];
  String? _defaultName;
  bool _loading = true;
  Object? _error;

  List<SignatureTemplate> get templates => _templates;
  String? get defaultName => _defaultName;
  bool get isLoading => _loading;
  Object? get error => _error;
  bool get isEmpty => _templates.isEmpty;

  SignatureTemplate? get defaultTemplate {
    final name = _defaultName;
    if (name == null) return null;
    for (final t in _templates) {
      if (t.name == name) return t;
    }
    return null;
  }

  Future<void> load() async {
    try {
      _templates = await _store.list();
      _defaultName = (await _store.getDefault())?.name;
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(String name, String signature,
      {bool makeDefault = false}) async {
    await _store.save(name, signature, makeDefault: makeDefault);
    await load();
  }

  Future<void> delete(String name) async {
    await _store.delete(name);
    await load();
  }

  Future<void> setDefault(String name) async {
    await _store.setDefault(name);
    await load();
  }
}
