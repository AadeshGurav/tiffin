import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'nb_text_field.dart';

/// The units a canteen actually buys in. "Custom…" covers everything else so
/// the list stays short (Hick's Law) without boxing anyone in.
const kCommonUnits = <String>[
  'kg',
  'g',
  'litre',
  'ml',
  'pcs',
  'packet',
  'dozen',
  'bunch',
  'bottle',
  'can',
  'box',
];

/// Pick an ingredient's unit from a short list, or type your own. Replaces a
/// bare text field so "kg" / "Kg" / "kilo" don't fragment into three units.
class NbUnitField extends StatefulWidget {
  const NbUnitField(
      {super.key, required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<NbUnitField> createState() => _NbUnitFieldState();
}

class _NbUnitFieldState extends State<NbUnitField> {
  static const _customSentinel = '__custom__';

  late String _selection = kCommonUnits.contains(widget.initial)
      ? widget.initial
      : (widget.initial.isEmpty ? kCommonUnits.first : _customSentinel);
  late final _custom = TextEditingController(
      text: kCommonUnits.contains(widget.initial) ? '' : widget.initial);

  @override
  void initState() {
    super.initState();
    // Report the resolved starting value so a caller that just opened the form
    // and didn't touch the field still gets a real unit on save.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
        _selection == _customSentinel ? _custom.text.trim() : _selection);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UNIT', style: t.text.label),
        const SizedBox(height: NbSpace.xs),
        DropdownButton<String>(
          value: _selection,
          isExpanded: true,
          items: [
            for (final u in kCommonUnits)
              DropdownMenuItem(value: u, child: Text(u)),
            const DropdownMenuItem(
                value: _customSentinel, child: Text('Custom…')),
          ],
          onChanged: (v) => setState(() {
            _selection = v ?? _selection;
            _emit();
          }),
        ),
        if (_selection == _customSentinel) ...[
          const SizedBox(height: NbSpace.xs),
          NbTextField(
            label: 'Custom unit',
            controller: _custom,
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}
