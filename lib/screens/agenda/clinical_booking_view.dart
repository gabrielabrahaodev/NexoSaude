import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/report_export.dart' show reportMoney;
import '../../widgets/clinical_booking_calendar.dart';

/// Presentation only. Availability, patient identity and persistence stay in
/// AgendaFormScreen. Ordinary desktop content fits a 1080p viewport.
class ClinicalBookingView extends StatelessWidget {
  const ClinicalBookingView({super.key, required this.title, required this.clinic,
    required this.patientField, required this.procedureField, required this.tags,
    required this.notesController, required this.selectedDate, required this.times,
    required this.selectedTimes, required this.occupiedTimes, required this.onDate,
    required this.onTime, required this.onFitIn, required this.onCancel,
    required this.onProcedure, this.onNewPatient, this.onChangePatient,
    this.onSave, this.professional, this.patientSummary, this.recordNumber,
    this.procedureCategory, this.procedurePrice, this.risk, this.error,
    this.fitInTimes = const [], this.loading = false, this.saving = false, this.fitIn = false});
  final String title, clinic;
  final String? professional, patientSummary, recordNumber, procedureCategory, error;
  final double? procedurePrice;
  final Widget patientField, procedureField, tags;
  final Widget? risk;
  final TextEditingController notesController;
  final DateTime selectedDate;
  final List<String> times, selectedTimes, occupiedTimes, fitInTimes;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<String> onTime;
  final ValueChanged<bool> onFitIn;
  final VoidCallback onCancel, onProcedure;
  final VoidCallback? onSave, onNewPatient, onChangePatient;
  final bool loading, saving, fitIn;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xff0a0f14) : const Color(0xfff4f7fa);
    final panel = dark ? const Color(0xff10151c) : Colors.white;
    final border = dark ? const Color(0xff26313e) : const Color(0xffd7e0ea);
    final muted = dark ? const Color(0xff99a9bc) : const Color(0xff53667d);
    final accent = dark ? const Color(0xff00d8a0) : const Color(0xff007e69);
    final onAccent = dark ? const Color(0xff00291f) : Colors.white;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width >= 1000;
    final tight = compact && MediaQuery.sizeOf(context).height < 1040;
    final gap = compact ? (tight ? 8.0 : 10.0) : 18.0;
    final sorted = selectedTimes.toList()..sort();
    final summary = '${DateFormat('dd/MM/yyyy').format(selectedDate)}${sorted.isEmpty ? '' : ' às ${sorted.first}'}${professional == null ? '' : ' • $professional'}';
    Widget box(Widget child, {double padding = 12}) => Container(padding: EdgeInsets.all(padding), decoration: BoxDecoration(color: panel, border: Border.all(color: border), borderRadius: BorderRadius.circular(14)), child: child);
    Widget heading(int n, String label, {String? detail}) => Padding(padding: EdgeInsets.only(bottom: tight ? 4 : 6), child: Row(children: [Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: border, shape: BoxShape.circle), child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))), if (detail != null && width > 1000) Text(detail, style: TextStyle(color: muted, fontSize: 11))]));
    Widget identity(IconData icon, String label) => box(Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: accent, size: 16), const SizedBox(width: 8), Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))]), padding: 8);
    final header = Container(padding: EdgeInsets.symmetric(horizontal: compact ? 28 : 12, vertical: compact ? (tight ? 6 : 8) : 12), decoration: BoxDecoration(color: panel, border: Border(bottom: BorderSide(color: border))), child: Row(children: [IconButton(tooltip: 'Voltar', onPressed: saving ? null : onCancel, icon: const Icon(Icons.arrow_back)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(title, style: TextStyle(fontSize: compact ? 22 : 18, fontWeight: FontWeight.w800)), Text('Odontologia', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12))]), if (width >= 700) Text('Clínica NexoSaúde  •  Agenda Clínica  •  Fluxo de Consulta', style: TextStyle(color: muted, fontSize: 12))])), if (width >= 900) ...[SizedBox(width: 210, child: identity(Icons.apartment_outlined, 'Unidade: $clinic')), const SizedBox(width: 12), SizedBox(width: 240, child: identity(Icons.person_outline, professional ?? 'Profissional selecionado'))]]));
    final save = FilledButton.icon(key: const ValueKey('booking-confirm'), style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: onAccent, minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: saving ? null : onSave, icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check, size: 18), label: Text(saving ? 'Salvando…' : 'Confirmar Agendamento'));
    final footer = Container(key: const ValueKey('booking-footer'), padding: EdgeInsets.symmetric(horizontal: 24, vertical: tight ? 8 : 10), decoration: BoxDecoration(color: panel, border: Border(top: BorderSide(color: border))), child: SafeArea(top: false, child: width >= 700 ? Row(children: [Icon(Icons.circle, color: accent, size: 9), const SizedBox(width: 10), Expanded(child: Text('Resumo: $summary', style: TextStyle(color: muted, fontSize: 13))), TextButton(onPressed: saving ? null : onCancel, child: const Text('Cancelar')), const SizedBox(width: 12), save]) : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(summary, maxLines: 2, style: TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 6), save])));
    final occupiedColor = dark ? const Color(0xffff8798) : const Color(0xffb32742);
    final slots = Wrap(spacing: compact ? 7 : 8, runSpacing: 6, children: [for (final time in times) Builder(builder: (context) {
      final busy = occupiedTimes.contains(time);
      final fitAvailable = !busy && fitInTimes.contains(time);
      final selected = !busy && selectedTimes.contains(time);
      return Tooltip(message: busy ? '$time — Ocupado: já existe agendamento' : '$time — ${fitAvailable ? 'Encaixe disponível (1 agendamento)' : selected ? 'Selecionado' : 'Livre'}', child: SizedBox(width: compact ? 76 : 72, height: compact ? 30 : 40, child: OutlinedButton(
        key: ValueKey('booking-slot-$time'),
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: selected ? onAccent : fitAvailable ? Colors.orange : muted,
          disabledForegroundColor: busy ? occupiedColor : muted,
          disabledBackgroundColor: busy ? occupiedColor.withValues(alpha: 0.12) : Colors.transparent,
          backgroundColor: selected ? accent : Colors.transparent,
          side: BorderSide(color: busy ? occupiedColor.withValues(alpha: 0.5) : selected ? accent : border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
        onPressed: saving || loading || busy || error != null ? null : () => onTime(time),
        child: busy || fitAvailable ? Column(mainAxisSize: MainAxisSize.min, children: [Text(time, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 11, height: 1.1)), Text(busy ? 'Ocupado' : 'Encaixe', style: const TextStyle(fontSize: 9, height: 1.1))]) : Text(time, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 12)),
      )));
    })]);
    return Scaffold(backgroundColor: bg, body: SafeArea(bottom: false, child: Column(children: [header, Expanded(child: AbsorbPointer(absorbing: saving, child: SingleChildScrollView(key: const ValueKey('booking-scroll'), padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 12, vertical: compact ? 12 : 16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1320), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      heading(1, 'Paciente', detail: 'Busque no cadastro ou registre um novo'),
      Row(children: [Expanded(child: SizedBox(height: 42, child: patientField)), if (onNewPatient != null) ...[const SizedBox(width: 10), SizedBox(height: 42, child: OutlinedButton.icon(onPressed: saving ? null : onNewPatient, icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Novo')))]]),
      if (patientSummary != null) Padding(padding: const EdgeInsets.only(top: 6), child: box(Row(children: [Expanded(child: Text(patientSummary!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 12))), if (recordNumber != null && recordNumber!.isNotEmpty && width > 600) Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('Prontuário $recordNumber', style: const TextStyle(fontSize: 12))), if (onChangePatient != null) TextButton(style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.all(4), tapTargetSize: MaterialTapTargetSize.shrinkWrap), onPressed: saving ? null : onChangePatient, child: const Text('Alterar paciente', style: TextStyle(fontSize: 11)))]), padding: 6)),
      if (risk != null) risk!, SizedBox(height: gap),
      heading(2, 'Procedimento Odontológico', detail: 'Tabela de Procedimentos e Valores'),
      box(Row(children: [Icon(Icons.medical_services_outlined, color: accent, size: 24), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(height: 32, child: procedureField), if (procedureCategory != null) Text(procedureCategory!, style: TextStyle(color: muted, fontSize: 11))])), if (procedurePrice != null && width >= 600) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(reportMoney(procedurePrice!), style: TextStyle(color: accent, fontWeight: FontWeight.w700))), TextButton(onPressed: saving ? null : onProcedure, child: const Text('Trocar'))]), padding: compact ? 8 : 12),
      SizedBox(height: gap), ConstrainedBox(constraints: BoxConstraints(maxHeight: compact ? 92 : 200), child: SingleChildScrollView(child: tags)), SizedBox(height: gap),
      heading(3, 'Data e Horários Disponíveis', detail: DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(selectedDate)),
      box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ClinicalBookingCalendar(selected: selectedDate, onChanged: onDate, compact: compact, embedded: true), Divider(color: border, height: 16), Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 4, children: [Text('Horários de Atendimento Disponíveis', style: TextStyle(color: muted, fontSize: 12)), Wrap(spacing: 12, children: [Text('● Selecionado', style: TextStyle(color: accent, fontSize: 11)), Text('○ Livre', style: TextStyle(color: muted, fontSize: 11)), Text('◼ Ocupado', style: TextStyle(color: occupiedColor, fontSize: 11))])]), const SizedBox(height: 8), if (loading) const LinearProgressIndicator(), if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), slots]), padding: compact ? 12 : 16),
      SizedBox(height: gap), box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 18, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('Confirmação via WhatsApp: envio manual na Agenda', style: TextStyle(color: muted, fontSize: 11)), Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: fitIn, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, onChanged: saving ? null : (v) => onFitIn(v!)), const Text('Paciente de Encaixe / Urgência', style: TextStyle(fontSize: 12))])]),
        TextField(key: const ValueKey('booking-notes'), controller: notesController, minLines: 1, maxLines: compact ? 2 : 4, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), labelText: 'Observações Clínicas ou Recomendações Pré-Atendimento (opcional)'), style: const TextStyle(fontSize: 12)),
      ]), padding: compact ? (tight ? 8 : 10) : 16),
    ])))))), footer])));
  }
}
