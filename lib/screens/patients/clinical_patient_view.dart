import 'package:flutter/material.dart';
import '../../models/financial_model.dart';
import '../../models/tooth_model.dart';
import '../../utils/display.dart';
import '../../ui/app_theme.dart';
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

abstract final class PatientVisualStyle {
  static Color get background =>
      clinicalAgendaEnabled ? const Color(0xFF10141A) : AppColors.background;
  static Color get surface =>
      clinicalAgendaEnabled ? const Color(0xFF181C22) : AppColors.surface;
  static Color get textPrimary =>
      clinicalAgendaEnabled ? const Color(0xFFDFE2EB) : AppColors.textPrimary;
  static Color get textSecondary =>
      clinicalAgendaEnabled ? const Color(0xFF8C909F) : AppColors.textSecondary;
  static const accent = Color(0xFF3DDBB7), warning = Color(0xFFFFC400);
  static ThemeData get theme => ClinicalCareStyle.theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ClinicalAgendaStyle.teal,
        foregroundColor: const Color(0xFF00382C),
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
            style: const TextStyle(
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
                style: const TextStyle(
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

  static const _meta = TextStyle(
    color: ClinicalAgendaStyle.muted,
    fontSize: 12,
  );
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
  });
  final String start, installments;
  final bool active;
  final List<Map<String, dynamic>> items;
  final double total, paid, margin;
  final VoidCallback onFinancial, onPayments, onClose;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: PatientVisualStyle.panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 9,
                      color: PatientVisualStyle.accent,
                    ),
                    Text(
                      'Iniciado em $start',
                      style: TextStyle(
                        color: PatientVisualStyle.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    CarePill(
                      active ? 'EM ANDAMENTO' : 'CONCLUÍDO',
                      active: active,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onFinancial,
                child: CarePill(
                  'Margem: ${margin.toStringAsFixed(0)}%',
                  active: margin >= 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ClinicalAgendaStyle.elevated.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    item['status'] == 'realizado'
                        ? Icons.check_circle_outline
                        : Icons.radio_button_checked,
                    size: 18,
                    color: PatientVisualStyle.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${item['name'] ?? 'Procedimento'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatBRL(parseBRL(item['price'])),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Progresso financeiro',
                style: TextStyle(
                  color: PatientVisualStyle.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '${formatBRL(paid)} de ${formatBRL(total)}',
                style: const TextStyle(fontSize: 11),
              ),
              if (installments.isNotEmpty) CarePill(installments),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: total > 0 ? (paid / total).clamp(0, 1) : 0,
              color: PatientVisualStyle.accent,
              backgroundColor: ClinicalAgendaStyle.elevated,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onPayments,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Receber parcela'),
                ),
                if (active)
                  OutlinedButton.icon(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PatientVisualStyle.warning,
                      side: const BorderSide(color: Color(0xFF705516)),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('ENCERRAR TRATAMENTO'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
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

/// Geometric five-face crown with a separate, accessible root action.
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
  Widget build(BuildContext context) => Semantics(
    label: 'Dente ${tooth.id}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tooth.isUpper)
          Text('${tooth.id}', style: const TextStyle(fontSize: 10)),
        GestureDetector(
          onTapUp: (d) {
            final p = d.localPosition / size;
            final face = p.dx > .27 && p.dx < .73 && p.dy > .27 && p.dy < .73
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
            painter: _PatientToothPainter(tooth),
          ),
        ),
        if (!tooth.isUpper)
          Text('${tooth.id}', style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}

class _PatientToothPainter extends CustomPainter {
  const _PatientToothPainter(this.tooth);
  final ToothModel tooth;
  Color color(String? s) => switch (s) {
    'issue' => const Color(0xFFEF4444),
    'restored' => const Color(0xFF0284C7),
    'planned' || 'crown_planned' => const Color(0xFFF59E0B),
    'crown_done' => const Color(0xFF0D9488),
    'endo_planned' => const Color(0xFFEC4899),
    'endo_done' => const Color(0xFF831843),
    'implant_planned' => const Color(0xFFA855F7),
    'implant_done' => const Color(0xFF581C87),
    'missing' => const Color(0xFF303640),
    _ => const Color(0xFF181C22),
  };
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final a = w * .27, b = w * .73;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF767D8A)
      ..strokeWidth = .8;
    void face(ToothFace f, List<Offset> points) {
      final p = Path()..addPolygon(points, true);
      canvas.drawPath(p, Paint()..color = color(tooth.facesStatus[f.name]));
      canvas.drawPath(p, stroke);
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
    final root = tooth.facesStatus[ToothFace.root.name];
    if (root != null || tooth.isMissing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-4, -4, w + 8, w + 8),
          const Radius.circular(5),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = color(root ?? 'missing'),
      );
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
                  const Icon(
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
          color: const Color(0xFF11151D),
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
            color: const Color(0xFF2B251A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
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
                  for (final e in const <(Color, String)>[
                    (Color(0xFFEC4899), 'Endo (Planej.)'),
                    (Color(0xFF831843), 'Endo (Realiz.)'),
                    (Color(0xFFA855F7), 'Implante (Planej.)'),
                    (Color(0xFF581C87), 'Implante (Realiz.)'),
                    (Color(0xFFF59E0B), 'Coroa (Planej.)'),
                    (Color(0xFF0D9488), 'Coroa (Realiz.)'),
                    (Color(0xFFEF4444), 'Cárie'),
                    (Color(0xFF0284C7), 'Restaurado'),
                    (Color(0xFFF59E0B), 'A realizar (Face)'),
                    (Color(0xFF303640), 'Extraído'),
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
    style: const TextStyle(
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
                color: const Color(0xFF263650),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
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
                  const Text(
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
                        style: const TextStyle(color: Color(0xFFFFB4AB)),
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
    color: const Color(0xFF20252B),
  );
}
