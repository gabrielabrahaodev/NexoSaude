import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClinicalBookingCalendar extends StatefulWidget {
  const ClinicalBookingCalendar({super.key, required this.selected, required this.onChanged});
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  @override
  State<ClinicalBookingCalendar> createState() => _ClinicalBookingCalendarState();
}
class _ClinicalBookingCalendarState extends State<ClinicalBookingCalendar> {
  late DateTime _month;
  @override
  void initState() { super.initState(); _month = DateTime(widget.selected.year, widget.selected.month); }
  @override
  Widget build(BuildContext context) {
    final first = _month.weekday % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final count = ((first + days + 6) ~/ 7) * 7;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(16)), child: Column(children: [
      Row(children: [Expanded(child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(_month), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))), IconButton(tooltip: 'Mês anterior', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)), IconButton(tooltip: 'Próximo mês', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right))]),
      Row(children: [for (final d in ['D','S','T','Q','Q','S','S']) Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(12), child: Text(d))))]), const Divider(),
      for (var row = 0; row < count ~/ 7; row++) Row(children: [for (var col = 0; col < 7; col++) Expanded(child: Builder(builder: (context) {
        final day = row * 7 + col - first + 1;
        if (day < 1 || day > days) return const SizedBox(height: 48);
        final selected = widget.selected.year == _month.year && widget.selected.month == _month.month && widget.selected.day == day;
        return TextButton(style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 48), backgroundColor: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, foregroundColor: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface), onPressed: () => widget.onChanged(DateTime(_month.year, _month.month, day)), child: Text('$day'));
      }))]),
    ]));
  }
}
