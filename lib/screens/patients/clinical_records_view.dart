import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/display.dart' show formatDateTimeFull;
import 'clinical_patient_view.dart';

/// Classification uses explicit recorded fields, never an inferred diagnosis.
bool recordIsCancellation(Map<String, dynamic> d) {
  final title = '${d['procedureName'] ?? ''}'.toLowerCase();
  return title.contains('cancelamento') || title == 'falta' || d['attendanceStatus'] == 'missed';
}
bool recordIsAdministrative(Map<String, dynamic> d) => '${d['procedureName'] ?? ''}'.toLowerCase().contains('cobrança') || d['type'] == 'administrative';
DateTime? recordDate(Map<String, dynamic> d) {
  final v = d['date'];
  return v is Timestamp ? v.toDate() : v is DateTime ? v : v is String ? DateTime.tryParse(v) : null;
}
class ClinicalRecordEntry {
  const ClinicalRecordEntry(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}
class ClinicalRecordsView extends StatefulWidget {
  const ClinicalRecordsView({super.key, required this.records, required this.onNew, required this.onEdit, required this.onDelete});
  final List<ClinicalRecordEntry> records;
  final VoidCallback onNew;
  final ValueChanged<String> onEdit, onDelete;
  @override
  State<ClinicalRecordsView> createState() => _ClinicalRecordsViewState();
}
class _ClinicalRecordsViewState extends State<ClinicalRecordsView> {
  String _filter = 'Todos';
  bool _newest = true;
  bool _matches(String filter, Map<String, dynamic> d) => switch (filter) {
    'Cancelamentos' => recordIsCancellation(d),
    'Evoluções' => !recordIsCancellation(d) && !recordIsAdministrative(d),
    'Procedimentos' => !recordIsCancellation(d) && !recordIsAdministrative(d) && '${d['treatmentId'] ?? ''}'.isNotEmpty,
    _ => true,
  };
  @override
  Widget build(BuildContext context) {
    final muted = PatientVisualStyle.textSecondary;
    final base = PatientVisualStyle.surface;
    final border = muted.withValues(alpha: .35);
    final rows = widget.records.where((e) => _matches(_filter, e.data)).toList()..sort((a, b) {
      final x = recordDate(a.data), y = recordDate(b.data);
      if (x == null) return y == null ? 0 : 1;
      if (y == null) return -1;
      return _newest ? y.compareTo(x) : x.compareTo(y);
    });
    Widget card(ClinicalRecordEntry entry) {
      final d = entry.data;
      final cancel = recordIsCancellation(d), admin = recordIsAdministrative(d);
      final color = cancel ? Theme.of(context).colorScheme.error : admin ? Theme.of(context).colorScheme.primary : PatientVisualStyle.accent;
      final date = recordDate(d);
      final operator = '${d['operatorName'] ?? d['dentistName'] ?? 'Não informado'}';
      final author = '${d['dentistName'] ?? d['professionalName'] ?? 'Não informado'}';
      final title = '${d['procedureName'] ?? 'Registro clínico'}';
      final description = '${d['description'] ?? ''}';
      // Legacy cancellation descriptions already include origin/reason/operator.
      // Keep the original text verbatim rather than manufacturing structured fields.
      return Container(margin: const EdgeInsets.only(bottom: 12), clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))), padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(cancel ? Icons.event_busy_outlined : admin ? Icons.receipt_long_outlined : Icons.note_alt_outlined, size: 18, color: color), const SizedBox(width: 8),
              Expanded(child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: .1), border: Border.all(color: color.withValues(alpha: .4)), borderRadius: BorderRadius.circular(8)), child: Text(cancel ? 'DESMARCAÇÃO / FALTA' : admin ? 'REGISTRO ADMINISTRATIVO' : 'EVOLUÇÃO CLÍNICA', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
              ])),
              IconButton(tooltip: 'Editar registro', visualDensity: VisualDensity.compact, onPressed: () => widget.onEdit(entry.id), icon: Icon(Icons.edit_outlined, size: 17, color: muted)),
              IconButton(tooltip: 'Excluir registro', visualDensity: VisualDensity.compact, onPressed: () => widget.onDelete(entry.id), icon: Icon(Icons.delete_outline, size: 17, color: muted)),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.calendar_today_outlined, size: 13, color: muted), Text(date == null ? 'Data não informada' : formatDateTimeFull(date), style: TextStyle(color: muted, fontSize: 12)), Text('• ${cancel || admin ? 'Operador do registro: $operator' : 'Profissional do registro: $author'}', style: TextStyle(color: cancel || admin ? muted : color, fontSize: 12))]),
            const SizedBox(height: 22),
            if (!cancel && !admin) ...[Text('CONDUTA & DIAGNÓSTICO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted)), const SizedBox(height: 6)],
            SelectableText(description.isEmpty ? 'Descrição não informada.' : description, style: const TextStyle(fontSize: 13, height: 1.6)),
            if (cancel) ...[const SizedBox(height: 12), Text('Registrado no prontuário por: $operator', style: TextStyle(color: muted, fontSize: 12))],
            if ('${d['treatmentId'] ?? ''}'.isNotEmpty && !cancel && !admin) ...[const SizedBox(height: 14), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: .08), border: Border.all(color: color.withValues(alpha: .25)), borderRadius: BorderRadius.circular(8)), child: Text('Procedimento: $title', style: TextStyle(color: color, fontSize: 12)))],
          ]),
        ),
      );
    }
    return Column(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: base, border: Border.all(color: border), borderRadius: BorderRadius.circular(14)), child: Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        IconButton(tooltip: _newest ? 'Mais antigos primeiro' : 'Mais recentes primeiro', onPressed: () => setState(() => _newest = !_newest), icon: Icon(_newest ? Icons.sort : Icons.swap_vert, size: 18)),
        for (final filter in ['Todos', 'Evoluções', 'Cancelamentos', 'Procedimentos']) TextButton(onPressed: () => setState(() => _filter = filter), style: TextButton.styleFrom(foregroundColor: _filter == filter ? PatientVisualStyle.textPrimary : muted, backgroundColor: _filter == filter ? muted.withValues(alpha: .15) : Colors.transparent), child: Text('$filter  ${widget.records.where((e) => _matches(filter, e.data)).length}', style: const TextStyle(fontSize: 12))),
        TextButton.icon(onPressed: widget.onNew, icon: const Icon(Icons.add_circle_outline, size: 17), label: const Text('Novo Registro Clínico / Evolução', style: TextStyle(fontSize: 12))),
      ])), const SizedBox(height: 14),
      Expanded(child: rows.isEmpty ? const Center(child: Text('Nenhum registro neste filtro.')) : ListView.builder(padding: const EdgeInsets.only(bottom: 24), itemCount: rows.length, itemBuilder: (_, i) => card(rows[i]))),
    ]);
  }
}
