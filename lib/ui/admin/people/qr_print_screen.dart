import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/print_layout.dart';
import '../../../domain/member.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared_widgets/motion.dart';
import '../../shared_widgets/nb_button.dart';
import '../../shared_widgets/nb_feedback.dart';
import '../../shared_widgets/nb_text_field.dart';
import '../../shared_widgets/qr_card.dart';
import '../../theme/category_palette.dart';
import '../../theme/tokens.dart';
import 'qr_print_preview_screen.dart';
import 'qr_print_settings_form.dart';
import 'qr_print_settings_provider.dart';

/// What the print screen needs, fetched together so one spinner covers it.
typedef _PrintData = ({
  List<Member> members,
  Map<String, int?> categoryColors,
  String canteenName,
});

final _printDataProvider = FutureProvider.autoDispose<_PrintData>((ref) async {
  final backend = ref.watch(backendProvider);
  final members = await backend.listMembers(status: 'active');
  final categories = await backend.listMenuCategories();
  return (
    members: members,
    categoryColors: {for (final c in categories) c.name: c.color},
    canteenName: (await backend.getSettings()).appName,
  );
});

/// Bulk QR printing: choose members on one tab, set paper/card/spacing on the
/// other, then preview the PDF and send it to any printer or share it.
class QrPrintScreen extends ConsumerStatefulWidget {
  const QrPrintScreen({super.key});

  @override
  ConsumerState<QrPrintScreen> createState() => _QrPrintScreenState();
}

class _QrPrintScreenState extends ConsumerState<QrPrintScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  final _selected = <String>{};
  String _search = '';
  String? _category; // null = every category

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Member> _shown(List<Member> all) {
    final q = _search.trim().toLowerCase();
    return [
      for (final m in all)
        if ((_category == null || m.category == _category) &&
            (q.isEmpty ||
                [m.name, m.className, m.rollNumber, m.staffId]
                    .any((f) => f?.toLowerCase().contains(q) ?? false)))
          m,
    ];
  }

  void _preview(_PrintData data) {
    final text = AppText.of(context);
    final settings = ref.read(qrPrintSettingsProvider);
    if (_selected.isEmpty) {
      showNbSnack(context, text.qrPrintPickSomeone, ok: false);
      _tabs.animateTo(0);
      return;
    }
    if (!SheetPlan.from(settings).fits) {
      // The layout tab already says why; take the admin to it.
      _tabs.animateTo(1);
      return;
    }
    final cards = [
      for (final m in data.members)
        if (_selected.contains(m.id))
          qrCardFor(m,
              canteenName: data.canteenName,
              categoryColors: data.categoryColors),
    ];
    Navigator.of(context).push<void>(tiffinRoute<void>(
        context, () => QrPrintPreviewScreen(cards: cards, settings: settings)));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final data = ref.watch(_printDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.qrPrintTitle),
        bottom: TabBar(controller: _tabs, tabs: [
          Tab(text: text.qrPrintSectionMembers),
          Tab(text: text.qrPrintTabLayout),
        ]),
      ),
      body: AsyncView<_PrintData>(
        value: data,
        onRetry: () => ref.invalidate(_printDataProvider),
        loadingLabel: text.qrPrintLoadingMembers,
        builder: (d) => Column(
          children: [
            Expanded(
              child: TabBarView(controller: _tabs, children: [
                _membersTab(d),
                _layoutTab(),
              ]),
            ),
            _previewBar(d),
          ],
        ),
      ),
    );
  }

  Widget _membersTab(_PrintData d) {
    final t = context.tokens;
    final shown = _shown(d.members);
    final categories = {for (final m in d.members) m.category}.toList()..sort();
    // Lazily built: a canteen can have hundreds of members, and the filters
    // sit in the first item so they scroll away with the list.
    return ListView.builder(
      padding: const EdgeInsets.all(NbSpace.md),
      itemCount: shown.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _filters(shown, categories, shown.isEmpty);
        final m = shown[i - 1];
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _selected.contains(m.id),
          onChanged: (on) => setState(
              () => on! ? _selected.add(m.id) : _selected.remove(m.id)),
          title: Text(m.name, style: t.text.body),
          // The category name is the cue; the dot only echoes its card colour.
          subtitle: Row(children: [
            Icon(Icons.circle,
                size: 12, color: cardColorFor(d.categoryColors[m.category])),
            const SizedBox(width: NbSpace.xs),
            Flexible(child: Text(m.category, style: t.text.label)),
          ]),
        );
      },
    );
  }

  Widget _filters(List<Member> shown, List<String> categories, bool none) {
    final t = context.tokens;
    final text = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NbTextField(
          label: text.qrPrintSearchLabel,
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: NbSpace.md),
        DropdownButtonFormField<String?>(
          initialValue: _category,
          isExpanded: true,
          decoration:
              InputDecoration(labelText: text.qrPrintCategoryFilterLabel),
          items: [
            DropdownMenuItem(child: Text(text.qrPrintAllCategories)),
            for (final c in categories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: NbSpace.sm),
        Wrap(
          spacing: NbSpace.sm,
          children: [
            TextButton(
              onPressed: none
                  ? null
                  : () =>
                      setState(() => _selected.addAll(shown.map((m) => m.id))),
              child: Text(text.qrPrintSelectAllShown(shown.length)),
            ),
            TextButton(
              onPressed:
                  _selected.isEmpty ? null : () => setState(_selected.clear),
              child: Text(text.qrPrintClearSelection),
            ),
          ],
        ),
        if (none)
          Padding(
            padding: const EdgeInsets.all(NbSpace.lg),
            child: Text(text.qrPrintNoMatches, style: t.text.body),
          ),
      ],
    );
  }

  Widget _layoutTab() {
    final settings = ref.watch(qrPrintSettingsProvider);
    return ListView(
      padding: const EdgeInsets.all(NbSpace.md),
      children: [
        QrPrintSettingsForm(
          settings: settings,
          cardCount: _selected.length,
          onChanged: ref.read(qrPrintSettingsProvider.notifier).save,
        ),
      ],
    );
  }

  /// Pinned under both tabs so the primary action is always in thumb reach.
  Widget _previewBar(_PrintData d) {
    final t = context.tokens;
    final text = AppText.of(context);
    return Material(
      color: t.color.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(NbSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Text(text.qrPrintSelectedCount(_selected.length),
                    style: t.text.body),
              ),
              const SizedBox(width: NbSpace.md),
              NbButton(
                  label: text.qrPrintPreviewButton,
                  icon: Icons.print_outlined,
                  onPressed: () => _preview(d)),
            ],
          ),
        ),
      ),
    );
  }
}
