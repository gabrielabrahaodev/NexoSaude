import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/procedure_tags.dart';

class PatientProcedureTags extends StatefulWidget {
  const PatientProcedureTags({super.key, required this.patientId, required this.selected, required this.onChanged, this.finishing = false});
  final String patientId;
  final Map<String, bool> selected;
  final ValueChanged<Map<String, bool>> onChanged;
  final bool finishing;
  @override
  State<PatientProcedureTags> createState() => _PatientProcedureTagsState();
}
class _PatientProcedureTagsState extends State<PatientProcedureTags> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  @override
  void initState() { super.initState(); _stream = ProcedureTags.watch(widget.patientId); }
  @override
  void didUpdateWidget(covariant PatientProcedureTags old) { super.didUpdateWidget(old); if (old.patientId != widget.patientId) _stream = ProcedureTags.watch(widget.patientId); }
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _stream, builder: (context, snapshot) {
    if (snapshot.hasError) return const Text('Não foi possível carregar as Tags. Reabra a tela antes de gravar vínculos.');
    if (!snapshot.hasData) return const LinearProgressIndicator();
    final active = snapshot.data!.docs.where((d) => ['pending','in_progress'].contains(d.data()['status'])).toList();
    final unavailable = widget.selected.keys.where((id) => !active.any((d) => d.id == id)).toList();
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('♧ Tags de Procedimentos Vinculadas', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6),
      Text(widget.finishing ? 'Selecione as Tags atendidas e marque a conclusão de cada procedimento.' : 'Selecione até 8 Tags do plano do paciente para esta consulta.', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 12),
      if (active.isEmpty) const Text('Nenhuma Tag pendente. Aprove um orçamento ou execute a migração dos planos existentes.'),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final d in active) FilterChip(label: Text('${d.data()['name']} • item ${(d.data()['lineIndex'] as num? ?? 0).toInt() + 1} • orç. ${'${d.data()['budgetId'] ?? ''}'.length > 6 ? '${d.data()['budgetId']}'.substring('${d.data()['budgetId']}'.length - 6) : '${d.data()['budgetId'] ?? ''}'}', maxLines: 2, overflow: TextOverflow.ellipsis), selected: widget.selected.containsKey(d.id), onSelected: (v) { final next = Map<String, bool>.from(widget.selected); if (v) { if (next.length >= 8) return; next[d.id] = false; } else { next.remove(d.id); } widget.onChanged(next); })]),
      for (final id in unavailable) TextButton.icon(onPressed: () { final next = Map<String, bool>.from(widget.selected)..remove(id); widget.onChanged(next); }, icon: const Icon(Icons.link_off), label: const Text('Remover vínculo de Tag indisponível')),
      if (widget.finishing) ...[const SizedBox(height: 14), for (final d in active.where((d) => widget.selected.containsKey(d.id))) SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('${d.data()['name']}'), subtitle: Text(widget.selected[d.id] == true ? 'Concluído com sucesso' : 'Em andamento • necessita retorno'), value: widget.selected[d.id] == true, onChanged: (v) { widget.onChanged({...widget.selected, d.id: v}); })],
    ]));
  });
}
