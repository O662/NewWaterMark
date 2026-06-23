import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:format_handlers/format_handlers.dart';
import 'package:provider/provider.dart';
import 'package:watermark_engine/watermark_engine.dart';

import '../services/document_service.dart';
import '../services/file_io_service.dart';
import '../services/identity_service.dart';
import '../services/pdf/pdf_handler.dart';
import '../services/template_service.dart';
import '../widgets/document_input.dart';
import '../widgets/every_n_stepper.dart';
import '../widgets/labeled_section.dart';

enum _SigSource { defaultTemplate, saved, custom }

enum _MarkMode { plain, secure }

class MarkScreen extends StatefulWidget {
  const MarkScreen({super.key});

  @override
  State<MarkScreen> createState() => _MarkScreenState();
}

class _MarkScreenState extends State<MarkScreen> {
  final _input = DocumentInputController();
  final _customSig = TextEditingController();
  final _customName = TextEditingController();

  _MarkMode _mode = _MarkMode.plain;
  _SigSource _source = _SigSource.defaultTemplate;
  String? _savedName;
  bool _saveCustom = false;
  int _every = 2;
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _input.dispose();
    _customSig.dispose();
    _customName.dispose();
    super.dispose();
  }

  String? _resolveSignature(TemplateService templates) {
    switch (_source) {
      case _SigSource.defaultTemplate:
        return templates.defaultTemplate?.signature;
      case _SigSource.saved:
        for (final t in templates.templates) {
          if (t.name == _savedName) return t.signature;
        }
        return null;
      case _SigSource.custom:
        final value = _customSig.text.trim();
        return value.isEmpty ? null : value;
    }
  }

  Future<void> _onMark() async {
    final templates = context.read<TemplateService>();
    final identity = context.read<IdentityService>();
    final docs = context.read<DocumentService>();
    final fileIo = context.read<FileIoService>();
    final messenger = ScaffoldMessenger.of(context);

    if (!_input.hasContent) {
      _show(messenger, 'Add some text or pick a file first.');
      return;
    }

    // Build the watermarker for the selected mode.
    final Watermarker watermarker;
    if (_mode == _MarkMode.secure) {
      final me = identity.identity;
      if (me == null) {
        _show(messenger, 'Create your identity on the Identity tab first.');
        return;
      }
      watermarker = SignedWatermarker(me, every: _every);
    } else {
      final signature = _resolveSignature(templates);
      if (signature == null || signature.isEmpty) {
        _show(messenger, 'Choose a signature first.');
        return;
      }
      if (_source == _SigSource.custom && _saveCustom) {
        final name = _customName.text.trim();
        if (name.isEmpty) {
          _show(messenger, 'Enter a name to save this as a template.');
          return;
        }
        await templates.save(name, signature);
      }
      watermarker = PlainWatermarker(signature, every: _every);
    }

    if (_input.mode == InputMode.text) {
      setState(() => _result = docs.markText(_input.text.text, watermarker));
      return;
    }

    final picked = _input.picked!;
    if (!docs.supports(picked.name)) {
      _show(messenger, 'That file type is not supported.');
      return;
    }

    setState(() => _busy = true);
    try {
      final marked = await docs.markFile(picked.bytes, picked.name, watermarker);
      final result = await fileIo.deliver(marked, _suggestName(picked.name));
      if (!mounted) return;
      switch (result.kind) {
        case DeliveryKind.saved:
          _show(messenger, 'Saved to ${result.location}');
        case DeliveryKind.shared:
          _show(messenger, 'Shared the watermarked file.');
        case DeliveryKind.cancelled:
          break;
      }
    } on PdfNoTextException catch (e) {
      _show(messenger, e.message);
    } on PdfHandlerNotWired {
      _show(messenger, 'PDF watermarking is not available on this platform.');
    } on UnsupportedDocumentFormat catch (e) {
      _show(messenger, e.message);
    } catch (e) {
      _show(messenger, 'Could not mark the file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final templates = context.watch<TemplateService>();
    final identity = context.watch<IdentityService>();
    final docs = context.read<DocumentService>();
    final secure = _mode == _MarkMode.secure;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark'),
        titleSpacing: 16,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          LabeledSection(
            title: 'Document',
            icon: Icons.description_outlined,
            child: DocumentInput(
              controller: _input,
              supportedHint: docs.supportedExtensionsLabel,
            ),
          ),
          const SizedBox(height: 28),
          LabeledSection(
            title: 'Watermark type',
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<_MarkMode>(
                  segments: const [
                    ButtonSegment(
                        value: _MarkMode.plain,
                        icon: Icon(Icons.draw_outlined),
                        label: Text('Signature')),
                    ButtonSegment(
                        value: _MarkMode.secure,
                        icon: Icon(Icons.verified_user_outlined),
                        label: Text('Secure seal')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 16),
                if (secure)
                  _SecureSource(identity: identity)
                else
                  _SignatureSource(
                    templates: templates,
                    source: _source,
                    onSourceChanged: (s) => setState(() => _source = s),
                    savedName: _savedName,
                    onSavedChanged: (n) => setState(() => _savedName = n),
                    customController: _customSig,
                    customNameController: _customName,
                    saveCustom: _saveCustom,
                    onSaveCustomChanged: (v) => setState(() => _saveCustom = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          LabeledSection(
            title: 'Density',
            icon: Icons.tune,
            child: EveryNStepper(
              value: _every,
              onChanged: (v) => setState(() => _every = v),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _busy ? null : _onMark,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(secure ? Icons.verified_user : Icons.water_drop),
            label: Text(_busy
                ? 'Working…'
                : (secure ? 'Embed secure seal' : 'Embed watermark')),
          ),
          if (_result != null) ...[
            const SizedBox(height: 28),
            _TextResult(
              marked: _result!,
              onCopy: () => _copy(_result!),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copy(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _show(messenger, 'Copied — the invisible watermark travels with it.');
  }
}

String _suggestName(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot <= 0) return '$filename.watermarked';
  return '${filename.substring(0, dot)}.watermarked${filename.substring(dot)}';
}

class _SignatureSource extends StatelessWidget {
  const _SignatureSource({
    required this.templates,
    required this.source,
    required this.onSourceChanged,
    required this.savedName,
    required this.onSavedChanged,
    required this.customController,
    required this.customNameController,
    required this.saveCustom,
    required this.onSaveCustomChanged,
  });

  final TemplateService templates;
  final _SigSource source;
  final ValueChanged<_SigSource> onSourceChanged;
  final String? savedName;
  final ValueChanged<String?> onSavedChanged;
  final TextEditingController customController;
  final TextEditingController customNameController;
  final bool saveCustom;
  final ValueChanged<bool> onSaveCustomChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_SigSource>(
          segments: const [
            ButtonSegment(value: _SigSource.defaultTemplate, label: Text('Default')),
            ButtonSegment(value: _SigSource.saved, label: Text('Saved')),
            ButtonSegment(value: _SigSource.custom, label: Text('Custom')),
          ],
          selected: {source},
          onSelectionChanged: (s) => onSourceChanged(s.first),
        ),
        const SizedBox(height: 16),
        switch (source) {
          _SigSource.defaultTemplate => _buildDefault(context),
          _SigSource.saved => _buildSaved(context),
          _SigSource.custom => _buildCustom(context),
        },
      ],
    );
  }

  Widget _buildDefault(BuildContext context) {
    final def = templates.defaultTemplate;
    if (def == null) {
      return const _InfoNote(
        icon: Icons.info_outline,
        text: 'No default template yet. Add one on the Templates tab, '
            'or pick "Custom".',
      );
    }
    return Panel(
      child: Row(
        children: [
          Icon(Icons.star, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(def.signature,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaved(BuildContext context) {
    if (templates.isEmpty) {
      return const _InfoNote(
        icon: Icons.info_outline,
        text: 'No saved templates yet. Add one on the Templates tab.',
      );
    }
    final names = templates.templates.map((t) => t.name).toList();
    final current = names.contains(savedName) ? savedName : null;
    return DropdownButtonFormField<String>(
      initialValue: current,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Template'),
      items: [
        for (final t in templates.templates)
          DropdownMenuItem(
            value: t.name,
            child: Text('${t.name}  —  ${t.signature}',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onSavedChanged,
    );
  }

  Widget _buildCustom(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: customController,
          decoration: const InputDecoration(
            labelText: 'Signature',
            hintText: 'e.g. Malcolm-2026',
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: saveCustom,
          onChanged: (v) => onSaveCustomChanged(v ?? false),
          title: const Text('Save this as a template'),
        ),
        if (saveCustom)
          TextField(
            controller: customNameController,
            decoration: const InputDecoration(
              labelText: 'Template name',
              hintText: 'e.g. Work',
            ),
          ),
      ],
    );
  }
}

class _SecureSource extends StatelessWidget {
  const _SecureSource({required this.identity});

  final IdentityService identity;

  @override
  Widget build(BuildContext context) {
    final me = identity.identity;
    if (me == null) {
      return const _InfoNote(
        icon: Icons.info_outline,
        text: 'Create your identity on the Identity tab to seal documents with '
            'an unforgeable, tamper-evident proof.',
      );
    }
    final theme = Theme.of(context);
    return Panel(
      child: Row(
        children: [
          Icon(Icons.verified_user, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sealing as ${me.authorId}',
                    style: theme.textTheme.titleSmall),
                Text(
                  'Fingerprint ${me.fingerprint} · unforgeable & tamper-evident',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextResult extends StatelessWidget {
  const _TextResult({required this.marked, required this.onCopy});

  final String marked;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LabeledSection(
      title: 'Watermarked text',
      icon: Icons.check_circle_outline,
      subtitle: 'Looks identical — the watermark is invisible. Copy and paste '
          'it anywhere.',
      trailing: FilledButton.tonalIcon(
        onPressed: onCopy,
        icon: const Icon(Icons.copy, size: 18),
        label: const Text('Copy'),
      ),
      child: Panel(
        child: SelectableText(
          marked,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
