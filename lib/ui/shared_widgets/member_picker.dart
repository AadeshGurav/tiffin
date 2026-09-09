import 'package:flutter/material.dart';

import '../../domain/member.dart';
import '../theme/tokens.dart';
import 'frosted_panel.dart';
import 'nb_button.dart';
import 'nb_feedback.dart';
import 'nb_picker.dart';
import 'nb_text_field.dart';

/// Picking a member for a top-up or a refund. A blind [DropdownButton] is
/// unusable past a few dozen people; this filters as you type (name, class,
/// roll number, staff id) and offers a "+ New member" shortcut so a walk-up
/// member can be added without leaving the till (client's point 1).
typedef QuickCreateMember = Future<Member> Function(MemberDraft draft);

/// Tap-to-open field that shows the current [value] and opens [showMemberPicker].
class NbMemberField extends StatelessWidget {
  const NbMemberField({
    super.key,
    required this.label,
    required this.value,
    required this.members,
    required this.onSelected,
    this.onCreate,
    this.categories = const [],
  });

  final String label;
  final Member? value;
  final List<Member> members;
  final ValueChanged<Member> onSelected;

  /// Supplied by the screen (which holds the backend ref); null hides the
  /// "+ New member" shortcut.
  final QuickCreateMember? onCreate;

  /// Menu-category names for the walk-up member's category picker.
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NbSurfaceField(
      label: label,
      onTap: () async {
        final picked = await showMemberPicker(
          context: context,
          members: members,
          selected: value,
          onCreate: onCreate,
          categories: categories,
        );
        if (picked != null) onSelected(picked);
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? 'Tap to choose a member' : _describe(value!),
              style: t.text.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.search, size: 20, color: t.color.ink),
        ],
      ),
    );
  }
}

String _describe(Member m) => m.type == 'student'
    ? '${m.name} · ${m.className ?? '—'} ${m.rollNumber ?? ''}'.trim()
    : '${m.name} · ${m.staffId ?? 'staff'}';

bool _memberMatches(Member m, String q) {
  if (q.isEmpty) return true;
  final hay = [
    m.name,
    m.className ?? '',
    m.rollNumber ?? '',
    m.staffId ?? '',
    m.type,
  ].join(' ').toLowerCase();
  return hay.contains(q);
}

/// Modal search-and-pick over [members]. Bottom sheet so it lands in the thumb
/// zone and leaves room for the keyboard (CLAUDE.md §11.6.6). Returns null if
/// dismissed.
Future<Member?> showMemberPicker({
  required BuildContext context,
  required List<Member> members,
  Member? selected,
  QuickCreateMember? onCreate,
  List<String> categories = const [],
}) {
  final t = context.tokens;
  return showModalBottomSheet<Member>(
    context: context,
    isScrollControlled: true,
    backgroundColor: sheetBackground(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: t.shape.radius.topLeft),
      side: BorderSide(color: t.color.border, width: t.shape.borderBold),
    ),
    builder: (_) => FrostedPanel(
      child: _MemberPickerSheet(
          members: members,
          selected: selected,
          onCreate: onCreate,
          categories: categories),
    ),
  );
}

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({
    required this.members,
    required this.selected,
    required this.onCreate,
    required this.categories,
  });

  final List<Member> members;
  final Member? selected;
  final QuickCreateMember? onCreate;
  final List<String> categories;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final _query = TextEditingController();
  late final List<Member> _all = widget.members;
  late List<Member> _matches = widget.members;

  @override
  void initState() {
    super.initState();
    _query.addListener(_filter);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _query.text.trim().toLowerCase();
    setState(() => _matches = [
          for (final m in _all)
            if (_memberMatches(m, q)) m
        ]);
  }

  Future<void> _createNew() async {
    final draft = await _showQuickAddForm(context, widget.categories);
    if (draft == null || !mounted) return;
    Member? made;
    final ok = await runGuarded(
      context,
      () async => made = await widget.onCreate!(draft),
      successMessage: 'Member added.',
    );
    if (ok && made != null && mounted) {
      Navigator.of(context).pop(made);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NbSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Member', style: t.text.heading)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: NbSpace.sm),
                NbTextField(
                    label: 'Search', controller: _query, autofocus: true),
                if (widget.onCreate != null) ...[
                  const SizedBox(height: NbSpace.sm),
                  NbButton.secondary(
                    label: '+ New member',
                    onPressed: _createNew,
                  ),
                ],
                const SizedBox(height: NbSpace.sm),
                if (_matches.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        _all.isEmpty
                            ? 'No members yet.'
                            : 'Nothing matches "${_query.text}".',
                        style: t.text.body,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _matches.length,
                      itemExtent: 56,
                      itemBuilder: (_, i) {
                        final m = _matches[i];
                        final isSelected = m.id == widget.selected?.id;
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          title: Text(m.name, style: t.text.body),
                          subtitle: Text(_describe(m), style: t.text.label),
                          trailing: isSelected
                              ? Icon(Icons.check, color: t.color.accent)
                              : null,
                          onTap: () => Navigator.of(context).pop(m),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim create-only form for the walk-up case. The full member form —
/// editing, status, grace, delete — lives on the Members screen.
Future<MemberDraft?> _showQuickAddForm(
    BuildContext context, List<String> categories) {
  final t = context.tokens;
  var type = 'student';
  // Only offer a category picker once the admin has defined categories; a
  // walk-up member otherwise falls to the default 'Normal'.
  var category = categories.isEmpty ? 'Normal' : categories.first;
  final name = TextEditingController();
  final className = TextEditingController();
  final roll = TextEditingController();
  final staffId = TextEditingController();

  return showDialog<MemberDraft>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text('New member', style: t.text.heading),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'student', label: Text('Student')),
                  ButtonSegment(value: 'staff', label: Text('Staff')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setLocal(() => type = s.first),
              ),
              const SizedBox(height: NbSpace.md),
              NbTextField(label: 'Name', controller: name, autofocus: true),
              const SizedBox(height: NbSpace.md),
              if (type == 'student') ...[
                NbTextField(label: 'Class', controller: className),
                const SizedBox(height: NbSpace.md),
                NbTextField(label: 'Roll number', controller: roll),
              ] else
                NbTextField(label: 'Staff ID', controller: staffId),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: NbSpace.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('CATEGORY', style: t.text.label),
                ),
                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          NbButton(
            label: 'Create',
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                MemberDraft(
                  type: type,
                  name: name.text.trim(),
                  className: type == 'student' ? className.text.trim() : null,
                  rollNumber: type == 'student' ? roll.text.trim() : null,
                  staffId: type == 'staff' ? staffId.text.trim() : null,
                  category: category,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
