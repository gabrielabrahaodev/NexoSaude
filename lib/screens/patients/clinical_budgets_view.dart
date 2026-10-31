import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/budget_model.dart';
import '../../utils/display.dart';
import '../../utils/report_export.dart' show reportMoney;
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

class ClinicalBudgetsView extends StatefulWidget {
  const ClinicalBudgetsView({
    super.key,
    required this.budgets,
    required this.onNew,
    required this.onApprove,
    required this.onDelete,
    required this.onPrint,
    required this.onPrintAll,
    required this.onShare,
    required this.onTreatment,
    required this.onReceipt,
    this.plans = const {},
    this.loading = false,
    this.error,
    this.plansError,
    this.deleting = false,
  });
  final List<BudgetModel> budgets;
  final Map<String, Map<String, dynamic>> plans;
  final VoidCallback onNew;
  final ValueChanged<List<BudgetModel>> onPrintAll;
  final ValueChanged<BudgetModel> onApprove,
      onDelete,
      onPrint,
      onShare,
      onTreatment,
      onReceipt;
  final bool loading, deleting;
  final String? error, plansError;
  @override
  State<ClinicalBudgetsView> createState() => _ClinicalBudgetsViewState();
}

class _ClinicalBudgetsViewState extends State<ClinicalBudgetsView> {
  BudgetGroup _group = BudgetGroup.all;
  String _search = '';
  Color get _green => ClinicalAgendaStyle.accent;
  Color get _yellow => ClinicalAgendaStyle.warning;
  TextStyle get _muted =>
      TextStyle(fontSize: 11, color: ClinicalAgendaStyle.muted);
  bool _match(BudgetModel b) =>
      (_group == BudgetGroup.all || budgetGroup(b, DateTime.now()) == _group) &&
      (_search.isEmpty ||
          '${budgetTitle(b)} ${b.total} ${reportMoney(b.total)} ${b.items.map((i) => i['name']).join(' ')}'
              .toLowerCase()
              .contains(_search));
  Map<String, dynamic>? _plan(BudgetModel b) {
    final id = '${b.details['relatedPlanId'] ?? ''}';
    return widget.plans[id] ??
        widget.plans.values.where((p) => p['budgetId'] == b.id).firstOrNull;
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
  Widget _panel(Widget child, {Color? color, double padding = 16}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color ?? ClinicalAgendaStyle.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) {
    final visible = widget.budgets.where(_match).toList();
    final ready = !widget.loading && widget.error == null;
    return Theme(
      data: ClinicalCareStyle.forContext(context).copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ClinicalCareStyle.theme.outlinedButtonTheme.style!.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: ClinicalAgendaStyle.text,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('budget-new'),
                onPressed: widget.onNew,
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicalAgendaStyle.tone(
                    const Color(0xFF4D8EFF),
                    const Color(0xFF1565C0),
                  ),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'NOVO ORÇAMENTO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _panel(
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final choice in [
                      (BudgetGroup.all, 'Todos', ClinicalAgendaStyle.text),
                      (BudgetGroup.approved, 'Aprovados', _green),
                      (BudgetGroup.pending, 'Em Negociação', _yellow),
                      (
                        BudgetGroup.declined,
                        'Recusados / Expirados',
                        ClinicalAgendaStyle.muted,
                      ),
                    ])
                      TextButton(
                        key: ValueKey('budget-filter-${choice.$1.name}'),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: _group == choice.$1
                              ? ClinicalAgendaStyle.elevated
                              : Colors.transparent,
                          foregroundColor: ClinicalAgendaStyle.text,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => setState(() => _group = choice.$1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (choice.$1 != BudgetGroup.all) ...[
                              Icon(Icons.circle, size: 8, color: choice.$3),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              choice.$2,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ready
                                  ? '${choice.$1 == BudgetGroup.all ? widget.budgets.length : widget.budgets.where((b) => budgetGroup(b, DateTime.now()) == choice.$1).length}'
                                  : '—',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: math.min(250, c.maxWidth),
                      child: TextField(
                        key: const ValueKey('budget-search'),
                        onChanged: (v) =>
                            setState(() => _search = v.toLowerCase().trim()),
                        decoration: const InputDecoration(
                          hintText: 'Filtrar procedimentos…',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Imprimir orçamentos filtrados',
                      onPressed: ready && visible.isNotEmpty
                          ? () => widget.onPrintAll(visible)
                          : null,
                      icon: const Icon(Icons.print_outlined, size: 19),
                    ),
                  ],
                ),
              ),
              padding: 8,
            ),
            const SizedBox(height: 24),
            if (widget.loading)
              const LinearProgressIndicator()
            else if (widget.error != null)
              _panel(
                Text(
                  widget.error!,
                  style: TextStyle(color: ClinicalAgendaStyle.danger),
                ),
              )
            else if (visible.isEmpty)
              _panel(
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nenhum orçamento encontrado.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              if (widget.plansError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(widget.plansError!, style: _muted),
                ),
              for (final b in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _card(b),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BudgetModel b) {
    final group = budgetGroup(b, DateTime.now());
    final approved = group == BudgetGroup.approved;
    final pending = group == BudgetGroup.pending;
    final color = approved
        ? _green
        : pending
        ? _yellow
        : ClinicalAgendaStyle.muted;
    final plan = _plan(b);
    final complete =
        plan != null &&
        [
          'completed',
          'concluido',
          'concluído',
          'finalizado',
        ].contains('${plan['status']}'.toLowerCase());
    final valid = budgetDate(b.details['validUntil'] ?? b.details['expiresAt']);
    final responsible =
        '${b.details['responsibleName'] ?? b.details['dentistName'] ?? ''}';
    final conditions = '${b.details['paymentConditions'] ?? ''}';
    final installments = int.tryParse(
      '${b.details['suggestedInstallments'] ?? ''}',
    );
    final share = budgetLink(b.details['shareUrl'] ?? b.details['proposalUrl']);
    final receipt = budgetLink(b.details['receiptUrl'] ?? plan?['receiptUrl']);
    final subtitle = approved
        ? complete
              ? 'Tratamento concluído'
              : 'Proposta aprovada${plan == null ? ' • Vínculo de tratamento não localizado' : ' • Tratamento vinculado'}'
        : [
            if (b.dateKnown) 'Emitido: ${formatDateFull(b.date)}',
            if (valid != null) 'Válido até ${formatDateFull(valid)}',
            if (responsible.isNotEmpty) 'Responsável: $responsible',
            if ('${b.details['clinicName'] ?? ''}'.isNotEmpty)
              'Unidade ${b.details['clinicName']}',
          ].join(' • ');
    return Container(
      key: ValueKey('budget-card-${b.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ClinicalAgendaStyle.tone(const Color(0xFF1C2026), Colors.white),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            color: ClinicalAgendaStyle.tone(
              const Color(0xFF262A31),
              const Color(0xFFE8EDF4),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final title = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        approved
                            ? Icons.check_circle_outline
                            : pending
                            ? Icons.hourglass_top
                            : Icons.description_outlined,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                budgetTitle(b),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              _pill(
                                approved
                                    ? 'Aprovado'
                                    : pending
                                    ? 'Em Negociação'
                                    : group == BudgetGroup.declined
                                    ? 'Recusado / Expirado'
                                    : b.status,
                                color,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (subtitle.isNotEmpty)
                            Text(subtitle, style: _muted),
                          if (b.details['signedAt'] != null)
                            Text(
                              'Assinatura registrada em ${budgetDate(b.details['signedAt']) == null ? 'data não informada' : formatDateFull(budgetDate(b.details['signedAt'])!)}',
                              style: _muted,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
                final value = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          approved ? 'TOTAL APROVADO' : 'VALOR TOTAL',
                          style: TextStyle(
                            fontSize: 10,
                            color: ClinicalAgendaStyle.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reportMoney(b.total),
                          style: TextStyle(
                            color: color,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          approved
                              ? '${b.items.length} procedimento(s)'
                              : installments != null && installments > 1
                              ? 'em até ${installments}x de ${reportMoney(b.total / installments)}'
                              : '',
                          style: TextStyle(
                            color: approved ? ClinicalAgendaStyle.text : _green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: 'Excluir orçamento',
                      onPressed: widget.deleting
                          ? null
                          : () => widget.onDelete(b),
                      style: IconButton.styleFrom(
                        backgroundColor: ClinicalAgendaStyle.tone(
                          const Color(0xFF31353C),
                          const Color(0xFFDDE3EB),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                );
                return c.maxWidth < 740
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          title,
                          const SizedBox(height: 16),
                          Align(alignment: Alignment.centerRight, child: value),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 16),
                          value,
                        ],
                      );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: approved
                ? Column(
                    children: [
                      for (final item in b.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _approvedItem(
                            b,
                            BudgetItemDisplay(item),
                            plan != null,
                            receipt != null && complete,
                          ),
                        ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _table(b),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 340,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: _green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    conditions.isEmpty
                                        ? 'Condições de pagamento não informadas.'
                                        : 'Condições: $conditions',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Tooltip(
                                    message: share == null
                                        ? 'Link público não cadastrado para este orçamento'
                                        : 'Copiar link da proposta',
                                    child: OutlinedButton.icon(
                                      onPressed: share == null
                                          ? null
                                          : () => widget.onShare(b),
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        size: 15,
                                      ),
                                      label: const Text('Compartilhar Link'),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => widget.onPrint(b),
                                    icon: const Icon(
                                      Icons.print_outlined,
                                      size: 15,
                                    ),
                                    label: const Text('Imprimir Proposta'),
                                  ),
                                ],
                              ),
                              if (pending) ...[
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  key: ValueKey('budget-approve-${b.id}'),
                                  onPressed: () => widget.onApprove(b),
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 17,
                                  ),
                                  label: const Text(
                                    'Aprovar e Gerar Tratamento',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _approvedItem(
    BudgetModel b,
    BudgetItemDisplay item,
    bool linked,
    bool receipt,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: ClinicalAgendaStyle.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final name = Row(
          children: [
            BudgetProcedureIcon(size: 20, color: _green),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('Dente/Região: ${item.region}', style: _muted),
                ],
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              reportMoney(item.subtotal),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            OutlinedButton.icon(
              onPressed: receipt
                  ? () => widget.onReceipt(b)
                  : linked
                  ? () => widget.onTreatment(b)
                  : null,
              icon: Icon(
                receipt
                    ? Icons.receipt_long_outlined
                    : Icons.visibility_outlined,
                size: 14,
              ),
              label: Text(receipt ? 'Recibo' : 'Ver Tratamento'),
            ),
          ],
        );
        return c.maxWidth < 620
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  name,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              )
            : Row(
                children: [
                  Expanded(child: name),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
      },
    ),
  );
  Widget _table(BudgetModel b) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(760, c.maxWidth),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3.4),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(.5),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.2),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: ClinicalAgendaStyle.background.withValues(alpha: .6),
              ),
              children: [
                for (final label in [
                  'PROCEDIMENTO',
                  'DENTE / REGIÃO',
                  'QTD',
                  'VALOR UNITÁRIO',
                  'DESCONTO',
                  'SUBTOTAL',
                ])
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: ClinicalAgendaStyle.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            for (final raw in b.items)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ClinicalAgendaStyle.elevated.withValues(alpha: .4),
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        BudgetProcedureIcon(
                          color: ClinicalAgendaStyle.blue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            BudgetItemDisplay(raw).name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final value in [
                    BudgetItemDisplay(raw).region,
                    BudgetItemDisplay(
                      raw,
                    ).quantity.toString().replaceFirst(RegExp(r'\.0$'), ''),
                    reportMoney(BudgetItemDisplay(raw).unitPrice),
                    raw['discountAmount'] == null
                        ? '—'
                        : reportMoney(BudgetItemDisplay(raw).discount),
                    reportMoney(BudgetItemDisplay(raw).subtotal),
                  ])
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(value, style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class BudgetProcedureIcon extends StatelessWidget {
  const BudgetProcedureIcon({super.key, required this.color, this.size = 20});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _BudgetToothPainter(color));
}

class _BudgetToothPainter extends CustomPainter {
  const _BudgetToothPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 20, size.height / 20);
    final path = Path()
      ..moveTo(10, 4)
      ..cubicTo(7, 1, 3, 2, 3, 6)
      ..cubicTo(3, 9, 4, 10, 4.5, 13)
      ..cubicTo(5, 17, 5.5, 18, 6.5, 18)
      ..cubicTo(8, 18, 7.5, 12, 10, 12)
      ..cubicTo(12.5, 12, 12, 18, 13.5, 18)
      ..cubicTo(14.5, 18, 15, 17, 15.5, 13)
      ..cubicTo(16, 10, 17, 9, 17, 6)
      ..cubicTo(17, 2, 13, 1, 10, 4)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BudgetToothPainter old) => old.color != color;
}
