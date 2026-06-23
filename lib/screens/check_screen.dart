import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:format_handlers/format_handlers.dart';
import 'package:provider/provider.dart';
import 'package:watermark_engine/watermark_engine.dart';

import '../services/document_service.dart';
import '../services/identity_service.dart';
import '../widgets/document_input.dart';
import '../widgets/labeled_section.dart';

class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key});

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  final _input = DocumentInputController();
  final _expected = TextEditingController();

  bool _busy = false;
  _Outcome? _outcome;

  @override
  void dispose() {
    _input.dispose();
    _expected.dispose();
    super.dispose();
  }

  Future<void> _onCheck() async {
    final docs = context.read<DocumentService>();
    final me = context.read<IdentityService>().identity;
    final messenger = ScaffoldMessenger.of(context);

    if (!_input.hasContent) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Add some text or pick a file first.')));
      return;
    }

    String text;
    if (_input.mode == InputMode.text) {
      text = _input.text.text;
    } else {
      final picked = _input.picked!;
      setState(() => _busy = true);
      try {
        text = await docs.extractText(picked.bytes, picked.name);
      } on PdfHandlerNotWired {
        if (mounted) {
          messenger.showSnackBar(const SnackBar(
              content: Text('Reading PDFs is not available yet.')));
        }
        return;
      } on UnsupportedDocumentFormat catch (e) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
        return;
      } catch (e) {
        if (mounted) {
          messenger
              .showSnackBar(SnackBar(content: Text('Could not read file: $e')));
        }
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    final expected = _expected.text.trim().isEmpty ? null : _expected.text.trim();
    setState(() {
      _outcome = _Outcome(
        check: docs.check(text, expected: expected),
        signatures: docs.signatures(text),
        report: verifyDocument(text, expectedPublicKey: me?.publicKeyBytes),
        cleaned: docs.strip(text),
        expected: expected,
      );
    });
  }

  Future<void> _showCleaned(String cleaned) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Watermarks removed'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(cleaned)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: cleaned));
              if (context.mounted) Navigator.pop(context);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Clean text copied.')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = context.read<DocumentService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Check'), titleSpacing: 16),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          LabeledSection(
            title: 'Document',
            icon: Icons.description_outlined,
            child: DocumentInput(
              controller: _input,
              textHint: 'Paste text to check for a watermark…',
              supportedHint: docs.supportedExtensionsLabel,
            ),
          ),
          const SizedBox(height: 24),
          LabeledSection(
            title: 'Check against (optional)',
            icon: Icons.compare_arrows,
            subtitle: 'Enter a signature to confirm a specific author.',
            child: TextField(
              controller: _expected,
              decoration: const InputDecoration(
                labelText: 'Expected signature',
                hintText: 'e.g. Malcolm-2026',
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _onCheck,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.travel_explore),
            label: Text(_busy ? 'Reading…' : 'Check document'),
          ),
          if (_outcome != null) ...[
            const SizedBox(height: 28),
            _Results(outcome: _outcome!, onStrip: _showCleaned),
          ],
        ],
      ),
    );
  }
}

class _Outcome {
  _Outcome({
    required this.check,
    required this.signatures,
    required this.report,
    required this.cleaned,
    required this.expected,
  });

  final DocumentCheck check;
  final List<String> signatures;
  final VerificationReport report;
  final String cleaned;
  final String? expected;
}

class _Results extends StatelessWidget {
  const _Results({required this.outcome, required this.onStrip});

  final _Outcome outcome;
  final ValueChanged<String> onStrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final check = outcome.check;

    final report = outcome.report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.found) ...[
          _SealCard(report: report),
          const SizedBox(height: 16),
        ],
        _SummaryCard(found: check.found, count: check.count),
        if (outcome.expected != null) ...[
          const SizedBox(height: 12),
          _MatchBadge(match: check.match ?? false, expected: outcome.expected!),
        ],
        if (outcome.signatures.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Signatures found', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in outcome.signatures)
                Chip(
                  avatar: const Icon(Icons.verified_user, size: 18),
                  label: Text(s),
                ),
            ],
          ),
        ],
        if (check.instances.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Each occurrence', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final m in check.instances) _InstanceTile(match: m),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => onStrip(outcome.cleaned),
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Remove watermarks'),
        ),
      ],
    );
  }
}

class _SealCard extends StatelessWidget {
  const _SealCard({required this.report});

  final VerificationReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final genuine = report.hasGenuineSeal;
    final intact = report.documentIntact;
    final mine = report.matchesExpectedAuthor ?? false;

    final occurrence = report.seals.firstWhere(
      (o) => o.seal.signatureValid,
      orElse: () => report.seals.first,
    );
    final seal = occurrence.seal;

    final bg = genuine ? scheme.primaryContainer : scheme.errorContainer;
    final fg = genuine ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(genuine ? Icons.verified_user : Icons.gpp_bad,
                  color: fg, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  genuine
                      ? 'Genuine cryptographic seal'
                      : 'Seal present but NOT genuine',
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          if (genuine) ...[
            _line(fg, Icons.person,
                mine ? 'Signed by you' : 'Signed by ${report.genuineAuthors.join(', ')}'),
            _line(fg, Icons.fingerprint, 'Key ${seal.publicKeyFingerprint}'),
            _line(fg, Icons.schedule, 'Sealed ${_formatDate(seal.timestamp)}'),
            _line(
                fg,
                intact ? Icons.check_circle : Icons.warning_amber,
                intact
                    ? 'Document intact — unchanged since sealing'
                    : 'Text has changed since it was sealed'),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'A seal was found but its signature does not check out — it was '
                'forged or corrupted.',
                style: TextStyle(color: fg),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(Color fg, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: fg))),
          ],
        ),
      );
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.found, required this.count});

  final bool found;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = found ? scheme.primary : scheme.outline;
    return Panel(
      child: Row(
        children: [
          Icon(found ? Icons.verified : Icons.search_off,
              size: 36, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  found ? 'Watermark found' : 'No watermark found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (found)
                  Text('$count occurrence${count == 1 ? '' : 's'} embedded.',
                      style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.match, required this.expected});

  final bool match;
  final String expected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = match ? scheme.primaryContainer : scheme.errorContainer;
    final fg = match ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(match ? Icons.check_circle : Icons.cancel, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              match
                  ? 'MATCH — "$expected" is present.'
                  : 'NO MATCH — "$expected" was not found.',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstanceTile extends StatelessWidget {
  const _InstanceTile({required this.match});

  final WatermarkMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Text('${match.line}',
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
        ),
        title: Text(match.signature ?? '(unreadable watermark)'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Line ${match.line}, column ${match.column}',
                style: theme.textTheme.bodySmall),
            if (match.context.isNotEmpty)
              Text('“${match.context}”',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ),
        isThreeLine: match.context.isNotEmpty,
      ),
    );
  }
}
