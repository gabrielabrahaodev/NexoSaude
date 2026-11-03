import 'package:flutter/material.dart';
import '../../models/procedure_model.dart';
import '../../utils/report_export.dart' show reportMoney;
import 'clinical_operations_style.dart';

/// Local filters never change the catalog or the financial rules.
class ClinicalProceduresView extends StatefulWidget {
  const ClinicalProceduresView({super.key, required this.items, required this.onNew, required this.onEdit, required this.onDelete});
  final List<ProcedureModel> items;
  final VoidCallback onNew;
  final ValueChanged<ProcedureModel> onEdit, onDelete;
  @override
  State<ClinicalProceduresView> createState() => _ClinicalProceduresViewState();
}
class _ClinicalProceduresViewState extends State<ClinicalProceduresView> {
  String _search = '';
  String? _category;
  @override
  Widget build(BuildContext context) {
    final s = ClinicalOperationsStyle.panel(context);
    final muted = ClinicalOperationsStyle.muted(context);
    final accent = ClinicalOperationsStyle.teal(context);
    final categories = widget.items.map((i) => i.category).toSet().toList()..sort();
    final category = categories.contains(_category) ? _category : null;
    final items = widget.items.where((i) {
      final text = '${i.name} ${i.category} ${i.formattedCommission} ${i.hasCost ? 'gera custo' : ''} ${i.generatesMonthlyFee ? 'mensalidade' : ''}'.toLowerCase();
      return (category == null || i.category == category) && text.contains(_search.toLowerCase().trim());
    }).toList();
    Widget badge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)));
    Widget card(ProcedureModel item) {
      final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), if (item.hasCost) badge('Gera Custo', Theme.of(context).brightness == Brightness.dark ? const Color(0xffffd86a) : const Color(0xff825e00)), if (item.generatesMonthlyFee) badge('Mensalidade', Theme.of(context).colorScheme.primary), if (!item.active) badge('Inativo', muted)]),
        const SizedBox(height: 5), Text('${item.category} • Repasse: ${item.commissionValue == 0 ? 'Sem repasse cadastrado' : item.formattedCommission}', style: TextStyle(color: item.commissionValue == 0 ? muted : accent, fontSize: 14)),
      ]);
      final actions = Row(mainAxisSize: MainAxisSize.min, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Valor padrão', style: TextStyle(color: muted, fontSize: 12)), Text(reportMoney(item.price), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700))]),
        const SizedBox(width: 20), IconButton.filledTonal(tooltip: 'Editar ${item.name}', onPressed: () => widget.onEdit(item), icon: const Icon(Icons.edit_outlined)),
        const SizedBox(width: 6), IconButton(tooltip: 'Excluir ${item.name}', style: IconButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: .12), foregroundColor: Theme.of(context).colorScheme.error), onPressed: () => widget.onDelete(item), icon: const Icon(Icons.delete_outline)),
      ]);
      return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: s, borderRadius: BorderRadius.circular(24)), child: LayoutBuilder(builder: (context, size) {
        final avatar = Container(width: 56, height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: (item.commissionValue > 0 ? accent : Theme.of(context).colorScheme.primary).withValues(alpha: .15), borderRadius: BorderRadius.circular(16)), child: Text(item.name.isEmpty ? '?' : item.name.characters.first.toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: accent)));
        final description = Row(children: [avatar, const SizedBox(width: 20), Expanded(child: details)]);
        return size.maxWidth < 800 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [description, const SizedBox(height: 16), Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: actions))]) : Row(children: [Expanded(child: description), const SizedBox(width: 20), actions]);
      }));
    }
    return Scaffold(backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(tooltip: 'Novo Procedimento', backgroundColor: ClinicalOperationsStyle.accent, foregroundColor: const Color(0xff00382c), onPressed: widget.onNew, child: const Icon(Icons.add, size: 32)),
      body: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: s, borderRadius: BorderRadius.circular(24)), child: LayoutBuilder(builder: (context, size) {
          final search = TextField(onChanged: (v) => setState(() => _search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar procedimento clínico, repasse ou tag'));
          final filter = DropdownButtonFormField<String>(value: category ?? '', isExpanded: true, decoration: const InputDecoration(border: InputBorder.none), items: [const DropdownMenuItem(value: '', child: Text('Todas as Especialidades')), ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))], onChanged: (v) => setState(() => _category = v == '' ? null : v));
          final add = FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xffadc6ff), foregroundColor: const Color(0xff002e6a), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22)), onPressed: widget.onNew, icon: const Icon(Icons.add), label: const Text('Novo Procedimento'));
          return size.maxWidth < 850 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 12), filter, const SizedBox(height: 12), add]) : Row(children: [Expanded(flex: 3, child: search), const SizedBox(width: 12), Expanded(flex: 2, child: filter), const SizedBox(width: 24), add]);
        })), const SizedBox(height: 20),
        if (items.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Text(widget.items.isEmpty ? 'Nenhum procedimento cadastrado' : 'Nenhum procedimento encontrado', textAlign: TextAlign.center)),
        for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: card(item)),
      ]));
  }
}
