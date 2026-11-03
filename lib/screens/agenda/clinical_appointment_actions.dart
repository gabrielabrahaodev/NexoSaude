import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../widgets/patient_procedure_tags.dart';
import '../../utils/display.dart' show formatDateTimeFull;

class ClinicalAppointmentActions extends StatefulWidget {
  const ClinicalAppointmentActions({super.key, required this.appointment, required this.onFinalize, required this.onPatient, required this.onConfirm, required this.onWhatsApp, required this.onEdit, required this.onFit, required this.onCancel, required this.onAbsence});
  final AppointmentModel appointment;
  final Future<void> Function(Map<String, bool>, String) onFinalize;
  final VoidCallback onPatient, onWhatsApp, onEdit, onCancel, onAbsence;
  final Future<void> Function() onConfirm;
  final VoidCallback? onFit;
  @override
  State<ClinicalAppointmentActions> createState() => _ClinicalAppointmentActionsState();
}
class _ClinicalAppointmentActionsState extends State<ClinicalAppointmentActions> {
  late Map<String, bool> _tags;
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void initState() { super.initState(); _tags = {for (final id in widget.appointment.procedureTagIds) id: false}; }
  @override
  void dispose() { _note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    Widget action(String label, IconData icon, VoidCallback? callback, {bool danger = false}) => OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), foregroundColor: danger ? Theme.of(context).colorScheme.error : null), onPressed: _saving ? null : callback, icon: Icon(icon, size: 19), label: Text(label));
    return Dialog(insetPadding: const EdgeInsets.all(16), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [CircleAvatar(child: Text(a.patientName.isEmpty ? '?' : a.patientName.characters.first)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.patientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), Text('${formatDateTimeFull(a.date)} • ${a.procedure}', style: Theme.of(context).textTheme.bodySmall), Text(a.status, style: TextStyle(color: Theme.of(context).colorScheme.primary))])), IconButton(tooltip: 'Fechar', onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      const Divider(height: 32),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Finalização de Consulta & Procedimentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const Text('Vincule as Tags clínicas e registre o desfecho'), const SizedBox(height: 16),
        IgnorePointer(ignoring: _saving, child: PatientProcedureTags(patientId: a.patientId, selected: _tags, finishing: true, onChanged: (v) => setState(() => _tags = v))),
        const SizedBox(height: 14), TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Observação Clínica / Resumo da Evolução (opcional)')),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 14),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : () async { setState(() { _saving = true; _error = null; }); try { await widget.onFinalize(_tags, _note.text.trim()); if (context.mounted) Navigator.pop(context); } catch (e) { if (mounted) setState(() { _saving = false; _error = '$e'; }); } }, icon: const Icon(Icons.check), label: Text(_saving ? 'Salvando…' : 'Confirmar e Finalizar Atendimento'))),
      ])),
      const SizedBox(height: 22), const Text('AÇÕES RÁPIDAS DE GESTÃO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [action('Abrir Prontuário 360°', Icons.person_outline, widget.onPatient), action('Confirmar Presença (Check-in)', Icons.thumb_up_outlined, () async { setState(() => _saving = true); try { await widget.onConfirm(); if (context.mounted) Navigator.pop(context); } catch (e) { if (mounted) setState(() { _saving = false; _error = '$e'; }); } }), action('Lembrete via WhatsApp', Icons.chat_outlined, widget.onWhatsApp), action('Editar Agendamento', Icons.edit_outlined, widget.onEdit), action('Realizar Encaixe Clínico neste Horário', Icons.group_add_outlined, widget.onFit), action('Registrar Falta / Atestado', Icons.event_busy, widget.onAbsence), action('Cancelar Agendamento', Icons.cancel_outlined, widget.onCancel, danger: true)]),
      const SizedBox(height: 18), Text('Desmarcar uma Tag apenas remove o vínculo desta consulta. Não exclui a Tag nem quita valores.', style: Theme.of(context).textTheme.bodySmall),
    ])))) ;
  }
}
