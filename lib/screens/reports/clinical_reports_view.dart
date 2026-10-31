import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/oracle_report_service.dart';
import '../../models/financial_model.dart';
import '../../utils/display.dart';
import '../../utils/report_export.dart';
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

class ClinicalReportsView extends StatefulWidget {
  const ClinicalReportsView({
    super.key,
    required this.month,
    required this.clinicName,
    required this.snapshot,
    required this.receivables,
    required this.onMonth,
    required this.onRefresh,
    required this.onExport,
    required this.onExpense,
    required this.onIncome,
    required this.onAnticipate,
    required this.onEntry,
    required this.onCashbook,
    this.loading = false,
    this.error,
    this.receivablesError,
    this.onManageExpenses,
    this.onReceitaSaude,
  });
  final DateTime month;
  final String clinicName;
  final OracleReportSnapshot snapshot;
  final List<ReportDocument> receivables;
  final VoidCallback? onManageExpenses, onReceitaSaude;
  final ValueChanged<int> onMonth;
  final VoidCallback onRefresh,
      onExport,
      onExpense,
      onIncome,
      onAnticipate,
      onCashbook;
  final void Function(TransactionItem, String) onEntry;
  final bool loading;
  final String? error, receivablesError;
  @override
  State<ClinicalReportsView> createState() => _ClinicalReportsViewState();
}

