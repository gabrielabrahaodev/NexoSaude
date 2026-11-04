import 'dart:ui' show ImageFilter;
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
  Future<void> _run(Future<void> Function() operation) async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await operation();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() { _saving = false; _error = '$error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xff111720) : Colors.white;
    final card = dark ? const Color(0xff191f29) : const Color(0xfff1f5f8);
    final edge = dark ? const Color(0xff2a3444) : const Color(0xffcfdae4);
    final accent = dark ? const Color(0xff00dfa2) : const Color(0xff007558);
    final muted = dark ? const Color(0xffa1b0c5) : const Color(0xff516679);
    final danger = Theme.of(context).colorScheme.error;
    final pending = a.status.toLowerCase().contains('aguardando');
    final statusColor = pending ? (dark ? Colors.amber : Colors.brown) : accent;
    Widget tile(String title, String hint, IconData icon, VoidCallback? action, {Color? color, String? badge}) {
      final tint = color ?? accent;
      return Material(color: color == danger ? danger.withValues(alpha: .09) : card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9), side: BorderSide(color: color == danger ? danger.withValues(alpha: .45) : edge)),
        child: InkWell(onTap: _saving ? null : action, child: Padding(
          padding: const EdgeInsets.all(12), child: Row(children: [
            Icon(icon, size: 19, color: action == null ? muted : tint), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color == danger ? danger : null)),
              Text(hint, style: TextStyle(fontSize: 12, color: muted)),
            ])),
            if (badge != null) Text(badge, style: TextStyle(color: tint, fontSize: 11))
            else Icon(Icons.chevron_right, size: 16, color: muted),
          ]))));
    }
    final quick = [
      tile('Abrir Prontuário 360°', 'Histórico, exames e odontograma', Icons.person_outline, widget.onPatient),
      tile('Confirmar Presença (Check-in)', 'Paciente ligou ou está no balcão', Icons.thumb_up_outlined, () => _run(widget.onConfirm), badge: 'Balcão'),
      tile('Lembrete via WhatsApp', 'Disparar mensagem instantânea', Icons.chat_outlined, widget.onWhatsApp),
      tile('Editar Agendamento', 'Remanejar horário ou dentista', Icons.edit_outlined, widget.onEdit),
    ];
    void close() => Navigator.pop(context);
    return BackdropFilter(filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: Dialog(
      backgroundColor: bg, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: edge)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: SizedBox(width: 720, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(color: card, padding: const EdgeInsets.all(16), child: Row(children: [
          Container(width: 48, height: 48, alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: [Colors.blue, Colors.teal])),
            child: Text(a.patientName.isEmpty ? '?' : a.patientName.characters.first, style: const TextStyle(color: Colors.white, fontSize: 22))),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(a.patientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
                child: Text('● ${a.status}', style: TextStyle(fontSize: 12, color: statusColor))),
            ]),
            Text('${formatDateTimeFull(a.date)}   •   ${a.procedure}', style: TextStyle(color: accent)),
          ])), IconButton(tooltip: 'Fechar', onPressed: _saving ? null : close, icon: const Icon(Icons.close)),
        ])),
        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
            color: accent.withValues(alpha: .035), borderRadius: BorderRadius.circular(14), border: Border.all(color: accent.withValues(alpha: .65))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Icon(Icons.check_circle_outline, color: accent), const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Finalização de Consulta & Procedimentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Vincule as tags clínicas e registre o desfecho', style: TextStyle(fontSize: 12)),
                ])),
                if (MediaQuery.sizeOf(context).width > 550) Text('FLUXO CLÍNICO', style: TextStyle(color: accent, fontSize: 11)),
              ]),
              const SizedBox(height: 16),
              IgnorePointer(ignoring: _saving, child: PatientProcedureTags(patientId: a.patientId, selected: _tags, finishing: true, modal: true, onChanged: (v) => setState(() => _tags = v))),
              const SizedBox(height: 14), const Text('Observação Clínica / Resumo da Evolução (opcional):', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6), TextField(controller: _note, enabled: !_saving, minLines: 1, maxLines: 3, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Descreva a evolução deste atendimento…')),
              if (_error != null) Text(_error!, style: TextStyle(color: danger)), const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: dark ? Colors.black : Colors.white),
                onPressed: _saving ? null : () => _run(() => widget.onFinalize(_tags, _note.text.trim())),
                icon: const Icon(Icons.check), label: Text(_saving ? 'Salvando…' : 'Confirmar e Finalizar Atendimento'))),
            ])),
          const SizedBox(height: 20), Text('AÇÕES RÁPIDAS DE GESTÃO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: muted)),
          const SizedBox(height: 10), LayoutBuilder(builder: (_, c) {
            final width = c.maxWidth < 480 ? c.maxWidth : (c.maxWidth - 10) / 2;
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final item in quick) SizedBox(width: width, child: item)]);
          }),
          const SizedBox(height: 10), tile('Realizar Encaixe Clínico neste Horário', 'Adicionar outro paciente simultaneamente para atendimento', Icons.group_add_outlined, widget.onFit, badge: '+ Encaixar'),
          const SizedBox(height: 20), tile('Cancelar Agendamento', 'Liberar horário na grade e notificar recepção', Icons.cancel_outlined, widget.onCancel, color: danger, badge: 'Cancelar Slot'),
        ]))),
        const Divider(height: 1), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          Icon(Icons.circle, size: 9, color: accent), const SizedBox(width: 8),
          Expanded(child: Text('Consulta #${a.id}', maxLines: 1, overflow: TextOverflow.ellipsis)),
          PopupMenuButton<String>(tooltip: 'Outras ações', enabled: !_saving, onSelected: (_) => widget.onAbsence(),
            itemBuilder: (_) => [const PopupMenuItem(value: 'absence', child: Text('Registrar Falta / Atestado'))]),
          TextButton(onPressed: _saving ? null : close, child: const Text('Fechar')),
        ])),
      ])),
    ));
  }
}
