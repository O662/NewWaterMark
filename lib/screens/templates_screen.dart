import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature_storage/signature_storage.dart';

import '../services/template_service.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = context.watch<TemplateService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Templates'), titleSpacing: 16),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: _body(context, templates),
    );
  }

  Widget _body(BuildContext context, TemplateService templates) {
    if (templates.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (templates.error != null) {
      return _Centered(
        icon: Icons.error_outline,
        title: 'Could not load templates',
        subtitle: '${templates.error}',
      );
    }
    if (templates.isEmpty) {
      return const _Centered(
        icon: Icons.bookmark_border,
        title: 'No templates yet',
        subtitle: 'Save the signatures you reuse so they are one tap away.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: templates.templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = templates.templates[i];
        final isDefault = t.name == templates.defaultName;
        return _TemplateTile(
          template: t,
          isDefault: isDefault,
          onSetDefault: () =>
              context.read<TemplateService>().setDefault(t.name),
          onDelete: () => _delete(context, t),
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final templates = context.read<TemplateService>();
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final signatureController = TextEditingController();
    var makeDefault = false;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: signatureController,
                decoration: const InputDecoration(
                  labelText: 'Signature',
                  hintText: 'e.g. Malcolm-2026',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: makeDefault,
                onChanged: (v) => setState(() => makeDefault = v ?? false),
                title: const Text('Set as default'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      final name = nameController.text.trim();
      final signature = signatureController.text.trim();
      if (name.isEmpty || signature.isEmpty) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Name and signature are both required.')));
      } else {
        await templates.save(name, signature, makeDefault: makeDefault);
      }
    }
    nameController.dispose();
    signatureController.dispose();
  }

  Future<void> _delete(BuildContext context, SignatureTemplate template) async {
    final templates = context.read<TemplateService>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${template.name}"?'),
        content: const Text(
            'This removes the template. Documents you have already watermarked '
            'are unaffected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await templates.delete(template.name);
      messenger.showSnackBar(
          SnackBar(content: Text('Deleted "${template.name}".')));
    }
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.isDefault,
    required this.onSetDefault,
    required this.onDelete,
  });

  final SignatureTemplate template;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: IconButton(
          tooltip: isDefault ? 'Default template' : 'Set as default',
          icon: Icon(isDefault ? Icons.star : Icons.star_border,
              color: isDefault ? scheme.primary : scheme.outline),
          onPressed: isDefault ? null : onSetDefault,
        ),
        title: Row(
          children: [
            Flexible(child: Text(template.name, overflow: TextOverflow.ellipsis)),
            if (isDefault) ...[
              const SizedBox(width: 8),
              _DefaultChip(),
            ],
          ],
        ),
        subtitle: Text(template.signature, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _DefaultChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Default',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer)),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