class _ClinicalReportsViewState extends State<ClinicalReportsView> {
  int _tab = 0;
  String _search = '';
  String? _category;
  bool _matches(TransactionItem t) =>
      (_category == null || reportCategory(t) == _category) &&
      (_search.isEmpty ||
          '${t.title} ${t.details['title'] ?? ''} ${t.details['description'] ?? ''} ${t.details['supplierName'] ?? ''} ${t.details['dentistName'] ?? ''}'
              .toLowerCase()
              .contains(_search));
  Color get _green => ClinicalAgendaStyle.accent;
  Color get _red => ClinicalAgendaStyle.danger;
  Color get _yellow => ClinicalAgendaStyle.warning;
  Widget _panel(Widget child, {Color? color, double padding = 16}) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color ?? ClinicalAgendaStyle.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );
  TextStyle get _muted =>
      TextStyle(fontSize: 11, color: ClinicalAgendaStyle.muted);

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final paid = s.transactions.where((t) => t.isPaid).toList();
    final income = paid.where((t) => t.isIncome).toList();
    final expenses = paid.where((t) => !t.isIncome).toList();
    final payable = s.transactions
        .where((t) => !t.isIncome && !t.isPaid)
        .toList();
    final available = widget.receivables
        .where((d) => reportCanAnticipate(d.data, DateTime.now()))
        .fold<double>(0, (sum, d) => sum + parseBRL(d.data['amount']));
    final categories = {
      for (final t in s.transactions) reportCategory(t),
      for (final d in widget.receivables)
        reportText(d.data['category'], fallback: 'Receita'),
    };
    if (_category != null) categories.add(_category!);
    return Theme(
      data: ClinicalCareStyle.forContext(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: ClinicalCareStyle.theme.filledButtonTheme.style!.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ClinicalCareStyle.theme.outlinedButtonTheme.style!.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(30, 30),
            padding: const EdgeInsets.all(6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: ClinicalAgendaStyle.text,
        ),
        child: ColoredBox(
          color: ClinicalAgendaStyle.background,
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 620;
              final ready = !widget.loading && widget.error == null;
              final monthControl = Container(
                decoration: BoxDecoration(
                  color: ClinicalAgendaStyle.elevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Mês anterior',
                      onPressed: () => widget.onMonth(-1),
                      icon: const Icon(Icons.chevron_left, size: 20),
                    ),
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: _green,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        reportMonthLabel(widget.month).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _badge('PERÍODO', _green),
                    IconButton(
                      tooltip: 'Próximo mês',
                      onPressed: () => widget.onMonth(1),
                      icon: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ],
                ),
              );
              final headerLeft = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: _green,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Financeiro  ›  DRE & Livro Caixa Gerencial',
                          style: TextStyle(
                            color: _green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  monthControl,
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ClinicalAgendaStyle.elevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: _green,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Unidade: ${widget.clinicName}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final headerActions = Column(
                crossAxisAlignment: narrow
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: ready ? widget.onExport : null,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Exportar DRE'),
                      ),
                      if (widget.onReceitaSaude != null)
                        OutlinedButton.icon(
                          key: const ValueKey('report-receita-saude'),
                          onPressed: widget.onReceitaSaude,
                          icon: const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 16,
                          ),
                          label: const Text('Receita Saúde'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _yellow.withValues(alpha: .16),
                      foregroundColor: _yellow,
                    ),
                    onPressed:
                        ready &&
                            widget.receivablesError == null &&
                            available > 0
                        ? widget.onAnticipate
                        : null,
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: Text(
                      'Antecipar Cartão  ${widget.receivablesError == null ? reportMoney(available) : 'Indisponível'}',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _red.withValues(alpha: .15),
                          foregroundColor: _red,
                        ),
                        onPressed: widget.onExpense,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Nova Despesa'),
                      ),
                      FilledButton.icon(
                        onPressed: widget.onIncome,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Novo Lançamento'),
                      ),
                    ],
                  ),
                ],
              );
              return SingleChildScrollView(
                padding: EdgeInsets.all(narrow ? 12 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _panel(
                      narrow
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                headerLeft,
                                const SizedBox(height: 16),
                                headerActions,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: headerLeft),
                                const SizedBox(width: 20),
                                Expanded(child: headerActions),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    _panel(
                      Row(
                        children: [
                          Icon(
                            widget.error == null
                                ? Icons.insights_outlined
                                : Icons.error_outline,
                            size: 20,
                            color: widget.error == null ? _green : _red,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.error ??
                                  (widget.loading
                                      ? 'Apurando os lançamentos do período…'
                                      : 'Dados do período apurados a partir dos registros do sistema. Conciliação bancária não informada.'),
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.error == null
                                    ? ClinicalAgendaStyle.text
                                    : _red,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Atualizar relatório',
                            onPressed: widget.onRefresh,
                            icon: const Icon(Icons.refresh, size: 16),
                          ),
                        ],
                      ),
                      color: (widget.error == null ? _green : _red).withValues(
                        alpha: .10,
                      ),
                      padding: 10,
                    ),
                    if (widget.loading) const LinearProgressIndicator(),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, k) {
                        final columns = k.maxWidth >= 700
                            ? 4
                            : k.maxWidth >= 440
                            ? 2
                            : 1;
                        final width =
                            (k.maxWidth - (columns - 1) * 12) / columns;
                        final cards = [
                          _metric(
                            'Receita Realizada\n(Caixa • bruto)',
                            s.totalRevenue,
                            _green,
                            Icons.payments_outlined,
                            '${income.length} lançamentos recebidos',
                          ),
                          _metric(
                            'Despesas Pagas\n(Saídas)',
                            s.totalExpenses,
                            _red,
                            Icons.receipt_long_outlined,
                            'Laboratório: ${reportMoney(expenses.where((t) => reportCategory(t).toLowerCase().contains('laborat')).fold<double>(0, (v, t) => v + t.amount))}',
                          ),
                          _metric(
                            'Disponível p/\nAntecipar',
                            available,
                            _yellow,
                            Icons.flash_on,
                            'Bruto · próximos 12 meses',
                            onTap:
                                ready &&
                                    available > 0 &&
                                    widget.receivablesError == null
                                ? widget.onAnticipate
                                : null,
                            unknown: widget.receivablesError != null,
                          ),
                          _metric(
                            'LUCRO LÍQUIDO\n(Caixa)',
                            s.netProfit,
                            ClinicalAgendaStyle.blue,
                            Icons.account_balance_outlined,
                            s.totalRevenue > 0
                                ? 'Margem operacional: ${s.profitMargin.toStringAsFixed(2).replaceAll('.', ',')}%'
                                : 'Margem não apurada',
                            highlight: true,
                          ),
                        ];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final card in cards)
                              SizedBox(width: width, child: card),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _panel(
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.query_stats, color: _green, size: 22),
                          Text(
                            'Previsão para Fechamento de ${reportMonths[widget.month.month - 1]}:',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Caixa do período + recebíveis − contas a pagar',
                            style: _muted,
                          ),
                          Text(
                            ready ? reportMoney(s.projectedBalance) : '—',
                            key: const ValueKey('report-projection'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tab in [
                                (
                                  Icons.menu_book_outlined,
                                  'Livro Caixa / DRE Agrupado',
                                ),
                                (
                                  Icons.stacked_bar_chart,
                                  'Fluxo de Caixa Real',
                                ),
                                (
                                  Icons.request_quote_outlined,
                                  'Contas a Pagar',
                                ),
                                (
                                  Icons.credit_card,
                                  'Recebíveis & Antecipações',
                                ),
                              ].indexed)
                                TextButton.icon(
                                  key: ValueKey('report-tab-${tab.$1}'),
                                  onPressed: () =>
                                      setState(() => _tab = tab.$1),
                                  style: TextButton.styleFrom(
                                    backgroundColor: _tab == tab.$1
                                        ? ClinicalAgendaStyle.elevated
                                        : Colors.transparent,
                                    foregroundColor: _tab == tab.$1
                                        ? _green
                                        : ClinicalAgendaStyle.text,
                                  ),
                                  icon: Icon(tab.$2.$1, size: 16),
                                  label: Text(
                                    '${tab.$2.$2}${tab.$1 == 2 ? '  ${payable.length}' : ''}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: math.min(310, c.maxWidth - 64),
                                child: TextField(
                                  key: const ValueKey('report-search'),
                                  onChanged: (v) => setState(
                                    () => _search = v.toLowerCase().trim(),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Filtrar por paciente ou conta…',
                                    prefixIcon: Icon(
                                      Icons.filter_alt_outlined,
                                      size: 16,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: math.min(230, c.maxWidth - 64),
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('report-category-$_category'),
                                  initialValue: _category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'Todas as Categorias',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    for (final category in categories)
                                      DropdownMenuItem(
                                        value: category,
                                        child: Text(
                                          category,
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _category = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      padding: 10,
                    ),
                    const SizedBox(height: 18),
                    if (!ready)
                      _panel(
                        Text(
                          widget.error ?? 'Carregando valores…',
                          textAlign: TextAlign.center,
                          style: _muted,
                        ),
                      )
                    else if (_tab == 0) ...[
                      _group(
                        '1. RECEITAS OPERACIONAIS (ENTRADAS)',
                        'Procedimentos e recebimentos registrados no período',
                        income.where(_matches).toList(),
                        true,
                        s.totalRevenue,
                      ),
                      const SizedBox(height: 20),
                      _group(
                        '2. DESPESAS OPERACIONAIS E CUSTOS (SAÍDAS)',
                        'Laboratório, repasses e demais despesas registradas e pagas',
                        expenses.where(_matches).toList(),
                        false,
                        s.totalExpenses,
                      ),
                    ] else if (_tab == 1) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: widget.onCashbook,
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 16,
                          ),
                          label: const Text('Livro Caixa / PDF'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _cash(paid),
                    ] else if (_tab == 2) ...[
                      if (widget.onManageExpenses != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: widget.onManageExpenses,
                            icon: const Icon(Icons.edit_note),
                            label: const Text(
                              'Gerenciar despesas e recorrências',
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _group(
                        'CONTAS A PAGAR',
                        'Pendências do mês selecionado, incluindo os custos de laboratório',
                        payable.where(_matches).toList(),
                        false,
                        payable.fold(
                          0.0,
                          (sum, t) =>
                              sum + math.max(0, t.amount - t.paidAmount),
                        ),
                        pending: true,
                      ),
                    ] else
                      _receivableList(),
                    const SizedBox(height: 14),
                    Text(
                      'Base do resultado: valores brutos recebidos menos despesas pagas. Valores líquidos são exibidos apenas quando registrados. O saldo projetado não inclui saldo bancário inicial.',
                      style: _muted,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    double value,
    Color color,
    IconData icon,
    String footer, {
    bool highlight = false,
    bool unknown = false,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: highlight
            ? ClinicalAgendaStyle.blue.withValues(alpha: .09)
            : ClinicalAgendaStyle.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 11, height: 1.3),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.loading || widget.error != null || unknown
                      ? '—'
                      : reportMoney(value),
                  key: ValueKey('report-kpi-$label'),
                  style: TextStyle(
                    color: color,
                    fontSize: highlight ? 24 : 27,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: ClinicalAgendaStyle.background.withValues(alpha: .45),
            child: Text(footer, style: TextStyle(fontSize: 10, color: color)),
          ),
        ],
      ),
    ),
  );

  Widget _group(
    String title,
    String description,
    List<TransactionItem> rows,
    bool income,
    double subtotal, {
    bool pending = false,
  }) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: ClinicalAgendaStyle.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: ClinicalAgendaStyle.elevated.withValues(alpha: .4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    income
                        ? Icons.arrow_circle_up_outlined
                        : Icons.arrow_circle_down_outlined,
                    color: income ? _green : _red,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(description, style: _muted),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                '${pending ? 'A PAGAR' : 'SUBTOTAL ${income ? 'BRUTO' : 'PAGO'}'}: ${reportMoney(subtotal)}',
                style: TextStyle(
                  color: income ? _green : _red,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _table(
          income
              ? [
                  'DATA / HORÁRIO',
                  'PACIENTE & PROCEDIMENTO',
                  'PROFISSIONAL TÉCNICO',
                  'FORMA / PARCELAS',
                  'STATUS REGISTRADO',
                  'BRUTO / LÍQUIDO',
                  'AÇÕES',
                ]
              : [
                  'VENCIMENTO / BAIXA',
                  'FORNECEDOR / DESCRIÇÃO DA DESPESA',
                  'CENTRO DE CUSTO',
                  'FORMA DE LIQUIDAÇÃO',
                  'STATUS',
                  pending ? 'SALDO A PAGAR' : 'VALOR PAGO',
                  'AÇÕES',
                ],
          [
            for (final t in rows)
              [
                _dateCell(t, pending),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      income
                          ? t.title
                          : reportText(
                              t.details['supplierName'],
                              fallback: 'Fornecedor não informado',
                            ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reportDescription(t),
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (income && t.patientId?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      _badge('Paciente vinculado', ClinicalAgendaStyle.muted),
                    ],
                  ],
                ),
                income
                    ? Text(
                        reportText(t.details['dentistName']),
                        style: const TextStyle(fontSize: 11),
                      )
                    : _badge(
                        reportCategory(t),
                        reportCategory(t).toLowerCase().contains('laborat')
                            ? _green
                            : ClinicalAgendaStyle.muted,
                      ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reportMethod(t)}${t.details['installmentNumber'] != null ? ' (${t.details['installmentNumber']})' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (income &&
                        reportCanAnticipate(t.details, DateTime.now()))
                      Text(
                        'Disponível p/ antecipação',
                        style: TextStyle(color: _yellow, fontSize: 10),
                      ),
                  ],
                ),
                _badge(
                  t.isPaid ? (income ? 'Recebido' : 'Pago') : 'Pendente',
                  t.isPaid ? _green : _yellow,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportMoney(
                        pending
                            ? math.max(0, t.amount - t.paidAmount)
                            : t.amount,
                      ),
                      style: TextStyle(
                        color: income ? _green : _red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (income)
                      Text(
                        reportNet(t) == null
                            ? 'Líquido não informado'
                            : 'Líquido: ${reportMoney(reportNet(t)!)}',
                        style: _muted,
                      ),
                  ],
                ),
                IconButton(
                  tooltip: pending ? 'Baixar pagamento' : 'Ver lançamento',
                  onPressed: () =>
                      widget.onEntry(t, pending ? 'pay' : 'details'),
                  icon: Icon(
                    pending ? Icons.check_circle_outline : Icons.more_horiz,
                    size: 18,
                  ),
                ),
              ],
          ],
        ),
      ],
    ),
  );

  Widget _dateCell(TransactionItem t, bool pending) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        formatDateFull(pending ? t.dueDate : t.date),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      if (t.date.hour != 0 || t.date.minute != 0)
        Text(
          '${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}',
          style: _muted,
        ),
    ],
  );
  Widget _table(List<String> headers, List<List<Widget>> rows) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(760, c.maxWidth),
        child: Table(
          columnWidths: {
            for (var i = 0; i < headers.length; i++)
              i: FlexColumnWidth(
                i == 1
                    ? 1.7
                    : i == headers.length - 1
                    ? 0.5
                    : 1.15,
              ),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: ClinicalAgendaStyle.background.withValues(alpha: .7),
              ),
              children: [
                for (final h in headers)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4,
                        color: ClinicalAgendaStyle.text,
                      ),
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ClinicalAgendaStyle.elevated.withValues(alpha: .3),
                    ),
                  ),
                ),
                children: [
                  for (final cell in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: cell,
                    ),
                ],
              ),
            if (rows.isEmpty)
              TableRow(
                children: [
                  for (var i = 0; i < headers.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        i == 1 ? 'Nenhum lançamento encontrado' : '',
                        style: _muted,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  Widget _cash(List<TransactionItem> paid) {
    final all = List<TransactionItem>.from(paid)
      ..sort((a, b) => a.date.compareTo(b.date));
    double balance = 0;
    final balances = <String, double>{};
    for (final t in all) {
      balance += t.isIncome ? t.amount : -t.amount;
      balances['${t.isIncome}:${t.id}'] = balance;
    }
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FLUXO DE CAIXA REAL',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Movimentações pagas do mês; acumulado a partir de zero, sem saldo bancário inicial cadastrado.',
            style: _muted,
          ),
          const SizedBox(height: 14),
          _table(
            [
              'DATA',
              'TIPO',
              'DESCRIÇÃO / CONTA',
              'FORMA',
              'VALOR',
              'SALDO DO PERÍODO',
            ],
            [
              for (final t in all.where(_matches))
                [
                  _dateCell(t, false),
                  _badge(
                    t.isIncome ? 'Entrada' : 'Saída',
                    t.isIncome ? _green : _red,
                  ),
                  Text(t.title, style: const TextStyle(fontSize: 12)),
                  Text(reportMethod(t), style: _muted),
                  Text(
                    '${t.isIncome ? '+' : '−'} ${reportMoney(t.amount)}',
                    style: TextStyle(
                      color: t.isIncome ? _green : _red,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    reportMoney(balances['${t.isIncome}:${t.id}']!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
            ],
          ),
        ],
      ),
      padding: 16,
    );
  }

  Widget _receivableList() {
    final docs = <String, TransactionItem>{
      for (final t in widget.snapshot.transactions)
        if (t.isIncome && !t.isPaid) t.id: t,
    };
    for (final d in widget.receivables) {
      final data = d.data;
      final date = reportDate(data['dueDate']) ?? reportDate(data['date']);
      if (date == null) continue;
      docs.putIfAbsent(
        d.id,
        () => TransactionItem(
          id: d.id,
          title: '${data['patientName'] ?? data['title'] ?? 'Receita avulsa'}',
          amount: parseBRL(data['amount']),
          date: date,
          dueDate: date,
          isIncome: true,
          isPaid:
              reportAnticipated(data) ||
              data['isPaid'] == true ||
              FinancialModel.isPaidOf(
                status: '${data['status'] ?? ''}',
                paidAmount: data['paidAmount'],
                amount: data['amount'],
              ),
          category: 'Receita',
          details: data,
        ),
      );
    }
    final rows = docs.values.where(_matches).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RECEBÍVEIS & ANTECIPAÇÕES',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            widget.receivablesError ??
                'Pendências do período e cartões dos próximos 12 meses. A antecipação exige simulação e confirmação.',
            style: _muted,
          ),
          const SizedBox(height: 14),
          _table(
            [
              'VENCIMENTO',
              'PACIENTE / CONTA',
              'PROCEDIMENTO',
              'FORMA',
              'STATUS',
              'VALOR BRUTO',
              'AÇÃO',
            ],
            [
              for (final t in rows)
                [
                  _dateCell(t, true),
                  Text(t.title, style: const TextStyle(fontSize: 12)),
                  Text(
                    reportDescription(t),
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(reportMethod(t), style: _muted),
                  _badge(
                    reportAnticipated(t.details)
                        ? 'Antecipado'
                        : t.isPaid
                        ? 'Recebido'
                        : 'Programado',
                    t.isPaid ? _green : _yellow,
                  ),
                  Text(
                    reportMoney(t.amount),
                    style: TextStyle(
                      color: _yellow,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    tooltip: reportCanAnticipate(t.details, DateTime.now())
                        ? 'Simular antecipação'
                        : 'Ver lançamento',
                    onPressed: () =>
                        reportCanAnticipate(t.details, DateTime.now())
                        ? widget.onAnticipate()
                        : widget.onEntry(t, 'details'),
                    icon: Icon(
                      reportCanAnticipate(t.details, DateTime.now())
                          ? Icons.flash_on
                          : Icons.more_horiz,
                      size: 18,
                    ),
                  ),
                ],
            ],
          ),
        ],
      ),
      padding: 16,
    );
  }
}
