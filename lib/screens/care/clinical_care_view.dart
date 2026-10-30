import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../services/care_day.dart';
import '../../services/care_workflow.dart';
import '../agenda/clinical_agenda_view.dart';

class CareSurface extends StatelessWidget {
  const CareSurface({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: ClinicalAgendaStyle.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class CarePill extends StatelessWidget {
  const CarePill(this.text, {super.key, this.active = false});
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active
          ? ClinicalAgendaStyle.teal.withValues(alpha: .15)
          : ClinicalAgendaStyle.elevated,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: active ? const Color(0xFF43E1BA) : ClinicalAgendaStyle.muted,
      ),
    ),
  );
}

String careStatusLabel(AppointmentModel a, bool psychology) {
  if (careInProgress(a.status)) {
    return psychology ? 'Em sessão' : 'Em atendimento';
  }
  if (needsConfirmation(a)) return 'Aguardando confirmação';
  return a.status;
}

class ClinicalCareDayView extends StatelessWidget {
  const ClinicalCareDayView({
    super.key,
    required this.date,
    required this.clinicName,
    required this.psychology,
    required this.appointments,
    required this.professionals,
    required this.paidToday,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onConfirm,
    required this.onFilters,
    required this.onNew,
    required this.confirming,
    this.panel,
    this.activeId,
    this.contractKinds = const {},
    this.directoryError,
  });
  final DateTime date;
  final String clinicName;
  final bool psychology;
  final List<AppointmentModel> appointments;
  final Map<String, String> professionals;
  final Map<String, String> contractKinds;
  final Set<String> paidToday;
  final Set<String> selected;
  final void Function(String, bool) onSelect;
  final ValueChanged<AppointmentModel> onOpen;
  final VoidCallback onConfirm, onFilters, onNew;
  final bool confirming;
  final Widget? panel;
  final String? activeId, directoryError;
  static const weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final running = appointments
          .where((a) => careInProgress(a.status))
          .length;
      final waiting = appointments.where(needsConfirmation).length;
      final packages = appointments
          .where((a) => contractKinds[a.scheduleId] == 'package')
          .length;
      final singles = appointments
          .where((a) => contractKinds[a.scheduleId] == 'session')
          .length;
      final list = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
            child: Text(
              psychology ? 'Atendimentos agendados' : 'Ordem cronológica',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: appointments.isEmpty
                ? const Center(child: Text('Nenhum atendimento neste filtro.'))
                : ListView.separated(
                    itemCount: appointments.length + 1,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == appointments.length) {
                        return CareSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                psychology ? 'Nova sessão' : 'Encaixe rápido',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Escolha um profissional e um horário livre.',
                                style: TextStyle(
                                  color: ClinicalAgendaStyle.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: onNew,
                                icon: const Icon(Icons.add),
                                label: Text(
                                  psychology ? 'Nova sessão' : 'Novo encaixe',
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final a = appointments[index];
                      final active = a.id == activeId;
                      final kind = contractKinds[a.scheduleId];
                      final color = careInProgress(a.status)
                          ? const Color(0xFF43E1BA)
                          : (a.isDone
                                ? ClinicalAgendaStyle.muted
                                : ClinicalAgendaStyle.blue);
                      return Material(
                        color: active
                            ? ClinicalAgendaStyle.elevated
                            : ClinicalAgendaStyle.surface,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onOpen(a),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: color, width: 5),
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (needsConfirmation(a))
                                      Checkbox(
                                        value: selected.contains(a.id),
                                        onChanged: (value) =>
                                            onSelect(a.id, value ?? false),
                                      )
                                    else
                                      Icon(
                                        psychology
                                            ? Icons.psychology_outlined
                                            : Icons.medical_services_outlined,
                                        color: color,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${a.date.hour.toString().padLeft(2, '0')}:${a.date.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        a.patientName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip:
                                          'Abrir atendimento de ${a.patientName}',
                                      onPressed: () => onOpen(a),
                                      icon: const Icon(
                                        Icons.open_in_full,
                                        size: 17,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  a.procedure,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ClinicalAgendaStyle.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (professionals[a.dentistId] != null)
                                  Text(
                                    professionals[a.dentistId]!,
                                    style: const TextStyle(
                                      color: ClinicalAgendaStyle.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    CarePill(
                                      careStatusLabel(a, psychology),
                                      active: careInProgress(a.status),
                                    ),
                                    if (psychology && kind != null)
                                      CarePill(
                                        kind == 'package'
                                            ? 'PACOTE MENSAL'
                                            : 'AVULSA',
                                      ),
                                    if (psychology &&
                                        kind == null &&
                                        a.scheduleId != null)
                                      const CarePill('Contrato vinculado'),
                                    if (paidToday.contains(a.patientId))
                                      const CarePill(
                                        'Pagamento hoje',
                                        active: true,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: FilledButton.icon(
                onPressed: confirming ? null : onConfirm,
                icon: const Icon(Icons.check),
                label: Text(
                  confirming
                      ? 'Confirmando…'
                      : 'Confirmar presença (${selected.length})',
                ),
              ),
            ),
        ],
      );
      return Padding(
        padding: EdgeInsets.all(constraints.maxWidth < 500 ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${psychology ? 'PSICOLOGIA E PSICOTERAPIA' : 'FLUXO CLÍNICO ATIVO'} • $clinicName',
              style: const TextStyle(
                color: Color(0xFF43E1BA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Meu dia • ${weekdays[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: wide ? 27 : 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CarePill(
                  '${appointments.length} ${psychology ? 'sessões' : 'consultas'} hoje',
                ),
                CarePill('$running em andamento', active: running > 0),
                if (!psychology) CarePill('$waiting aguardando'),
                if (psychology && contractKinds.isNotEmpty) ...[
                  CarePill('$packages em pacote'),
                  CarePill('$singles avulsas'),
                ],
                OutlinedButton.icon(
                  onPressed: onFilters,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Filtros'),
                ),
                IconButton(
                  tooltip: psychology ? 'Nova sessão' : 'Novo encaixe',
                  onPressed: onNew,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (directoryError != null)
              Text(
                directoryError!,
                style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width:
                              constraints.maxWidth * (psychology ? .32 : .38),
                          child: list,
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child:
                              panel ??
                              const CareSurface(
                                child: Center(
                                  child: Text(
                                    'Selecione um atendimento para abrir a ficha.',
                                  ),
                                ),
                              ),
                        ),
                      ],
                    )
                  : list,
            ),
          ],
        ),
      );
    },
  );
}

class ClinicalCareVisitView extends StatelessWidget {
  const ClinicalCareVisitView({
    super.key,
    required this.appointment,
    required this.psychology,
    required this.detailsController,
    required this.markers,
    required this.templates,
    required this.onMarker,
    required this.onSaveDraft,
    required this.onSaveEvolution,
    required this.onFinalize,
    required this.onStartPause,
    required this.onOpenRecord,
    required this.billing,
    required this.scheduling,
    required this.draftStatus,
    required this.saving,
    required this.evolutionSaved,
    this.alerts = const [],
    this.professionalName,
    this.onClose,
    this.status,
  });
  final AppointmentModel appointment;
  final bool psychology, saving, evolutionSaved;
  final TextEditingController detailsController;
  final Set<String> markers;
  final List<String> templates, alerts;
  final ValueChanged<String> onMarker;
  final VoidCallback onSaveDraft,
      onSaveEvolution,
      onFinalize,
      onStartPause,
      onOpenRecord;
  final VoidCallback? onClose;
  final Widget billing, scheduling;
  final String draftStatus;
  final String? professionalName, status;
  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final currentStatus = status ?? a.status;
    final done = currentStatus == 'Finalizado';
    Widget section(String title, IconData icon, Widget body) => CareSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: psychology
                    ? const Color(0xFF43E1BA)
                    : ClinicalAgendaStyle.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
    return Theme(
      data: ClinicalAgendaStyle.theme,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          CareSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ClinicalAgendaStyle.teal.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        psychology
                            ? Icons.psychology_outlined
                            : Icons.medical_services_outlined,
                        size: 30,
                        color: const Color(0xFF43E1BA),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.patientName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${a.date.day}/${a.date.month} ${a.date.hour.toString().padLeft(2, '0')}:${a.date.minute.toString().padLeft(2, '0')} • ${a.procedure}',
                            style: const TextStyle(
                              color: ClinicalAgendaStyle.muted,
                              fontSize: 12,
                            ),
                          ),
                          if (professionalName != null)
                            Text(
                              professionalName!,
                              style: const TextStyle(
                                color: ClinicalAgendaStyle.muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: 'Fechar ficha',
                        onPressed: saving ? null : onClose,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                CarePill(currentStatus, active: careInProgress(currentStatus)),
                const SizedBox(height: 12),
                if (!psychology && alerts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: alerts
                          .map(
                            (text) => Text(
                              text,
                              style: const TextStyle(
                                color: Color(0xFFFFB4AB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: onOpenRecord,
                  icon: const Icon(Icons.folder_shared_outlined),
                  label: Text(
                    psychology
                        ? 'Abrir prontuário psicológico completo'
                        : 'Abrir prontuário',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          section(
            psychology ? 'Registro de evolução clínica' : '1. Evolução clínica',
            Icons.edit_note,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  psychology
                      ? 'Síntese da sessão e conduta psicoterapêutica'
                      : 'Registro clínico formal',
                  style: const TextStyle(
                    color: ClinicalAgendaStyle.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final template in templates)
                      FilterChip(
                        label: Text(
                          template,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: markers.contains(template),
                        onSelected: done || saving
                            ? null
                            : (_) => onMarker(template),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('care-evolution'),
                  controller: detailsController,
                  readOnly: done || saving,
                  minLines: psychology ? 6 : 4,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: psychology
                        ? 'Descreva a sessão e a conduta…'
                        : 'Descreva o atendimento realizado…',
                    filled: true,
                    fillColor: ClinicalAgendaStyle.background,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: detailsController,
                  builder: (_, value, child) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${value.text.length} caracteres',
                      style: const TextStyle(
                        color: ClinicalAgendaStyle.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (psychology)
                      OutlinedButton(
                        onPressed: saving || done ? null : onSaveDraft,
                        child: const Text('Salvar como rascunho'),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3DDBB7),
                        foregroundColor: const Color(0xFF00382F),
                      ),
                      onPressed: saving || done ? null : onSaveEvolution,
                      icon: Icon(
                        evolutionSaved ? Icons.check : Icons.save_outlined,
                      ),
                      label: Text(
                        psychology
                            ? 'Salvar evolução psicológica'
                            : 'Salvar evolução',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          section(
            psychology
                ? 'Controle de pacote terapêutico e cobrança'
                : '2. Cobrança e financeiro',
            Icons.account_balance_wallet_outlined,
            billing,
          ),
          const SizedBox(height: 12),
          section(
            psychology
                ? 'Agendamento da próxima sessão'
                : '3. Próxima sessão / Agendamento',
            Icons.event_available,
            scheduling,
          ),
          const SizedBox(height: 12),
          CareSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_outlined,
                      color: ClinicalAgendaStyle.teal,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        draftStatus,
                        style: const TextStyle(
                          color: ClinicalAgendaStyle.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!done)
                      OutlinedButton.icon(
                        onPressed: saving ? null : onStartPause,
                        icon: Icon(
                          careInProgress(currentStatus)
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          careInProgress(currentStatus)
                              ? 'Pausar sessão'
                              : (carePaused(currentStatus)
                                    ? 'Retomar sessão'
                                    : (psychology
                                          ? 'Iniciar sessão'
                                          : 'Iniciar atendimento')),
                        ),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3DDBB7),
                        foregroundColor: const Color(0xFF00382F),
                      ),
                      onPressed: saving || done ? null : onFinalize,
                      icon: const Icon(Icons.task_alt),
                      label: Text(
                        done
                            ? 'Atendimento finalizado'
                            : (psychology
                                  ? 'Finalizar sessão terapêutica'
                                  : 'Finalizar atendimento'),
                      ),
                    ),
                  ],
                ),
                if (saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
