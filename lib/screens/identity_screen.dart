import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/identity_service.dart';
import '../widgets/labeled_section.dart';

class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Identity'), titleSpacing: 16),
      body: _body(context, identity),
    );
  }

  Widget _body(BuildContext context, IdentityService identity) {
    if (identity.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!identity.canManageIdentity) {
      return const _WebNote();
    }
    if (!identity.hasIdentity) {
      return _CreateIdentity(onCreate: (name) => identity.create(name));
    }
    return _IdentityDetails(identity: identity);
  }
}

/// Shown on web, where a private signing key cannot be stored securely.
class _WebNote extends StatelessWidget {
  const _WebNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text('Secure identities live on the app',
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'A browser has no secure keychain, so your private key is never '
              'stored here. Create and use your signing identity on the desktop '
              'or mobile app, where the device keychain protects it.\n\n'
              'This web version still verifies seals (which needs no secret) and '
              'adds plain watermarks.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateIdentity extends StatelessWidget {
  const _CreateIdentity({required this.onCreate});

  final Future<void> Function(String name) onCreate;

  Future<void> _create(BuildContext context) async {
    final controller = TextEditingController();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create your identity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your name or handle',
            hintText: 'e.g. Malcolm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (create == true && controller.text.trim().isNotEmpty) {
      await onCreate(controller.text.trim());
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text('Create your secure identity',
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Your identity is a private key that only you hold. With it you can '
              'seal documents so they are provably yours and tamper-evident — '
              'anyone can verify a seal, but nobody can forge it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add_moderator),
              label: const Text('Create identity'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityDetails extends StatelessWidget {
  const _IdentityDetails({required this.identity});

  final IdentityService identity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = identity.identity!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Panel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.verified_user,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.authorId, style: theme.textTheme.titleLarge),
                    Text('Fingerprint ${me.fingerprint}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        LabeledSection(
          title: 'Your public key',
          icon: Icons.key,
          subtitle: 'Share this so others can confirm your seals are really '
              'yours. It is safe to publish — it cannot sign anything.',
          trailing: FilledButton.tonalIcon(
            onPressed: () => _copy(context, me.publicKeyHex),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          child: Panel(
            child: SelectableText(
              me.publicKeyHex,
              style: const TextStyle(fontFamily: 'monospace', height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const _SecurityNote(),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          onPressed: () => _reset(context),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Reset identity'),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
        .showSnackBar(const SnackBar(content: Text('Public key copied.')));
  }

  Future<void> _reset(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset identity?'),
        content: const Text(
            'This deletes your private key from this device. Documents you have '
            'already sealed still verify, but new seals will use a different '
            'identity. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await identity.reset();
      messenger.showSnackBar(const SnackBar(content: Text('Identity reset.')));
    }
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your private key is kept in this device\'s secure keychain, '
              'encrypted and never sent anywhere. Keep your device secure — '
              'anyone with your key could forge your seals.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
