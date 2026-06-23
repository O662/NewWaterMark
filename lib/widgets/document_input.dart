import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/file_io_service.dart';

enum InputMode { text, file }

/// Holds the current document input — either pasted text or a picked file — so
/// it can be shared by the Mark and Check screens.
class DocumentInputController extends ChangeNotifier {
  DocumentInputController() {
    text.addListener(notifyListeners);
  }

  final TextEditingController text = TextEditingController();
  InputMode _mode = InputMode.text;
  PickedDocument? _picked;

  InputMode get mode => _mode;
  PickedDocument? get picked => _picked;

  set mode(InputMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void setPicked(PickedDocument? doc) {
    _picked = doc;
    notifyListeners();
  }

  bool get hasContent => _mode == InputMode.text
      ? text.text.trim().isNotEmpty
      : _picked != null;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

class DocumentInput extends StatelessWidget {
  const DocumentInput({
    super.key,
    required this.controller,
    this.textHint,
    this.supportedHint,
  });

  final DocumentInputController controller;
  final String? textHint;
  final String? supportedHint;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<InputMode>(
              segments: const [
                ButtonSegment(
                  value: InputMode.text,
                  icon: Icon(Icons.notes),
                  label: Text('Text'),
                ),
                ButtonSegment(
                  value: InputMode.file,
                  icon: Icon(Icons.insert_drive_file_outlined),
                  label: Text('File'),
                ),
              ],
              selected: {controller.mode},
              onSelectionChanged: (s) => controller.mode = s.first,
            ),
            const SizedBox(height: 12),
            if (controller.mode == InputMode.text)
              TextField(
                controller: controller.text,
                minLines: 5,
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: textHint ?? 'Paste or type your text here…',
                ),
              )
            else
              _FilePane(controller: controller, supportedHint: supportedHint),
          ],
        );
      },
    );
  }
}

class _FilePane extends StatelessWidget {
  const _FilePane({required this.controller, this.supportedHint});

  final DocumentInputController controller;
  final String? supportedHint;

  Future<void> _pick(BuildContext context) async {
    final picked = await context.read<FileIoService>().pick();
    if (picked != null) controller.setPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final picked = controller.picked;

    if (picked == null) {
      return InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.upload_file, size: 40, color: scheme.primary),
              const SizedBox(height: 8),
              const Text('Choose a file'),
              if (supportedHint != null) ...[
                const SizedBox(height: 4),
                Text(
                  supportedHint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.description, color: scheme.onPrimaryContainer),
        ),
        title: Text(picked.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatBytes(picked.bytes.length)),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close),
          onPressed: () => controller.setPicked(null),
        ),
        onTap: () => _pick(context),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
