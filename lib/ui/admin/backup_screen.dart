import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../services/backup_service.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';

/// Settings ▸ Backup & restore. Host-only. The `.tiffin` file is a complete,
/// optionally-encrypted copy of the canteen — the supported way to move to a
/// new phone or recover a lost one. Restore replaces everything and keeps the
/// current data beside it.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _passphrase = TextEditingController();
  bool _protect = true;
  bool _busy = false;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _share(List<int> bytes, String name) async {
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: name,
      subject: 'Tiffin backup',
    );
  }

  Future<void> _exportBackup() async {
    if (_protect && _passphrase.text.length < 4) {
      showNbSnack(context, 'Choose a password, or turn protection off.',
          ok: false);
      return;
    }
    setState(() => _busy = true);
    await runGuarded(context, () async {
      final container = await ref.read(hostContainerProvider.future);
      final bytes = await container.backups
          .export(passphrase: _protect ? _passphrase.text : null);
      await _share(bytes, container.backups.fileName());
    }, successMessage: 'Backup ready. Keep it somewhere safe.');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFile();
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final container = await ref.read(hostContainerProvider.future);
    if (!mounted) return;

    // Read the manifest before asking for anything: it tells the admin what
    // they are about to overwrite their canteen with.
    final BackupManifest manifest;
    try {
      manifest = container.backups.inspect(bytes);
    } on AppException catch (e) {
      if (mounted) showNbSnack(context, e.message, ok: false);
      return;
    }

    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => _RestoreConfirmDialog(manifest: manifest),
    );
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    await runGuarded(context, () async {
      await ref.read(hostServingProvider.notifier).restoreFromBackup(
            bytes,
            passphrase: passphrase.isEmpty ? null : passphrase,
          );
    }, successMessage: 'Restored. Sign in again to continue.');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          NbSurface(
            tone: NbTone.system,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BACKUP', style: t.text.label),
                const SizedBox(height: NbSpace.xs),
                Text(
                  'A complete copy of this canteen — members, balances, '
                  'history, settings and accounts. Use it to move to a new '
                  'phone, or to recover from one that is lost.',
                  style: t.text.body,
                ),
                const SizedBox(height: NbSpace.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _protect,
                  onChanged: _busy ? null : (v) => setState(() => _protect = v),
                  title: Text('Protect with a password', style: t.text.body),
                  subtitle: Text(
                    _protect
                        ? 'Nobody can open the file without it — including '
                            'you, so write it down.'
                        : 'The file will hold member names and account '
                            'details in the clear.',
                    style: t.text.body.copyWith(color: t.color.inkMuted),
                  ),
                ),
                if (_protect) ...[
                  const SizedBox(height: NbSpace.sm),
                  NbTextField(
                      label: 'Backup password', controller: _passphrase),
                ],
                const SizedBox(height: NbSpace.md),
                NbButton(
                  label: 'Export backup',
                  icon: Icons.save_alt,
                  busy: _busy,
                  onPressed: _busy ? null : _exportBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: NbSpace.lg),
          NbSurface(
            tone: NbTone.system,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESTORE', style: t.text.label),
                const SizedBox(height: NbSpace.xs),
                Text(
                  'Replaces everything on this device with the contents of a '
                  'backup file. The current data is kept beside it as a copy.',
                  style: t.text.body,
                ),
                const SizedBox(height: NbSpace.md),
                NbButton.secondary(
                  label: 'Restore from a backup',
                  icon: Icons.restore,
                  busy: _busy,
                  onPressed: _busy ? null : _restore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Typed confirmation before a restore, showing what the file actually holds.
class _RestoreConfirmDialog extends StatefulWidget {
  const _RestoreConfirmDialog({required this.manifest});

  final BackupManifest manifest;

  @override
  State<_RestoreConfirmDialog> createState() => _RestoreConfirmDialogState();
}

class _RestoreConfirmDialogState extends State<_RestoreConfirmDialog> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = widget.manifest;
    final armed = _confirm.text.trim().toUpperCase() == 'REPLACE' &&
        (!m.encrypted || _passphrase.text.isNotEmpty);

    return AlertDialog(
      title: Text('Replace everything?', style: t.text.heading),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This backup was made on '
              '${DateFormat('d MMM y, HH:mm').format(m.createdAt.toLocal())} '
              'by Tiffin ${m.appVersion}, and holds ${m.totalRows} rows '
              '(${m.rowCounts['members'] ?? 0} members).',
              style: t.text.body,
            ),
            const SizedBox(height: NbSpace.sm),
            Text(
              'Everything currently on this device will be replaced. A copy '
              'of the current data is kept next to it.',
              style: t.text.body.copyWith(color: t.color.reject),
            ),
            if (m.encrypted) ...[
              const SizedBox(height: NbSpace.md),
              NbTextField(
                label: 'Backup password',
                controller: _passphrase,
                obscure: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: NbSpace.md),
            NbTextField(
              label: 'Type REPLACE to confirm',
              controller: _confirm,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        NbButton(
          label: 'Restore',
          background: t.color.reject,
          onPressed:
              armed ? () => Navigator.pop(context, _passphrase.text) : null,
        ),
      ],
    );
  }
}
