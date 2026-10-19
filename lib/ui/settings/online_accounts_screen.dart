import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/role.dart';
import '../../data/access.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../shared_widgets/nb_text_field.dart';
import '../theme/tokens.dart';

/// Settings ▸ Online accounts. An optional second kind of account — email
/// and password through Firebase Auth — that works on any phone without
/// approving the phone first. Offline accounts are unaffected either way.
class OnlineAccountsScreen extends ConsumerWidget {
  const OnlineAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = AppText.of(context);
    final enabled = ref.watch(onlineAccountsEnabledProvider).asData?.value;
    final accounts = ref.watch(onlineAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(text.onlineAccountsTitle)),
      floatingActionButton: enabled == true
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt),
              label: Text(text.onlineAccountsAdd),
              onPressed: () => _add(context, ref),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            NbSpace.lg, NbSpace.lg, NbSpace.lg, NbSpace.xxl),
        children: [
          Text(text.onlineAccountsExplainer, style: t.text.body),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled ?? false,
            onChanged: enabled == null
                ? null
                : (on) async {
                    await runGuarded(
                        context,
                        () => ref
                            .read(backendProvider)
                            .setOnlineAccountsEnabled(on));
                    ref.invalidate(onlineAccountsEnabledProvider);
                  },
            title: Text(text.onlineAccountsToggle, style: t.text.label),
          ),
          const SizedBox(height: NbSpace.md),
          if (enabled == false)
            Text(text.onlineAccountsOff,
                style: t.text.body.copyWith(color: t.color.inkMuted)),
          AsyncView<List<OnlineAccount>>(
            value: accounts,
            builder: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.isEmpty)
                  Text(text.onlineAccountsEmpty, style: t.text.body),
                for (final a in list) ...[
                  _AccountRow(account: a),
                  const SizedBox(height: NbSpace.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<OnlineAccount>(
      context: context,
      builder: (_) => const _AddAccountDialog(),
    );
    if (created != null && context.mounted) {
      showNbSnack(
          context, AppText.of(context).onlineAccountsCreated(created.email));
    }
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.account});

  final OnlineAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = AppText.of(context);
    final access = ref.read(accessServiceProvider);
    return NbSurface(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.email, style: t.text.label),
                Text(
                  '${text.roleLabel(account.role)} · '
                  '${text.statusLabel(account.status)}',
                  style: t.text.body.copyWith(color: t.color.inkMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => runGuarded(
                context,
                () => access.setOnlineAccount(account.uid,
                    status: account.isActive ? 'inactive' : 'active')),
            child: Text(account.isActive
                ? text.onlineAccountsTurnOff
                : text.onlineAccountsTurnOn),
          ),
        ],
      ),
    );
  }
}

class _AddAccountDialog extends ConsumerStatefulWidget {
  const _AddAccountDialog();

  @override
  ConsumerState<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<_AddAccountDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  Role _role = Role.counter;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    OnlineAccount? created;
    final ok = await runGuarded(context, () async {
      created = await ref
          .read(accessServiceProvider)
          .createOnlineAccount(_email.text, _password.text, _role);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return AlertDialog(
      title: Text(text.onlineAccountsAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NbTextField(
              label: text.onlineEmailLabel,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: NbSpace.sm),
            NbTextField(label: text.onlinePasswordLabel, controller: _password),
            const SizedBox(height: NbSpace.sm),
            DropdownButtonFormField<Role>(
              initialValue: _role,
              decoration: InputDecoration(labelText: text.devicesRoleLabel),
              items: [
                for (final r in Role.values)
                  DropdownMenuItem(value: r, child: Text(text.roleLabel(r))),
              ],
              onChanged: (r) => setState(() => _role = r!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(text.settingsScreenCancelButton)),
        NbButton(
          label: text.onlineAccountsAdd,
          busy: _busy,
          onPressed: _busy ? null : _create,
        ),
      ],
    );
  }
}
