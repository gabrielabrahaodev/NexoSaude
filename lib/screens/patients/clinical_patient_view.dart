import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../models/financial_model.dart';
import '../../models/tooth_model.dart';
import '../../utils/display.dart';
import '../../ui/app_theme.dart';
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

abstract final class PatientVisualStyle {
  static Color get background => clinicalAgendaEnabled
      ? ClinicalAgendaStyle.background
      : AppColors.background;
  static Color get surface =>
      clinicalAgendaEnabled ? ClinicalAgendaStyle.surface : AppColors.surface;
  static Color get textPrimary =>
      clinicalAgendaEnabled ? ClinicalAgendaStyle.text : AppColors.textPrimary;
  static Color get textSecondary => clinicalAgendaEnabled
      ? ClinicalAgendaStyle.muted
      : AppColors.textSecondary;
  static Color get accent => ClinicalAgendaStyle.accent;
  static Color get warning => ClinicalAgendaStyle.warning;

  /// Register an inherited theme dependency so live switching keeps existing State.
  static ThemeData forContext(BuildContext context) {
    Theme.of(context);
    return theme;
  }

  static ThemeData get theme => ClinicalCareStyle.theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ClinicalAgendaStyle.teal,
        foregroundColor: ClinicalAgendaStyle.onAccent,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
  static Widget panel(Widget child, {double padding = 16, Color? color}) =>
      Material(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      );
}

class ClinicalPatientHeader extends StatelessWidget {
  const ClinicalPatientHeader({
    super.key,
    required this.name,
    required this.id,
    required this.status,
    required this.consent,
    required this.psychology,
    required this.onBack,
    required this.onPayments,
    required this.onRegistration,
    this.birth,
    this.cpf,
    this.phone,
  });
  final String name, id, status;
  final bool consent, psychology;
  final String? birth, cpf, phone;
  final VoidCallback onBack, onPayments, onRegistration;
  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0])
        .join()
        .toUpperCase();
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back, size: 20),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ClinicalAgendaStyle.elevated,
            border: Border.all(color: const Color(0xFF22B8D7), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            initials,
            style: TextStyle(
              color: PatientVisualStyle.accent,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  CarePill('ID $id'),
                  CarePill(status, active: status.toLowerCase() == 'ativo'),
                  if (consent) const CarePill('LGPD aceito', active: true),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (birth?.isNotEmpty == true) Text(birth!, style: _meta),
                  if (cpf?.isNotEmpty == true)
                    Text(_maskedCpf(cpf!), style: _meta),
                  if (phone?.isNotEmpty == true) Text(phone!, style: _meta),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                psychology
                    ? 'Psicologia & Psicoterapia'
                    : 'Odontologia & Clínica Geral',
                style: TextStyle(
                  color: PatientVisualStyle.accent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 6,
      children: [
        FilledButton.icon(
          onPressed: onPayments,
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text('Receber pagamento'),
        ),
        IconButton(
          onPressed: onRegistration,
          tooltip: 'Editar cadastro',
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
    return PatientVisualStyle.panel(
      LayoutBuilder(
        builder: (context, c) => c.maxWidth > 780
            ? Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  actions,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              ),
      ),
    );
  }

  static TextStyle get _meta =>
      TextStyle(color: ClinicalAgendaStyle.muted, fontSize: 12);
  static String _maskedCpf(String value) {
    final d = value.replaceAll(RegExp(r'\D'), '');
    return d.length == 11
        ? '${d.substring(0, 3)}.***.***-${d.substring(9)}'
        : value;
  }
}

class PatientMetric extends StatelessWidget {
  const PatientMetric({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    this.progress = 0,
    this.badge,
  });
  final String label, value, detail;
  final IconData icon;
  final Color color;
  final double progress;
  final String? badge;
  @override
  Widget build(BuildContext context) => PatientVisualStyle.panel(
    SizedBox(
      height: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: PatientVisualStyle.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (badge != null)
                Text(badge!, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PatientVisualStyle.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 4,
              color: color,
              backgroundColor: ClinicalAgendaStyle.elevated,
            ),
          ),
        ],
      ),
    ),
  );
}

