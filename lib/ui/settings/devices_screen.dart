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
import '../theme/tokens.dart';

/// Settings ▸ Devices. Every phone that asked to join, waiting ones first.
/// Approving a phone gives it a role, and that role is what Firestore rules
/// enforce — it caps who can sign in on it.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = AppText.of(context);
    final devices = ref.watch(devicesProvider);
    final me = ref.watch(accessServiceProvider).user?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(text.devicesTitle)),
      body: AsyncView<List<Device>>(
        value: devices,
        builder: (list) {
          final ordered = [
            ...list.where((d) => d.status == 'pending'),
            ...list.where((d) => d.status == 'approved'),
          ];
          return ListView(
            padding: const EdgeInsets.all(NbSpace.lg),
            children: [
              Text(text.devicesRoleExplainer,
                  style: t.text.body.copyWith(color: t.color.inkMuted)),
              const SizedBox(height: NbSpace.md),
              if (ordered.length <= 1)
                Text(text.devicesEmpty, style: t.text.body),
              for (final d in ordered) ...[
                _DeviceCard(device: d, isMe: d.uid == me),
                const SizedBox(height: NbSpace.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.device, required this.isMe});

  final Device device;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = AppText.of(context);
    final access = ref.read(accessServiceProvider);
    final by = ref.read(sessionProvider)?.username ?? '';
    final pending = device.status == 'pending';

    return NbSurface(
      background: pending ? t.color.warn : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(device.name, style: t.text.heading),
          Text(
            [
              if (isMe) text.devicesThisPhone,
              if (pending) text.devicesPending,
              device.code,
            ].join('   '),
            style: t.text.label,
          ),
          const SizedBox(height: NbSpace.sm),
          DropdownButtonFormField<Role>(
            initialValue: device.role,
            decoration: InputDecoration(labelText: text.devicesRoleLabel),
            items: [
              for (final r in Role.values)
                DropdownMenuItem(value: r, child: Text(text.roleLabel(r))),
            ],
            // Your own phone's role is fixed here: demoting it would lock you
            // out of this very screen.
            onChanged: isMe || pending
                ? null
                : (r) =>
                    runGuarded(context, () => access.setRole(device.uid, r!)),
          ),
          const SizedBox(height: NbSpace.sm),
          if (pending)
            NbButton(
              label: text.devicesApproveButton,
              icon: Icons.check,
              onPressed: () => _approve(context, access, by),
            ),
          if (!isMe)
            TextButton.icon(
              icon: const Icon(Icons.phonelink_erase),
              label: Text(text.devicesRemoveButton),
              style: TextButton.styleFrom(foregroundColor: t.color.reject),
              onPressed: () => _remove(context, access),
            ),
        ],
      ),
    );
  }

  /// Asks which role first: approval without a deliberate role choice is how
  /// a phone at the gate ends up able to issue refunds.
  Future<void> _approve(
      BuildContext context, AccessService access, String by) async {
    final text = AppText.of(context);
    final role = await showDialog<Role>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(text.devicesRoleLabel),
        children: [
          for (final r in Role.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: NbSpace.sm),
                child: Text(text.roleLabel(r)),
              ),
            ),
        ],
      ),
    );
    if (role == null || !context.mounted) return;
    await runGuarded(context, () => access.approve(device.uid, role, by: by));
  }

  Future<void> _remove(BuildContext context, AccessService access) async {
    final text = AppText.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(text.devicesRemoveConfirm(device.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(text.settingsScreenCancelButton)),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(text.devicesRemoveButton)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runGuarded(context, () => access.remove(device.uid));
    }
  }
}
