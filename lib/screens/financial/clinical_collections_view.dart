import '../../utils/report_export.dart' show reportMoney;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/collection_queue.dart';
import '../../utils/display.dart';
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

class ClinicalCollectionsView extends StatefulWidget {
  const ClinicalCollectionsView({
    super.key,
    required this.month,
    required this.queue,
    required this.onMonth,
    required this.onExport,
    required this.onBatch,
    required this.onCopy,
    required this.onSend,
    required this.onReceive,
    required this.onReschedule,
    required this.onPatient,
    required this.onRetry,
    this.loading = false,
    this.busy = false,
    this.error,
  });
  final DateTime month;
  final CollectionQueue queue;
  final ValueChanged<int> onMonth;
  final void Function(List<CollectionCharge>, String?) onExport;
  final ValueChanged<List<CollectionCharge>> onBatch;
  final ValueChanged<CollectionCharge> onCopy,
      onSend,
      onReceive,
      onReschedule,
      onPatient;
  final VoidCallback onRetry;
  final bool loading, busy;
  final String? error;
  @override
  State<ClinicalCollectionsView> createState() =>
      _ClinicalCollectionsViewState();
}

class _ClinicalCollectionsViewState extends State<ClinicalCollectionsView> {
  final _search = TextEditingController();
  final _inspectorKey = GlobalKey();
  String? _clinic, _selected;
  static Color get _text => ClinicalAgendaStyle.text;
  static Color get _muted => ClinicalAgendaStyle.muted;
  static Color get _accent => ClinicalAgendaStyle.accent;
  static Color get _surface =>
      ClinicalAgendaStyle.tone(const Color(0xFF1C2026), Colors.white);
  static Color get _low => ClinicalAgendaStyle.surface;
  bool get _ready => !widget.loading && widget.error == null;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
  );
  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
  Widget _box(Widget child, {Color? color, EdgeInsets? padding}) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? _surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
  Widget _icon(IconData icon, Color color, {double size = 44}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 24),
  );
  @override
  Widget build(BuildContext context) {
    final q = widget.queue.only(_clinic);
    final rows = q.charges.where((c) => c.matches(_search.text)).toList();
    final eligible = rows.where((c) => c.canContact(DateTime.now())).toList();
    final selected =
        rows.where((c) => c.key == _selected).firstOrNull ?? rows.firstOrNull;
    final monthLabel = DateFormat(
      'MMMM yyyy',
      'pt_BR',
    ).format(widget.month).toUpperCase();
    final current = DateTime.now();
    return Theme(
      data: ClinicalCareStyle.forContext(context).copyWith(
        dividerTheme: DividerThemeData(color: _muted.withValues(alpha: .13)),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: ClinicalAgendaStyle.background,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 940;
              final mobile = constraints.maxWidth < 600;
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('collections-export'),
                    onPressed: _ready && !widget.busy
                        ? () => widget.onExport(rows, _clinic)
                        : null,
                    icon: const Icon(Icons.download_outlined, size: 17),
                    label: const Text('Exportar Fechamento'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('collections-batch'),
                    onPressed: _ready && !widget.busy && eligible.isNotEmpty
                        ? () => widget.onBatch(eligible)
                        : null,
                    icon: const Icon(Icons.forward_to_inbox_outlined, size: 18),
                    label: Text('Disparar Lote Pendente (${eligible.length})'),
                  ),
                ],
              );
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(mobile ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: _accent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'MÓDULO FINANCEIRO · RÉGUA ATIVA',
                                      style: TextStyle(
                                        color: _accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Cobrança Manual Inteligente',
                                style: TextStyle(
                                  fontSize: mobile ? 24 : 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                  color: _text,
                                ),
                              ),
                            ],
                          ),
                          actions,
                        ],
                      ),
                      const SizedBox(height: 20),
                      _box(
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Mês anterior',
                              key: const ValueKey('collections-prev'),
                              onPressed: widget.busy
                                  ? null
                                  : () => widget.onMonth(-1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    color: _accent,
                                    size: 21,
                                  ),
                                  Text(
                                    monthLabel,
                                    style: TextStyle(
                                      fontSize: mobile ? 15 : 19,
                                      fontWeight: FontWeight.w600,
                                      color: _text,
                                    ),
                                  ),
                                  if (current.year == widget.month.year &&
                                      current.month == widget.month.month)
                                    _chip('COMPETÊNCIA ATUAL', _accent),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Próximo mês',
                              key: const ValueKey('collections-next'),
                              onPressed: widget.busy
                                  ? null
                                  : () => widget.onMonth(1),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        color: _low,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _box(
                        LayoutBuilder(
                          builder: (context, c) {
                            final heading = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _icon(Icons.hub_outlined, _accent),
                                const SizedBox(width: 16),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('FILTRAR PROTOCOLO POR UNIDADE'),
                                      const SizedBox(height: 4),
                                      Text(
                                        _clinic == null
                                            ? 'Todas as Unidades (Modo Híbrido)'
                                            : widget.queue.clinics
                                                      .where(
                                                        (c) => c.id == _clinic,
                                                      )
                                                      .firstOrNull
                                                      ?.name ??
                                                  'Unidade indisponível',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: _text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                            final tabs = _box(
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ChoiceChip(
                                    key: const ValueKey('collections-unit-all'),
                                    showCheckmark: false,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side: BorderSide.none,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    label: const Text('Todas as Unidades'),
                                    selected: _clinic == null,
                                    onSelected: widget.busy
                                        ? null
                                        : (_) => setState(() {
                                            _clinic = null;
                                            _selected = null;
                                          }),
                                  ),
                                  for (final clinic in widget.queue.clinics)
                                    ChoiceChip(
                                      key: ValueKey(
                                        'collections-unit-${clinic.id}',
                                      ),
                                      label: Text(
                                        '${clinic.name} (${clinic.protocol})',
                                      ),
                                      avatar: Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: clinic.psychology
                                            ? ClinicalAgendaStyle.blue
                                            : _accent,
                                      ),
                                      selected: _clinic == clinic.id,
                                      onSelected: widget.busy
                                          ? null
                                          : (_) => setState(() {
                                              _clinic = clinic.id;
                                              _selected = null;
                                            }),
                                    ),
                                ],
                              ),
                              color: _low,
                              padding: const EdgeInsets.all(5),
                            );
                            return c.maxWidth >= 850
                                ? Row(
                                    children: [
                                      SizedBox(width: 310, child: heading),
                                      const SizedBox(width: 16),
                                      Expanded(child: tabs),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      heading,
                                      const SizedBox(height: 14),
                                      tabs,
                                    ],
                                  );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.loading)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (widget.error != null)
                        _box(
                          Column(
                            children: [
                              Text(
                                widget.error!,
                                style: TextStyle(
                                  color: ClinicalAgendaStyle.danger,
                                ),
                              ),
                              TextButton(
                                onPressed: widget.onRetry,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        LayoutBuilder(
                          builder: (context, c) {
                            final cards = [
                              _kpi(
                                'TOTAL EM ABERTO / PENDENTE',
                                reportMoney(q.pending),
                                '${q.patients} pacientes · ${q.charges.length} cobranças',
                                Icons.pending_actions,
                                ClinicalAgendaStyle.danger,
                                detail: q.charges.any((c) => c.issue != null)
                                    ? 'Há cálculos indisponíveis, excluídos do total.'
                                    : 'Aguardando confirmação Pix ou balcão',
                              ),
                              _kpi(
                                'CONTATOS WHATSAPP CONFIRMADOS',
                                '${q.contacts} confirmados',
                                'Na competência desta fila',
                                Icons.chat_outlined,
                                _accent,
                                detail:
                                    'Envio manual · confirmação do operador',
                              ),
                              _kpi(
                                'LIQUIDADO NESTE MÊS',
                                reportMoney(q.settled),
                                '${q.settledCount} lançamentos liquidados',
                                Icons.check_circle_outline,
                                ClinicalAgendaStyle.blue,
                                detail: 'Mesma base de caixa dos Relatórios',
                              ),
                            ];
                            return c.maxWidth >= 700
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < cards.length;
                                        i++
                                      ) ...[
                                        if (i > 0) const SizedBox(width: 16),
                                        Expanded(child: cards[i]),
                                      ],
                                    ],
                                  )
                                : Column(
                                    children: [
                                      for (final card in cards)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: card,
                                        ),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 42,
                          child: TextField(
                            key: const ValueKey('collections-search'),
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar prontuário, fatura ou paciente…',
                              hintStyle: TextStyle(color: _muted, fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: _low,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpar busca',
                                      onPressed: () {
                                        _search.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _queue(rows, mobile: false)),
                              const SizedBox(width: 24),
                              SizedBox(width: 310, child: _inspector(selected)),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _queue(rows, mobile: mobile),
                              const SizedBox(height: 20),
                              _inspector(selected),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kpi(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    required String detail,
  }) => _box(
    ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 130),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(label),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(subtitle, style: TextStyle(color: _text, fontSize: 12)),
                const SizedBox(height: 6),
                Text(detail, style: TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _icon(icon, color, size: 48),
        ],
      ),
    ),
    color: _low,
  );
  Widget _queue(List<CollectionCharge> rows, {required bool mobile}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 10,
        runSpacing: 6,
        children: [
          Text(
            'FILA DE COBRANÇA ATIVA (${DateFormat('MMMM', 'pt_BR').format(widget.month).toUpperCase()})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
          Text(
            'Selecione para abrir régua de envio',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        _box(
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 42, color: _accent),
                const SizedBox(height: 10),
                Text(
                  'Nenhuma cobrança nesta seleção.',
                  style: TextStyle(color: _text),
                ),
              ],
            ),
          ),
        ),
      for (final charge in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: ValueKey('collection-${charge.key}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() => _selected = charge.key);
                if (MediaQuery.sizeOf(context).width < 940) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final c = _inspectorKey.currentContext;
                    if (c != null) {
                      Scrollable.ensureVisible(
                        c,
                        duration: const Duration(milliseconds: 250),
                      );
                    }
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _icon(
                      charge.isPackage
                          ? Icons.psychology_outlined
                          : charge.clinic.psychology
                          ? Icons.event_available_outlined
                          : Icons.chat_outlined,
                      charge.clinic.psychology
                          ? ClinicalAgendaStyle.blue
                          : _accent,
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
                                charge.patientName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _text,
                                ),
                              ),
                              _chip(
                                charge.badge,
                                charge.clinic.psychology
                                    ? ClinicalAgendaStyle.blue
                                    : _accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${charge.description} · Vence: ${charge.dueDate == null ? 'Não informado' : formatDateFull(charge.dueDate!)}',
                            maxLines: mobile ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: _text),
                          ),
                          if (mobile) ...[
                            const SizedBox(height: 7),
                            Text(
                              charge.issue != null
                                  ? 'Cálculo indisponível'
                                  : reportMoney(charge.amount),
                              style: TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (charge.contactedToday ||
                              charge.nextContact != null ||
                              charge.paymentNoticed)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                charge.paymentNoticed
                                    ? 'Paciente avisou que pagou · conferir baixa'
                                    : charge.nextContact != null
                                    ? 'Lembrete adiado: ${formatDateFull(charge.nextContact!)}'
                                    : 'Contato confirmado hoje',
                                style: TextStyle(fontSize: 11, color: _accent),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!mobile) ...[
                      const SizedBox(width: 12),
                      Text(
                        charge.issue != null ? '—' : reportMoney(charge.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _text,
                        ),
                      ),
                    ],
                    IconButton(
                      key: ValueKey('collection-patient-${charge.key}'),
                      tooltip: 'Abrir paciente em Pagamentos',
                      onPressed: widget.busy
                          ? null
                          : () => widget.onPatient(charge),
                      icon: Icon(
                        Icons.person_outline,
                        size: 18,
                        color: ClinicalAgendaStyle.blue,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: _muted),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
  Widget _inspector(CollectionCharge? charge) => Column(
    key: _inspectorKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _box(
        charge == null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Selecione uma cobrança para consultar a régua.',
                  style: TextStyle(color: _muted),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy_outlined, color: _accent, size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Régua de Cobrança',
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _chip('Unidade ${charge.clinic.name}', _accent),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _box(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          children: [
                            _label('PACIENTE SELECIONADO'),
                            _chip(
                              _dueLabel(charge),
                              ClinicalAgendaStyle.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          charge.patientName,
                          key: const ValueKey('collection-selected-name'),
                          style: TextStyle(
                            color: _text,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          charge.description,
                          style: TextStyle(color: _text, fontSize: 12),
                        ),
                        if (charge.bill != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${charge.bill!.describe()}${charge.bill!.isPartial ? ' · Parcial' : ''}',
                              style: TextStyle(
                                color: ClinicalAgendaStyle.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const Divider(height: 25),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 5,
                          children: [
                            Text(
                              'Valor a liquidar:',
                              style: TextStyle(color: _text, fontSize: 12),
                            ),
                            Text(
                              charge.issue != null
                                  ? 'Indisponível'
                                  : reportMoney(charge.amount),
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    color: _surface,
                  ),
                  const SizedBox(height: 16),
                  if (charge.issue != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        charge.issue!,
                        style: TextStyle(
                          color: ClinicalAgendaStyle.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _label('PRÉVIA DO TEXTO (WHATSAPP CLÍNICO)'),
                      TextButton.icon(
                        key: const ValueKey('collection-copy'),
                        onPressed: widget.busy || charge.issue != null
                            ? null
                            : () => widget.onCopy(charge),
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text(
                          'Copiar Texto',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  _box(
                    SelectableText(
                      charge.issue != null
                          ? 'A prévia estará disponível após corrigir o cálculo.'
                          : charge.message(DateTime.now()),
                      style: TextStyle(fontSize: 12, height: 1.7, color: _text),
                    ),
                    color: _surface,
                    padding: const EdgeInsets.all(12),
                  ),
                  if (charge.clinic.pixKey.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Pix não configurado nesta unidade. Mensagem sem código Pix.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  if (charge.clinic.pixKey.isNotEmpty &&
                      charge.clinic.city.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Cidade não cadastrada: será enviada a chave Pix, sem BR Code.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  if (collectionPhone(charge.phone).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Telefone ausente ou inválido. Atualize o cadastro para enviar.',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('collection-send'),
                    onPressed: widget.busy || !charge.canContact(DateTime.now())
                        ? null
                        : () => widget.onSend(charge),
                    icon: const Icon(Icons.send_outlined, size: 20),
                    label: Text(
                      charge.contactedToday
                          ? 'Contato confirmado hoje'
                          : charge.nextContact?.isAfter(DateTime.now()) == true
                          ? 'Lembrete adiado'
                          : charge.clinic.pixKey.isEmpty
                          ? 'Disparar WhatsApp'
                          : 'Disparar WhatsApp c/ Pix Inteligente',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('collection-receive'),
                          onPressed:
                              widget.busy ||
                                  charge.issue != null ||
                                  charge.amount <= 0
                              ? null
                              : () => widget.onReceive(charge),
                          icon: Icon(
                            Icons.point_of_sale,
                            size: 17,
                            color: _accent,
                          ),
                          label: const Text(
                            'Receber no\nBalcão',
                            textAlign: TextAlign.center,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 52),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('collection-reschedule'),
                          onPressed: widget.busy || charge.issue != null
                              ? null
                              : () => widget.onReschedule(charge),
                          icon: const Icon(Icons.schedule, size: 17),
                          label: const Text(
                            'Reagendar\nNotif.',
                            textAlign: TextAlign.center,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 52),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        color: _low,
      ),
      const SizedBox(height: 16),
      _box(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 21, color: ClinicalAgendaStyle.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Regra de Negócio Multi-Clínica',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Psicologia: pacote mensal rateado pelas sessões previstas; só sessões finalizadas e faltas sem atestado são cobráveis. Desconto de terceiro antes do rateio. Avulsas ficam separadas.\n\nOdontologia: cobrança direta do saldo do procedimento/parcela. Contato confirmado não é pagamento.',
                    style: TextStyle(fontSize: 12, height: 1.55, color: _text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
  String _dueLabel(CollectionCharge c) {
    final d = c.dueDate;
    if (d == null) return 'SEM VENCIMENTO';
    final n = DateTime.now();
    final days = DateTime(
      n.year,
      n.month,
      n.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    return days > 0
        ? 'VENCIDO HÁ $days DIAS'
        : days == 0
        ? 'VENCE HOJE'
        : 'VENCE EM ${formatDateShort(d)}';
  }
}