class ClinicalPatientMetrics extends StatelessWidget {
  const ClinicalPatientMetrics({super.key, required this.items});
  final List<Widget> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 760 ? 4 : (c.maxWidth >= 320 ? 2 : 1);
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in items)
            SizedBox(width: (c.maxWidth - 16 * (cols - 1)) / cols, child: item),
        ],
      );
    },
  );
}

class PatientSectionHeading extends StatelessWidget {
  const PatientSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final label = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: PatientVisualStyle.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: c.maxWidth > 640
            ? Row(
                children: [
                  Expanded(child: label),
                  if (action != null) action!,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  if (action != null) ...[const SizedBox(height: 10), action!],
                ],
              ),
      );
    },
  );
}

class ClinicalTreatmentCard extends StatelessWidget {
  const ClinicalTreatmentCard({
    super.key,
    required this.start,
    required this.active,
    required this.items,
    required this.total,
    required this.paid,
    required this.margin,
    required this.installments,
    required this.onFinancial,
    required this.onPayments,
    required this.onClose,
    this.onLinkedTeeth,
  });
  final String start, installments;
  final bool active;
  final List<Map<String, dynamic>> items;
  final double total, paid, margin;
  final VoidCallback onFinancial, onPayments, onClose;
  final VoidCallback? onLinkedTeeth;
  String _amount(num value) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  Widget pill(String text, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: (color ?? PatientVisualStyle.accent).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color ?? PatientVisualStyle.accent,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final buttonSize = Size(0, mobile ? 40 : 28);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PatientVisualStyle.panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 9,
                        color: PatientVisualStyle.accent,
                      ),
                      Text(
                        'Iniciado em $start',
                        style: TextStyle(
                          color: PatientVisualStyle.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      pill(
                        active ? 'EM ANDAMENTO' : 'CONCLUÍDO',
                        color: active
                            ? PatientVisualStyle.accent
                            : ClinicalAgendaStyle.muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onFinancial,
                  child: pill('↗  Margem: ${margin.toStringAsFixed(0)}%'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: ClinicalAgendaStyle.elevated,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['status'] == 'realizado'
                          ? Icons.check_circle_outline
                          : Icons.radio_button_checked,
                      size: 17,
                      color: PatientVisualStyle.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item['name'] ?? 'Procedimento'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _amount(parseBRL(item['price'])),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontFamilyFallback: ['PlusJakartaSans'],
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  'Progresso Financeiro:',
                  style: TextStyle(
                    fontSize: 11,
                    color: PatientVisualStyle.textSecondary,
                  ),
                ),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _amount(paid),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontFamilyFallback: ['PlusJakartaSans'],
                        fontSize: 10,
                        color: PatientVisualStyle.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'de ${_amount(total)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: PatientVisualStyle.textSecondary,
                      ),
                    ),
                    if (installments.isNotEmpty)
                      pill(installments, color: PatientVisualStyle.warning),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: total > 0 ? (paid / total).clamp(0, 1) : 0,
                minHeight: 6,
                backgroundColor: ClinicalAgendaStyle.elevated,
                color: PatientVisualStyle.accent,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onPayments,
                      style: FilledButton.styleFrom(
                        minimumSize: buttonSize,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 14),
                      label: const Text('Receber Parcela'),
                    ),
                    TextButton(
                      onPressed: onLinkedTeeth,
                      style: TextButton.styleFrom(
                        minimumSize: buttonSize,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        foregroundColor: ClinicalAgendaStyle.text,
                        backgroundColor: ClinicalAgendaStyle.elevated,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Ver Dentes Vinculados'),
                    ),
                  ],
                ),
                if (active)
                  OutlinedButton.icon(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      minimumSize: buttonSize,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      foregroundColor: PatientVisualStyle.warning,
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Color(0xFF705516)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('ENCERRAR TRATAMENTO'),
                  ),
              ],
            ),
          ],
        ),
        padding: 14,
      ),
    );
  }
}

