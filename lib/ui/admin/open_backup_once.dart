import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/canteen_book.dart';
import '../shared_widgets/motion.dart';
import 'backup_screen.dart';

/// Opens the backup screen once, right after a canteen was created "from a
/// backup", then gets out of the way.
class OpenBackupOnce extends ConsumerStatefulWidget {
  const OpenBackupOnce({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OpenBackupOnce> createState() => _OpenBackupOnceState();
}

class _OpenBackupOnceState extends ConsumerState<OpenBackupOnce> {
  @override
  void initState() {
    super.initState();
    if (!ref.read(startFromBackupProvider)) return;
    ref.read(startFromBackupProvider.notifier).set(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .push(tiffinRoute<void>(context, () => const BackupScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
