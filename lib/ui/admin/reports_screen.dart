import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../services/report_service.dart';
import '../shared_widgets/nb_button.dart';
import '../shared_widgets/nb_feedback.dart';
import '../shared_widgets/nb_surface.dart';
import '../theme/tokens.dart';

/// Settings ▸ Reports. Host-only: reads the whole database into an `.xlsx` for
/// people to read, print and pivot. Export-only on purpose — a round trip
/// through a spreadsheet loses types and ids and would be a way to corrupt
/// balances. Putting data *back* is [BackupScreen]'s job.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _sections = {...ReportSection.all};
  DateTimeRange? _range;
  bool _busy = false;

  /// Hands [bytes] to the OS share sheet — the one path that reaches email,
  /// Drive, WhatsApp and "Save to Files" without this app needing storage
  /// permissions of its own. Uses `printing` (already here for bills) rather
  /// than share_plus, which pulls package_info_plus and won't compile under
  /// this Flutter's Kotlin. sharePdf shares whatever bytes it's given.
  Future<void> _share(List<int> bytes, String name) async {
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: name,
      subject: 'Tiffin report',
    );
  }

  Future<void> _exportReport() async {
    setState(() => _busy = true);
    await runGuarded(context, () async {
      final container = await ref.read(hostContainerProvider.future);
      final bytes = await container.reports.build(
        start: _range?.start,
        end: _range?.end,
        sections: _sections,
      );
      await _share(bytes, container.reports.fileName());
    }, successMessage: 'Report ready.');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rangeLabel = _range == null
        ? 'Everything'
        : '${DateFormat('d MMM y').format(_range!.start)} – '
            '${DateFormat('d MMM y').format(_range!.end)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(NbSpace.lg),
        children: [
          NbSurface(
            tone: NbTone.money,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SPREADSHEET REPORT', style: t.text.label),
                const SizedBox(height: NbSpace.xs),
                Text(
                  'An .xlsx you can open in Excel or Google Sheets. For '
                  'reading and printing — it is not a way to put data back.',
                  style: t.text.body,
                ),
                const SizedBox(height: NbSpace.md),
                Row(
                  children: [
                    Expanded(child: Text(rangeLabel, style: t.text.body)),
                    TextButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('Dates'),
                      onPressed: _busy ? null : _pickRange,
                    ),
                    if (_range != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'All dates',
                        onPressed: () => setState(() => _range = null),
                      ),
                  ],
                ),
                const SizedBox(height: NbSpace.sm),
                Wrap(
                  spacing: NbSpace.sm,
                  children: [
                    for (final section in ReportSection.values)
                      FilterChip(
                        label: Text(section.label),
                        selected: _sections.contains(section),
                        onSelected: _busy
                            ? null
                            : (on) => setState(() => on
                                ? _sections.add(section)
                                : _sections.remove(section)),
                      ),
                  ],
                ),
                const SizedBox(height: NbSpace.md),
                NbButton(
                  label: 'Export spreadsheet',
                  icon: Icons.table_view,
                  busy: _busy,
                  onPressed: _busy ? null : _exportReport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