class ClinicalPatientLedger extends StatelessWidget {
  const ClinicalPatientLedger({
    super.key,
    required this.charges,
    required this.onOpen,
    required this.onReceive,
    this.professionals = const {},
  });
  final List<FinancialModel> charges;
  final Map<String, String> professionals;
  static String statusLabel(FinancialModel f) {
    if (f.isPaid) return 'Pago (${f.paymentMethod})';
    if (FinancialModel.isReplaced(f.status)) return 'Parcelado';
    if (f.status.toLowerCase() == 'cancelado') return 'Cancelado';
    final overdue =
        f.dueDate != null &&
        DateUtils.dateOnly(
          f.dueDate!,
        ).isBefore(DateUtils.dateOnly(DateTime.now()));
    return overdue
        ? 'Pendente (atrasado)'
        : (['pending', 'pendente'].contains(f.status.toLowerCase())
              ? 'Pendente'
              : f.status);
  }

  static Widget statusChip(FinancialModel f) {
    final color = f.isPaid
        ? PatientVisualStyle.accent
        : PatientVisualStyle.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(statusLabel(f), style: TextStyle(color: color, fontSize: 10)),
    );
  }

  final ValueChanged<FinancialModel> onOpen, onReceive;
  @override
  Widget build(BuildContext context) => PatientVisualStyle.panel(
    LayoutBuilder(
      builder: (context, c) {
        if (charges.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Nenhuma cobrança neste filtro.'),
          );
        }
        if (c.maxWidth < 820) {
          return Column(
            children: [
              for (final f in charges)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  title: Text(f.title),
                  subtitle: Text(
                    '${formatDateShortYear(f.dueDate ?? f.date)} • ${statusLabel(f)}\n${formatBRL(f.amount)}',
                  ),
                  isThreeLine: true,
                  onTap: () => onOpen(f),
                  trailing: IconButton(
                    tooltip: f.isPaid
                        ? 'Opções do pagamento'
                        : 'Receber / opções',
                    onPressed: () => onOpen(f),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: DataTable(
            horizontalMargin: 0,
            columnSpacing: 18,
            headingRowHeight: 36,
            dataRowMinHeight: 66,
            dataRowMaxHeight: 80,
            dividerThickness: .3,
            columns: [
              for (final title in [
                'VENCIMENTO',
                'DESCRIÇÃO DO TRATAMENTO',
                'PROFISSIONAL',
                'VALOR',
                'FORMA / STATUS',
                'AÇÃO',
              ])
                DataColumn(
                  label: Text(
                    title,
                    style: TextStyle(
                      color: PatientVisualStyle.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            rows: [
              for (final f in charges)
                DataRow(
                  onSelectChanged: (_) => onOpen(f),
                  cells: [
                    DataCell(
                      Text(
                        formatDateShortYear(f.dueDate ?? f.date),
                        style: TextStyle(
                          color:
                              !f.isPaid &&
                                  f.dueDate != null &&
                                  f.dueDate!.isBefore(DateTime.now())
                              ? PatientVisualStyle.warning
                              : PatientVisualStyle.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth * .25),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (f.installmentNumber != null)
                              Text(
                                'Parcela ${f.installmentNumber}',
                                style: TextStyle(
                                  color: PatientVisualStyle.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          f.dentistName ?? professionals[f.dentistId] ?? '—',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        formatBRL(f.amount),
                        style: TextStyle(
                          color: f.isPaid
                              ? PatientVisualStyle.accent
                              : PatientVisualStyle.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataCell(statusChip(f)),
                    DataCell(
                      (f.isPaid ||
                              f.status.toLowerCase() == 'cancelado' ||
                              FinancialModel.isReplaced(f.status))
                          ? TextButton(
                              onPressed: () => onOpen(f),
                              child: const Text('Opções'),
                            )
                          : FilledButton(
                              onPressed: () => onReceive(f),
                              child: const Text('Receber'),
                            ),
                    ),
                  ],
                ),
            ],
            showCheckboxColumn: false,
          ),
        );
      },
    ),
    padding: 16,
  );
}

/// Persisted procedure colors shared by the face, tooth number and legend.
abstract final class ClinicalToothStyle {
  static Color? color(String? status) => switch (status) {
    'issue' => ClinicalAgendaStyle.tone(
      const Color(0xFFEF4444),
      const Color(0xFFC42B2B),
    ),
    'restored' => ClinicalAgendaStyle.tone(
      const Color(0xFF0284C7),
      const Color(0xFF00659A),
    ),
    'planned' || 'crown_planned' => ClinicalAgendaStyle.tone(
      const Color(0xFFF59E0B),
      const Color(0xFF946000),
    ),
    'crown_done' => ClinicalAgendaStyle.tone(
      const Color(0xFF0D9488),
      const Color(0xFF006C63),
    ),
    'endo_planned' => ClinicalAgendaStyle.tone(
      const Color(0xFFEC4899),
      const Color(0xFFB52675),
    ),
    'endo_done' => ClinicalAgendaStyle.tone(
      const Color(0xFFD16AA4),
      const Color(0xFF831843),
    ),
    'implant_planned' => ClinicalAgendaStyle.tone(
      const Color(0xFFA855F7),
      const Color(0xFF7F2CC2),
    ),
    'implant_done' => ClinicalAgendaStyle.tone(
      const Color(0xFFB67BDF),
      const Color(0xFF581C87),
    ),
    'missing' => ClinicalAgendaStyle.muted,
    _ => null,
  };
  static Color? numberColor(String? status) => ClinicalAgendaStyle.isDark
      ? switch (status) {
          'restored' => const Color(0xFFADC6FF),
          'planned' || 'crown_planned' => const Color(0xFFFFC400),
          'endo_planned' => const Color(0xFFFFB1DA),
          _ => color(status),
        }
      : color(status);
  static String? marker(ToothModel tooth) {
    if (tooth.isMissing) return 'missing';
    final root = tooth.facesStatus[ToothFace.root.name];
    if (color(root) != null) return root;
    final occlusal = tooth.facesStatus[ToothFace.occlusal.name];
    if (color(occlusal) != null) return occlusal;
    for (final face in ToothFace.values) {
      final status = tooth.facesStatus[face.name];
      if (color(status) != null) return status;
    }
    return null;
  }
}

/// Five anatomical hit targets, with root procedures on long press.
class ClinicalTooth extends StatelessWidget {
  const ClinicalTooth({
    super.key,
    required this.tooth,
    required this.onFaceTap,
    this.size = 34,
  });
  final ToothModel tooth;
  final void Function(ToothModel, ToothFace) onFaceTap;
  final double size;
  @override
  Widget build(BuildContext context) {
    final marker = ClinicalToothStyle.marker(tooth);
    final color = ClinicalToothStyle.color(marker);
    final framed =
        tooth.facesStatus[ToothFace.root.name] != null ||
        marker == 'restored' ||
        tooth.isMissing;
    final number = Text(
      '${tooth.id}',
      key: ValueKey('tooth-number-${tooth.id}'),
      style: TextStyle(
        fontSize: 10,
        color:
            ClinicalToothStyle.numberColor(marker) ??
            PatientVisualStyle.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
    return Semantics(
      label: 'Dente ${tooth.id}',
      child: Container(
        key: ValueKey('tooth-marker-${tooth.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: framed ? color ?? Colors.transparent : Colors.transparent,
          ),
          color: framed ? color?.withValues(alpha: .04) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tooth.isUpper) ...[number, const SizedBox(height: 5)],
            GestureDetector(
              onTapUp: (d) {
                final p = d.localPosition / size;
                final face =
                    p.dx > .27 && p.dx < .73 && p.dy > .27 && p.dy < .73
                    ? ToothFace.occlusal
                    : (p.dy < p.dx && p.dy < 1 - p.dx
                          ? ToothFace.vestibular
                          : (p.dy > p.dx && p.dy > 1 - p.dx
                                ? ToothFace.lingual
                                : (p.dx < .5
                                      ? ToothFace.mesial
                                      : ToothFace.distal)));
                onFaceTap(tooth, face);
              },
              onLongPress: () => onFaceTap(tooth, ToothFace.root),
              child: CustomPaint(
                size: Size.square(size),
                painter: _PatientToothPainter(
                  tooth,
                  ClinicalAgendaStyle.isDark,
                ),
              ),
            ),
            if (!tooth.isUpper) ...[const SizedBox(height: 5), number],
          ],
        ),
      ),
    );
  }
}

class _PatientToothPainter extends CustomPainter {
  const _PatientToothPainter(this.tooth, this.dark);
  final ToothModel tooth;
  final bool dark;
  Color color(String? status) =>
      ClinicalToothStyle.color(status) ??
      (dark ? const Color(0xFF181C22) : Colors.white);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final a = w * .27, b = w * .73;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = dark ? const Color(0xFF767D8A) : const Color(0xFF657388)
      ..strokeWidth = .8;
    void face(ToothFace f, List<Offset> points) {
      final p = Path()..addPolygon(points, true);
      final status = tooth.facesStatus[f.name];
      final rootColor = ClinicalToothStyle.color(
        tooth.facesStatus[ToothFace.root.name],
      );
      final fill = status != null
          ? color(status)
          : rootColor != null
          ? rootColor.withValues(alpha: f == ToothFace.occlusal ? .65 : .18)
          : color(null);
      canvas.drawPath(p, Paint()..color = fill);
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color =
              ClinicalToothStyle.color(status) ?? rootColor ?? stroke.color,
      );
    }

    face(ToothFace.vestibular, [
      Offset.zero,
      Offset(w, 0),
      Offset(b, a),
      Offset(a, a),
    ]);
    face(ToothFace.lingual, [
      Offset(0, w),
      Offset(w, w),
      Offset(b, b),
      Offset(a, b),
    ]);
    face(ToothFace.mesial, [
      Offset.zero,
      Offset(0, w),
      Offset(a, b),
      Offset(a, a),
    ]);
    face(ToothFace.distal, [
      Offset(w, 0),
      Offset(w, w),
      Offset(b, b),
      Offset(b, a),
    ]);
    face(ToothFace.occlusal, [
      Offset(a, a),
      Offset(b, a),
      Offset(b, b),
      Offset(a, b),
    ]);
    if (tooth.isMissing) {
      canvas.drawLine(Offset.zero, Offset(w, w), stroke);
      canvas.drawLine(Offset(w, 0), Offset(0, w), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _PatientToothPainter oldDelegate) => true;
}

class ClinicalOdontogramView extends StatelessWidget {
  const ClinicalOdontogramView({
    super.key,
    required this.teeth,
    required this.controller,
    required this.onFaceTap,
    required this.onSave,
    required this.saving,
  });
  final List<ToothModel> teeth;
  final TransformationController controller;
  final void Function(ToothModel, ToothFace) onFaceTap;
  final VoidCallback onSave;
  final bool saving;
  void zoom(double factor) {
    final value = controller.value.clone();
    value.scaleByDouble(factor, factor, factor, 1);
    controller.value = value;
  }

  @override
  Widget build(BuildContext context) => PatientVisualStyle.panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, c) {
              final title = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_on_outlined,
                    color: PatientVisualStyle.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Odontograma anatômico',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Adulto (Permanente FDI de dois dígitos)',
                          style: TextStyle(
                            fontSize: 11,
                            color: PatientVisualStyle.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final controls = Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => zoom(1.15),
                    tooltip: 'Zoom +',
                    icon: const Icon(Icons.zoom_in, size: 19),
                  ),
                  IconButton(
                    onPressed: () => zoom(1 / 1.15),
                    tooltip: 'Zoom −',
                    icon: const Icon(Icons.zoom_out, size: 19),
                  ),
                  IconButton(
                    onPressed: () =>
                        controller.value = Matrix4.identity()
                          ..scaleByDouble(
                            (c.maxWidth / 880).clamp(.3, 1),
                            (c.maxWidth / 880).clamp(.3, 1),
                            1,
                            1,
                          ),
                    tooltip: 'Ajustar à tela',
                    icon: const Icon(Icons.center_focus_strong, size: 19),
                  ),
                  FilledButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: Text(saving ? 'Salvando…' : 'Salvar alterações'),
                  ),
                ],
              );
              return c.maxWidth > 740
                  ? Row(
                      children: [
                        Expanded(child: title),
                        controls,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 12), controls],
                    );
            },
          ),
        ),
        Container(
          color: ClinicalAgendaStyle.background,
          height: 300,
          child: LayoutBuilder(
            builder: (context, c) => InteractiveViewer(
              transformationController: controller,
              minScale: .3,
              maxScale: 4,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(300),
              child: SizedBox(
                width: c.maxWidth < 880 ? 880 : c.maxWidth,
                height: 300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _archLabel('ARCADA SUPERIOR (MAXILA)'),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final tooth in teeth.where((t) => t.isUpper))
                          ClinicalTooth(
                            tooth: tooth,
                            onFaceTap: onFaceTap,
                            size: 32,
                          ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _archLabel('LINHA MÉDIA DENTAL'),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final tooth in teeth.where((t) => !t.isUpper))
                          ClinicalTooth(
                            tooth: tooth,
                            onFaceTap: onFaceTap,
                            size: 32,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _archLabel('ARCADA INFERIOR (MANDÍBULA)'),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ClinicalAgendaStyle.tone(
              const Color(0xFF2B251A),
              const Color(0xFFFFF2D0),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Dica: Clique na face para atribuir um procedimento. Mantenha pressionado para ações de raiz. Use pinça para zoom.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PatientVisualStyle.warning, fontSize: 11),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEGENDA & PROCEDIMENTOS',
                style: TextStyle(
                  color: PatientVisualStyle.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in <(Color, String)>[
                    (
                      ClinicalToothStyle.color('endo_planned')!,
                      'Endo (Planej.)',
                    ),
                    (ClinicalToothStyle.color('endo_done')!, 'Endo (Realiz.)'),
                    (
                      ClinicalToothStyle.color('implant_planned')!,
                      'Implante (Planej.)',
                    ),
                    (
                      ClinicalToothStyle.color('implant_done')!,
                      'Implante (Realiz.)',
                    ),
                    (
                      ClinicalToothStyle.color('crown_planned')!,
                      'Coroa (Planej.)',
                    ),
                    (
                      ClinicalToothStyle.color('crown_done')!,
                      'Coroa (Realiz.)',
                    ),
                    (ClinicalToothStyle.color('issue')!, 'Cárie'),
                    (ClinicalToothStyle.color('restored')!, 'Restaurado'),
                    (
                      ClinicalToothStyle.color('crown_planned')!,
                      'A realizar (Face)',
                    ),
                    (ClinicalToothStyle.color('missing')!, 'Extraído'),
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: e.$1,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(e.$2, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    padding: 0,
  );
  static Widget _archLabel(String text) => Text(
    text,
    style: TextStyle(
      color: ClinicalAgendaStyle.muted,
      fontSize: 10,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
    ),
  );
}

class ClinicalPatientContextBanner extends StatelessWidget {
  const ClinicalPatientContextBanner({
    super.key,
    this.summary,
    this.alerts = const [],
    required this.onRefresh,
  });
  final String? summary;
  final List<String> alerts;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => PatientVisualStyle.panel(
    LayoutBuilder(
      builder: (context, c) {
        final refresh = TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 15),
          label: const Text('Atualizar resumo'),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ClinicalAgendaStyle.elevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: ClinicalAgendaStyle.blue,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESUMO DE CONTEXTO CLÍNICO INTELIGENTE',
                    style: TextStyle(
                      color: ClinicalAgendaStyle.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (summary != null)
                    Text(
                      summary!,
                      style: const TextStyle(fontSize: 13, height: 1.8),
                    ),
                  if (alerts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        alerts.join(' • '),
                        style: TextStyle(color: ClinicalAgendaStyle.danger),
                      ),
                    ),
                  if (c.maxWidth < 700)
                    Align(alignment: Alignment.centerRight, child: refresh),
                ],
              ),
            ),
            if (c.maxWidth >= 700) ...[const SizedBox(width: 12), refresh],
          ],
        );
      },
    ),
    color: ClinicalAgendaStyle.elevated,
  );
}
