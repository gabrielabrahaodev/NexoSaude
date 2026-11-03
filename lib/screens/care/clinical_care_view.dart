import 'package:flutter/material.dart';

import '../../models/appointment_model.dart';
import '../../services/care_day.dart';
import '../../services/care_workflow.dart';
import '../agenda/clinical_agenda_view.dart';

/// Styling is scoped to Atendimento: legacy screens keep their own theme.
abstract final class ClinicalCareStyle {
  static Color get accent => ClinicalAgendaStyle.accent;

  /// Register an inherited theme dependency so live switching keeps existing State.
  static ThemeData forContext(BuildContext context) {
    Theme.of(context);
    return theme;
  }

  static ThemeData get theme => ClinicalAgendaStyle.theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: ClinicalAgendaStyle.onAccent,
        minimumSize: const Size(0, 44),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: ClinicalAgendaStyle.elevated,
        foregroundColor: ClinicalAgendaStyle.text,
        side: BorderSide.none,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ClinicalAgendaStyle.elevated,
      selectedColor: ClinicalAgendaStyle.selected,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: ClinicalAgendaStyle.text,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClinicalAgendaStyle.elevated,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

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
        color: active ? ClinicalAgendaStyle.accent : ClinicalAgendaStyle.muted,
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
  Widget build(BuildContext context) => Theme(
    data: ClinicalCareStyle.forContext(context),
    child: LayoutBuilder(
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
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: appointments.isEmpty
                  ? const Center(
                      child: Text('Nenhum atendimento neste filtro.'),
                    )
                  : ListView.separated(
                      itemCount: appointments.length + 1,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == appointments.length) {
                          return CareSurface(
                            padding: 16,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_task,
                                  color: ClinicalCareStyle.accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        psychology
                                            ? 'Nova sessão'
                                            : 'Encaixe rápido',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Consultar horários livres',
                                        style: TextStyle(
                                          color: ClinicalAgendaStyle.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: onNew,
                                  tooltip: psychology
                                      ? 'Nova sessão'
                                      : 'Novo encaixe',
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          );
                        }
                        final a = appointments[index];
                        final active = a.id == activeId;
                        final kind = contractKinds[a.scheduleId];
                        final running = careInProgress(a.status);
                        final color = running
                            ? ClinicalCareStyle.accent
                            : (a.status == 'Confirmado'
                                  ? ClinicalAgendaStyle.blue
                                  : ClinicalAgendaStyle.muted);
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
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (needsConfirmation(a))
                                        Checkbox(
                                          value: selected.contains(a.id),
                                          onChanged: (value) =>
                                              onSelect(a.id, value ?? false),
                                        )
                                      else
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: .12),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            psychology
                                                ? Icons.psychology_outlined
                                                : Icons
                                                      .medical_services_outlined,
                                            color: running
                                                ? ClinicalCareStyle.accent
                                                : ClinicalAgendaStyle.muted,
                                            size: 22,
                                          ),
                                        ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              a.patientName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              a.procedure,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    ClinicalAgendaStyle.muted,
                                                fontSize: 12,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: running
                                              ? ClinicalAgendaStyle.selected
                                              : ClinicalAgendaStyle.background,
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                        child: Text(
                                          '${a.date.hour.toString().padLeft(2, '0')}:${a.date.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: running
                                                ? ClinicalCareStyle.accent
                                                : ClinicalAgendaStyle.blue,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (professionals[a.dentistId] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        professionals[a.dentistId]!,
                                        style: TextStyle(
                                          color: ClinicalAgendaStyle.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            CarePill(
                                              careStatusLabel(a, psychology),
                                              active: running,
                                            ),
                                            if (paidToday.contains(a.patientId))
                                              const CarePill(
                                                'Pagamento hoje',
                                                active: true,
                                              ),
                                          ],
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
                                        style: IconButton.styleFrom(
                                          backgroundColor: ClinicalAgendaStyle
                                              .background
                                              .withValues(alpha: .4),
                                          foregroundColor: running
                                              ? ClinicalCareStyle.accent
                                              : ClinicalAgendaStyle.muted,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (psychology &&
                                      (kind != null || a.scheduleId != null))
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: ClinicalAgendaStyle.elevated,
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            kind == 'session'
                                                ? Icons.person_outline
                                                : Icons.inventory_2_outlined,
                                            size: 15,
                                            color: running
                                                ? ClinicalCareStyle.accent
                                                : ClinicalAgendaStyle.muted,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              kind == 'package'
                                                  ? 'PACOTE MENSAL'
                                                  : (kind == 'session'
                                                        ? 'AVULSA'
                                                        : 'Contrato vinculado'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: running
                                                    ? ClinicalCareStyle.accent
                                                    : ClinicalAgendaStyle.muted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                style: TextStyle(
                  color: ClinicalAgendaStyle.accent,
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
                  style: TextStyle(
                    color: ClinicalAgendaStyle.danger,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 20),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width:
                                (constraints.maxWidth - 72) *
                                (psychology ? .32 : .40),
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
    ),
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
    final time =
        '${a.date.hour.toString().padLeft(2, '0')}:${a.date.minute.toString().padLeft(2, '0')}';
    const gap = SizedBox(height: 20);
    Widget heading(
      String title,
      IconData icon, {
      String? number,
      String? subtitle,
    }) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: number == null ? 36 : 28,
          height: number == null ? 36 : 28,
          decoration: BoxDecoration(
            color: number == null
                ? ClinicalAgendaStyle.selected
                : ClinicalAgendaStyle.elevated,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: number == null
              ? Icon(icon, color: ClinicalCareStyle.accent, size: 21)
              : Text(
                  number,
                  style: TextStyle(
                    color: ClinicalAgendaStyle.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ClinicalAgendaStyle.muted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    Widget section(
      String title,
      IconData icon,
      Widget body, {
      String? number,
      String? subtitle,
    }) {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(title, icon, number: number, subtitle: subtitle),
          const SizedBox(height: 18),
          body,
        ],
      );
      return psychology
          ? CareSurface(padding: 24, child: content)
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: content,
            );
    }

    final header = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!psychology)
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: ClinicalAgendaStyle.elevated,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: ClinicalAgendaStyle.selected,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: psychology
                    ? Icon(
                        Icons.psychology_outlined,
                        size: 30,
                        color: ClinicalCareStyle.accent,
                      )
                    : const Padding(
                        padding: EdgeInsets.all(12),
                        child: CustomPaint(painter: _ToothPainter()),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a.patientName}${psychology ? '' : ' • $time'}',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CarePill(
                      careInProgress(currentStatus)
                          ? (psychology
                                ? 'Em psicoterapia ($time)'
                                : 'Em atendimento')
                          : currentStatus,
                      active: careInProgress(currentStatus),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${a.date.day}/${a.date.month} $time • ${a.procedure}${professionalName == null ? '' : ' • $professionalName'}',
                      style: TextStyle(
                        color: ClinicalAgendaStyle.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Fechar ficha',
                  onPressed: saving ? null : onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          if (psychology) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onOpenRecord,
              icon: const Icon(Icons.folder_shared_outlined, size: 16),
              label: const Text('Abrir prontuário psicológico completo'),
            ),
          ],
        ],
      ),
    );
    final snapshot = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: ClinicalAgendaStyle.elevated.withValues(alpha: .35),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final alert in alerts)
            Text(
              alert,
              style: TextStyle(
                color: ClinicalAgendaStyle.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          TextButton.icon(
            onPressed: onOpenRecord,
            icon: const Icon(Icons.north_east, size: 14),
            label: const Text('Abrir prontuário'),
          ),
        ],
      ),
    );
    final editor = Container(
      decoration: BoxDecoration(
        color: psychology
            ? ClinicalAgendaStyle.background
            : ClinicalAgendaStyle.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, size: 17, color: ClinicalAgendaStyle.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  psychology
                      ? 'Síntese da sessão e conduta psicoterapêutica'
                      : 'Registro clínico formal',
                  style: TextStyle(
                    color: ClinicalAgendaStyle.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: detailsController,
                builder: (_, value, child) => Text(
                  '${value.text.length} caracteres',
                  style: TextStyle(
                    color: ClinicalAgendaStyle.muted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('care-evolution'),
            controller: detailsController,
            readOnly: done || saving,
            minLines: psychology ? 5 : 4,
            maxLines: null,
            style: const TextStyle(fontSize: 14, height: 1.65),
            decoration: InputDecoration(
              hintText: psychology
                  ? 'Descreva a sessão e a conduta…'
                  : 'Descreva o atendimento realizado…',
              filled: false,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
    final saveActions = Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (psychology)
            OutlinedButton(
              onPressed: saving || done ? null : onSaveDraft,
              child: const Text('Salvar como rascunho'),
            ),
          FilledButton.icon(
            onPressed: saving || done ? null : onSaveEvolution,
            icon: Icon(
              evolutionSaved
                  ? Icons.check
                  : (psychology
                        ? Icons.verified_user_outlined
                        : Icons.save_outlined),
              size: 18,
            ),
            label: Text(
              psychology ? 'Salvar evolução psicológica' : 'Salvar evolução',
            ),
          ),
        ],
      ),
    );
    final evolution = section(
      psychology ? 'Registro de evolução clínica' : 'Evolução clínica',
      Icons.edit_note,
      number: psychology ? null : '1',
      subtitle: psychology
          ? 'Registro da sessão e intervenções psicológicas'
          : null,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (psychology)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'MARCADORES E INTERVENÇÕES PSICOLÓGICAS RÁPIDAS',
                style: TextStyle(
                  color: ClinicalAgendaStyle.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final template in templates)
                FilterChip(
                  label: Text(template, style: const TextStyle(fontSize: 11)),
                  avatar: markers.contains(template)
                      ? null
                      : Icon(
                          Icons.add,
                          size: 15,
                          color: ClinicalCareStyle.accent,
                        ),
                  selected: markers.contains(template),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: done || saving ? null : (_) => onMarker(template),
                ),
            ],
          ),
          const SizedBox(height: 18),
          editor,
          const SizedBox(height: 16),
          saveActions,
        ],
      ),
    );
    final footer = CareSurface(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_done_outlined,
                color: ClinicalCareStyle.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draftStatus,
                  style: TextStyle(
                    color: ClinicalAgendaStyle.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (!done)
                  OutlinedButton.icon(
                    onPressed: saving ? null : onStartPause,
                    icon: Icon(
                      careInProgress(currentStatus)
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
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
                  onPressed: saving || done ? null : onFinalize,
                  icon: const Icon(Icons.task_alt, size: 18),
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
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
    final content = ListView(
      padding: EdgeInsets.only(bottom: psychology ? 24 : 0),
      children: [
        if (psychology) CareSurface(padding: 0, child: header) else header,
        if (!psychology) snapshot,
        if (psychology) gap,
        evolution,
        gap,
        section(
          psychology
              ? 'Controle de pacote terapêutico e cobrança'
              : 'Cobrança e financeiro',
          Icons.account_balance_wallet_outlined,
          billing,
          number: psychology ? null : '2',
          subtitle: psychology ? 'Gestão do contrato e faturamento' : null,
        ),
        gap,
        section(
          psychology
              ? 'Agendamento da próxima sessão'
              : 'Próxima sessão / Agendamento',
          Icons.event_available,
          scheduling,
          number: psychology ? null : '3',
        ),
        gap,
        if (psychology) footer,
      ],
    );
    return Theme(
      data: ClinicalCareStyle.forContext(context),
      child: psychology
          ? content
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: ClinicalAgendaStyle.surface,
                child: Column(
                  children: [
                    Expanded(child: content),
                    footer,
                  ],
                ),
              ),
            ),
    );
  }
}

/// Small code-native specialty icon; the original brand image is untouched.
class _ToothPainter extends CustomPainter {
  const _ToothPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final path = Path()
      ..moveTo(16, 6)
      ..cubicTo(10, 1, 3, 3, 4, 12)
      ..cubicTo(5, 21, 6, 29, 10, 29)
      ..cubicTo(13, 29, 12, 19, 16, 19)
      ..cubicTo(20, 19, 19, 29, 22, 29)
      ..cubicTo(26, 29, 27, 21, 28, 12)
      ..cubicTo(29, 3, 22, 1, 16, 6)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = ClinicalCareStyle.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ToothPainter oldDelegate) => false;
}
