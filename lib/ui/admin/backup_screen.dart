import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../l10n/messages.dart';
import '../../services/backup_service.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Settings ▸ Backup & restore. Admin only. The `.tiffin` file is a complete,
/// optionally-encrypted copy of the canteen — a copy the admin owns outside
/// Firebase, and the way to move to a new Firebase project. Restore replaces
/// everything, and reads the whole file before deleting anything.
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
      subject: AppText.of(context).backupScreenShareSubject,
    );
  }

  Future<void> _exportBackup() async {
    if (_protect && _passphrase.text.length < 4) {
      showNbSnack(context, AppText.of(context).backupScreenPasswordRequired,
          ok: false);
      return;
    }
    setState(() => _busy = true);
    await runGuarded(context, () async {
      final backups = ref.read(backendProvider).backups;
      final bytes =
          await backups.export(passphrase: _protect ? _passphrase.text : null);
      await _share(bytes, backups.fileName());
    }, successMessage: AppText.of(context).backupScreenExportSuccess);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFile();
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final backups = ref.read(backendProvider).backups;

    // Read the manifest before asking for anything: it tells the admin what
    // they are about to overwrite their canteen with.
    final BackupManifest manifest;
    try {
      manifest = backups.inspect(bytes);
    } on AppException catch (e) {
      if (mounted) {
        showNbSnack(context, AppText.of(context).errorText(e), ok: false);
      }
      return;
    }

    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => _RestoreConfirmDialog(manifest: manifest),
    );
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    await runGuarded(context, () async {
      final contents = await backups.read(bytes,
          passphrase: passphrase.isEmpty ? null : passphrase);
      await backups.restore(contents);
      ref.invalidate(setupRequiredProvider);
    }, successMessage: AppText.of(context).backupScreenRestoreSuccess);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(AppText.of(context).backupScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          NbSurface(
            tone: NbTone.system,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppText.of(context).backupScreenSectionBackup,
                    style: t.text.label),
                const SizedBox(height: NbSpace.xs),
                Text(
                  AppText.of(context).backupScreenBackupDescription,
                  style: t.text.body,
                ),
                const SizedBox(height: NbSpace.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _protect,
                  onChanged: _busy ? null : (v) => setState(() => _protect = v),
                  title: Text(AppText.of(context).backupScreenProtectToggle,
                      style: t.text.body),
                  subtitle: Text(
                    _protect
                        ? AppText.of(context).backupScreenProtectOnHint
                        : AppText.of(context).backupScreenProtectOffHint,
                    style: t.text.body.copyWith(color: t.color.inkMuted),
                  ),
                ),
                if (_protect) ...[
                  const SizedBox(height: NbSpace.sm),
                  NbTextField(
                      label: AppText.of(context).backupScreenPasswordLabel,
                      controller: _passphrase),
                ],
                const SizedBox(height: NbSpace.md),
                NbButton(
                  label: AppText.of(context).backupScreenExportButton,
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
                Text(AppText.of(context).backupScreenSectionRestore,
                    style: t.text.label),
                const SizedBox(height: NbSpace.xs),
                Text(
                  AppText.of(context).backupScreenRestoreDescription,
                  style: t.text.body,
                ),
                const SizedBox(height: NbSpace.md),
                NbButton.secondary(
                  label: AppText.of(context).backupScreenRestoreButton,
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
    final text = AppText.of(context);
    final armed =
        confirmWordMatches(_confirm.text, text.confirmWordReplace, 'REPLACE') &&
            (!m.encrypted || _passphrase.text.isNotEmpty);

    return AlertDialog(
      title: Text(AppText.of(context).backupScreenRestoreDialogTitle,
          style: t.text.heading),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppText.of(context).backupScreenRestoreManifestSummary(
                DateFormat.yMMMd().add_Hm().format(m.createdAt.toLocal()),
                m.appVersion,
                m.totalRows,
                m.rowCounts['members'] ?? 0,
              ),
              style: t.text.body,
            ),
            const SizedBox(height: NbSpace.sm),
            Text(
              AppText.of(context).backupScreenReplaceWarning,
              style: t.text.body.copyWith(color: t.color.reject),
            ),
            if (m.encrypted) ...[
              const SizedBox(height: NbSpace.md),
              NbTextField(
                label: AppText.of(context).backupScreenPasswordLabel,
                controller: _passphrase,
                obscure: true,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: NbSpace.md),
            NbTextField(
              label: AppText.of(context).backupScreenTypeReplaceLabel,
              controller: _confirm,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppText.of(context).backupScreenCancelButton),
        ),
        NbButton(
          label: AppText.of(context).backupScreenRestoreConfirmButton,
          background: t.color.reject,
          onPressed:
              armed ? () => Navigator.pop(context, _passphrase.text) : null,
        ),
      ],
    );
  }
}

/// First-run "bring over existing records": pick a `.tiffin` file (either
/// format), ask for its password if it has one, and write it into this empty
/// canteen. True when something was imported.
Future<bool> showImportDialog(BuildContext context) async {
  final text = AppText.of(context);
  final backups =
      ProviderScope.containerOf(context).read(backendProvider).backups;
  // Say where the file comes from before opening a file picker on someone.
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.importTitle),
      content: Text(text.importBody),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.backupScreenCancelButton)),
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.importPickButton)),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;
  final picked = await FilePicker.pickFile();
  if (picked == null || !context.mounted) return false;
  final bytes = await picked.readAsBytes();
  if (!context.mounted) return false;

  final BackupManifest manifest;
  try {
    manifest = backups.inspect(bytes);
  } on AppException catch (e) {
    if (context.mounted) showNbSnack(context, text.errorText(e), ok: false);
    return false;
  }
  String? passphrase;
  if (manifest.encrypted) {
    final field = TextEditingController();
    passphrase = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.importTitle),
        content: NbTextField(
            label: text.importPassphraseLabel,
            controller: field,
            obscure: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(text.backupScreenCancelButton)),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, field.text),
              child: Text(text.importPickButton)),
        ],
      ),
    );
    field.dispose();
    if (passphrase == null || !context.mounted) return false;
  }

  var count = 0;
  final ok = await runGuarded(context, () async {
    final contents = await backups.read(bytes, passphrase: passphrase);
    count = await backups.restore(contents, requireEmpty: true);
  });
  if (ok && context.mounted) showNbSnack(context, text.importDone(count));
  return ok;
}
