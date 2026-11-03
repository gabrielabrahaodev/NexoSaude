import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/patient_list_entry.dart';
import '../../services/oracle_report_service.dart' show reportDate;
import '../../utils/display.dart';
import '../../utils/report_export.dart' show reportMoney;
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

class ClinicalPatientListView extends StatefulWidget {
  const ClinicalPatientListView({
    super.key,
    required this.patients,
    required this.contextData,
    required this.onOpen,
    required this.onDelete,
    required this.onNew,
    required this.onExport,
    required this.onRefresh,
    this.clinicType = 'dental',
    this.loading = false,
    this.error,
    this.contextLoading = false,
    this.contextError,
  });
  final List<PatientListEntry> patients;
  final PatientListContext contextData;
  final ValueChanged<PatientListEntry> onOpen, onDelete;
  final ValueChanged<List<PatientListEntry>> onExport;
  final VoidCallback onNew, onRefresh;
  final String clinicType;
  final bool loading, contextLoading;
  final String? error, contextError;
  @override
  State<ClinicalPatientListView> createState() =>
      _ClinicalPatientListViewState();
}

class _ClinicalPatientListViewState extends State<ClinicalPatientListView> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _filters = <PatientListFilter>{};
  PatientListSort _sort = PatientListSort.alphabetic;
  String? _opened;
  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Color get _bg => ClinicalAgendaStyle.tone(
    const Color(0xFF0A0F15),
    const Color(0xFFF3F6FA),
  );
  Color get _surface =>
      ClinicalAgendaStyle.tone(const Color(0xFF10151C), Colors.white);
  Color get _input => ClinicalAgendaStyle.tone(
    const Color(0xFF151B23),
    const Color(0xFFE8EDF4),
  );
  Color get _border => ClinicalAgendaStyle.tone(
    const Color(0xFF1E2633),
    const Color(0xFFD7E0EA),
  );
  Color get _text => ClinicalAgendaStyle.tone(
    const Color(0xFFF8FAFC),
    const Color(0xFF202936),
  );
  Color get _muted => ClinicalAgendaStyle.tone(
    const Color(0xFF94A3B8),
    const Color(0xFF536276),
  );
  Color get _green => ClinicalAgendaStyle.tone(
    const Color(0xFF00E599),
    const Color(0xFF007E69),
  );
  Color get _pink => ClinicalAgendaStyle.tone(
    const Color(0xFFF87195),
    const Color(0xFFB32645),
  );
  bool get _ready => !widget.loading && widget.error == null;
  bool get _contextReady =>
      !widget.contextLoading && widget.contextError == null;
  bool get _unknownFilter =>
      !_contextReady &&
      (_sort == PatientListSort.attendance ||
          _filters.any((f) => f != PatientListFilter.noConsent));
  void _open(PatientListEntry p) {
    setState(() => _opened = p.id);
    widget.onOpen(p);
  }

  Widget _tag(String label, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      border: Border.all(color: color.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final rows = filterPatientList(
      widget.patients,
      context: widget.contextData,
      search: _search.text,
      filters: _filters,
      sort: _sort,
    );
    final noConsent = widget.patients.where((p) => !p.consent).length;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _focus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _focus.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: Theme(
          data: ClinicalCareStyle.forContext(context),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontFamily: 'PlusJakartaSans', color: _text),
            child: Scaffold(
              backgroundColor: _bg,
              floatingActionButton: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF009FE3).withValues(alpha: .22),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  key: const ValueKey('patient-list-new-floating'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF00B4DF)),
                  ),
                  onPressed: widget.onNew,
                  backgroundColor: const Color(0xFF008CC9),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text(
                    'NOVO PACIENTE',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              body: LayoutBuilder(
                builder: (context, c) {
                  final mobile = c.maxWidth < 650;
                  final padding = mobile ? 16.0 : 32.0;
                  final topActions = Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('patient-list-export'),
                        onPressed: _ready && !_unknownFilter && rows.isNotEmpty
                            ? () => widget.onExport(rows)
                            : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: _muted,
                          side: BorderSide(color: _border),
                          minimumSize: const Size(150, 40),
                        ),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Exportar CSV'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('patient-list-new'),
                        onPressed: widget.onNew,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(190, 40),
                        ),
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          '+ NOVO PACIENTE',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  );
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Meus Pacientes',
                            style: TextStyle(
                              fontSize: mobile ? 25 : 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _input,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _ready
                                  ? '${NumberFormat.decimalPattern('pt_BR').format(widget.patients.length)} pacientes • ${NumberFormat.decimalPattern('pt_BR').format(widget.patients.where((p) => p.active).length)} ativos'
                                  : widget.error != null
                                  ? 'Pacientes indisponíveis'
                                  : 'Carregando pacientes…',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Gerencie cadastros clínicos, orçamentos, termos LGPD e histórico de prontuários em tempo real.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  );
                  return CustomScrollView(
                    key: const ValueKey('patient-list-results'),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 28, padding, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (c.maxWidth < 1100) ...[
                                title,
                                const SizedBox(height: 16),
                                topActions,
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: title),
                                    const SizedBox(width: 20),
                                    topActions,
                                  ],
                                ),
                              const SizedBox(height: 28),
                              Container(
                                padding: EdgeInsets.all(mobile ? 14 : 20),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  border: Border.all(color: _border),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      key: const ValueKey(
                                        'patient-list-search',
                                      ),
                                      controller: _search,
                                      focusNode: _focus,
                                      onChanged: (_) => setState(() {}),
                                      style: TextStyle(
                                        color: _text,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Buscar por nome, CPF, telefone ou prontuário…',
                                        hintStyle: TextStyle(
                                          color: _muted,
                                          fontSize: mobile ? 12 : 15,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          color: _muted,
                                        ),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_search.text.isNotEmpty)
                                              IconButton(
                                                tooltip: 'Limpar busca',
                                                onPressed: () {
                                                  _search.clear();
                                                  setState(() {});
                                                },
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 17,
                                                ),
                                              ),
                                            if (!mobile)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 12,
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _surface,
                                                    border: Border.all(
                                                      color: _border,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Ctrl K',
                                                    style: TextStyle(
                                                      color: _muted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        filled: true,
                                        fillColor: _input,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 18,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                          borderSide: BorderSide(
                                            color: _border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                          borderSide: BorderSide(
                                            color: _border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                          borderSide: BorderSide(color: _green),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final f in [
                                          (
                                            PatientListFilter.noConsent,
                                            'Sem aceite LGPD',
                                            Icons.circle,
                                            _pink,
                                          ),
                                          (
                                            PatientListFilter.debt,
                                            'Com pendência financeira',
                                            Icons.attach_money,
                                            ClinicalAgendaStyle.warning,
                                          ),
                                          (
                                            PatientListFilter.treatment,
                                            'Tratamento em andamento',
                                            Icons.monitor_heart_outlined,
                                            _green,
                                          ),
                                          (
                                            PatientListFilter.budget,
                                            'Orçamentos abertos',
                                            Icons.description_outlined,
                                            ClinicalAgendaStyle.blue,
                                          ),
                                        ])
                                          Tooltip(
                                            message:
                                                f.$1 ==
                                                    PatientListFilter.noConsent
                                                ? 'Cadastros sem aceite registrado'
                                                : _contextReady
                                                ? 'Filtrar pacientes'
                                                : widget.contextError ??
                                                      'Carregando dados complementares',
                                            child: FilterChip(
                                              key: ValueKey(
                                                'patient-filter-${f.$1.name}',
                                              ),
                                              selected: _filters.contains(f.$1),
                                              showCheckmark: false,
                                              avatar: Icon(
                                                f.$3,
                                                size: 15,
                                                color: f.$4,
                                              ),
                                              label: Text(
                                                '${f.$2}${f.$1 == PatientListFilter.noConsent && _ready ? '  $noConsent' : ''}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      f.$1 ==
                                                          PatientListFilter
                                                              .noConsent
                                                      ? f.$4
                                                      : _muted,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              backgroundColor: _input,
                                              selectedColor: f.$4.withValues(
                                                alpha: .15,
                                              ),
                                              side: BorderSide(
                                                color: _filters.contains(f.$1)
                                                    ? f.$4.withValues(alpha: .6)
                                                    : f.$1 ==
                                                          PatientListFilter
                                                              .noConsent
                                                    ? f.$4.withValues(alpha: .3)
                                                    : _border,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              onSelected:
                                                  f.$1 ==
                                                          PatientListFilter
                                                              .noConsent ||
                                                      _contextReady ||
                                                      _filters.contains(f.$1)
                                                  ? (v) => setState(() {
                                                      if (v) {
                                                        _filters.add(f.$1);
                                                      } else {
                                                        _filters.remove(f.$1);
                                                      }
                                                    })
                                                  : null,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Ordenar por:',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: math.min(
                                              300,
                                              c.maxWidth -
                                                  padding * 2 -
                                                  (mobile ? 28 : 40) -
                                                  2,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _input,
                                            border: Border.all(color: _border),
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<PatientListSort>(
                                              key: const ValueKey(
                                                'patient-list-sort',
                                              ),
                                              value: _sort,
                                              isExpanded: true,
                                              style: TextStyle(
                                                fontFamily: 'PlusJakartaSans',
                                                color: _text,
                                                fontSize: 12,
                                              ),
                                              dropdownColor: _input,
                                              items: [
                                                const DropdownMenuItem(
                                                  value: PatientListSort
                                                      .alphabetic,
                                                  child: Text(
                                                    'Ordem alfabética (A–Z)',
                                                  ),
                                                ),
                                                const DropdownMenuItem(
                                                  value: PatientListSort.recent,
                                                  child: Text(
                                                    'Recentes adicionados',
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: PatientListSort
                                                      .attendance,
                                                  enabled: _contextReady,
                                                  child: const Text(
                                                    'Último atendimento (90 dias)',
                                                  ),
                                                ),
                                              ],
                                              onChanged: (v) =>
                                                  setState(() => _sort = v!),
                                            ),
                                          ),
                                        ),
                                        if (_filters.isNotEmpty ||
                                            _search.text.isNotEmpty ||
                                            _sort != PatientListSort.alphabetic)
                                          TextButton(
                                            onPressed: () => setState(() {
                                              _filters.clear();
                                              _search.clear();
                                              _sort =
                                                  PatientListSort.alphabetic;
                                            }),
                                            child: const Text('Limpar filtros'),
                                          ),
                                      ],
                                    ),
                                    if (widget.contextError != null)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Dados complementares indisponíveis. Busca e cadastros continuam disponíveis.',
                                              style: TextStyle(
                                                color:
                                                    ClinicalAgendaStyle.warning,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Atualizar lista',
                                            onPressed: widget.onRefresh,
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      if (widget.loading ||
                          widget.error != null ||
                          _unknownFilter ||
                          rows.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: widget.loading
                              ? const Center(child: CircularProgressIndicator())
                              : widget.error != null
                              ? _message(widget.error!, retry: true)
                              : _unknownFilter
                              ? _message(
                                  widget.contextError ??
                                      'Carregando dados dos filtros…',
                                  retry: widget.contextError != null,
                                )
                              : rows.isEmpty
                              ? _message(
                                  widget.patients.isEmpty
                                      ? 'Nenhum paciente cadastrado.'
                                      : 'Nenhum paciente encontrado para os filtros selecionados.',
                                )
                              : const SizedBox.shrink(),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            4,
                            padding,
                            110,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _card(
                                rows[i],
                                featured:
                                    _opened == rows[i].id ||
                                    (_opened == null && i == 0),
                                mobile: mobile,
                              ),
                              childCount: rows.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_outlined, size: 46, color: _muted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
          if (retry)
            TextButton(
              onPressed: widget.onRefresh,
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    ),
  );
  Widget _card(
    PatientListEntry p, {
    required bool featured,
    required bool mobile,
  }) {
    final colors = [
      _green,
      ClinicalAgendaStyle.blue,
      _pink,
      const Color(0xFFB784E4),
      ClinicalAgendaStyle.warning,
    ];
    final color =
        colors[p.name.runes.fold<int>(0, (s, c) => s + c) % colors.length];
    final statusColor = p.status.toLowerCase().contains('lab')
        ? const Color(0xFFB784E4)
        : p.active
        ? ClinicalAgendaStyle.blue
        : _muted;
    final visit = _contextReady ? widget.contextData.attendance[p.id] : null;
    final date = reportDate(visit?['date']);
    final debt = widget.contextData.debts[p.id] ?? 0;
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: featured ? 74 : 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: featured ? 70 : 60,
                height: featured ? 70 : 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  gradient: featured
                      ? const LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                            Color(0xFF1D4ED8),
                            Color(0xFF2563EB),
                            Color(0xFF009E85),
                          ],
                        )
                      : null,
                  border: Border.all(
                    color: featured
                        ? const Color(0xFF4392D8)
                        : color.withValues(alpha: .4),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.name.isEmpty
                      ? '?'
                      : String.fromCharCode(p.name.runes.first).toUpperCase(),
                  style: TextStyle(
                    color: featured ? Colors.white : color,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (featured)
                Positioned(
                  bottom: -5,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bg, width: 2),
                    ),
                    child: Text(
                      '360°',
                      style: TextStyle(
                        color: ClinicalAgendaStyle.onAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      color: _text,
                      fontSize: featured ? 20 : 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                  if (p.record.isNotEmpty)
                    _tag(
                      featured ? 'Prontuário #${p.record}' : '#${p.record}',
                      featured ? _green : _muted,
                    ),
                  if (featured || p.status.toLowerCase() != 'ativo')
                    _tag(
                      '${p.status}${featured && widget.clinicType == 'dental'
                          ? ' • Odontologia'
                          : featured && widget.clinicType == 'psychology'
                          ? ' • Psicologia'
                          : ''}',
                      statusColor,
                    ),
                  if (_contextReady &&
                      widget.contextData.treatments.contains(p.id))
                    _tag('Em tratamento', _green),
                  if (!p.consent) _tag('Sem aceite LGPD', _pink),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 18,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.phone.isEmpty
                            ? Icons.phone_disabled_outlined
                            : Icons.phone_outlined,
                        size: 15,
                        color: color,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          p.phone.isEmpty ? 'Não informado' : p.phone,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontStyle: p.phone.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (p.cpf.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined, size: 15, color: _muted),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'CPF: ${patientMaskedCpf(p.cpf)}',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (_contextReady &&
                  (date != null ||
                      debt > 0 ||
                      widget.contextData.budgets.contains(p.id))) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 6,
                  children: [
                    if (date != null)
                      Tooltip(
                        message:
                            'Atendimento finalizado registrado nos últimos 90 dias',
                        child: _tag(
                          'Último atendimento: ${formatDateFull(date)}${'${visit?['procedure'] ?? ''}'.isEmpty ? '' : ' (${visit!['procedure']})'}',
                          _green,
                          icon: Icons.schedule,
                        ),
                      ),
                    if (debt > 0)
                      _tag(
                        'Pendência ${reportMoney(debt)}',
                        ClinicalAgendaStyle.warning,
                        icon: Icons.error_outline,
                      ),
                    if (widget.contextData.budgets.contains(p.id))
                      _tag(
                        'Orçamento aberto',
                        ClinicalAgendaStyle.tone(
                          const Color(0xFF00C8E8),
                          const Color(0xFF007A9A),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final open = featured
        ? FilledButton.icon(
            key: ValueKey('patient-open-${p.id}'),
            onPressed: () => _open(p),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: ClinicalAgendaStyle.onAccent,
              minimumSize: const Size(210, 44),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            iconAlignment: IconAlignment.end,
            label: const Text(
              'Abrir Prontuário 360°',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          )
        : OutlinedButton(
            key: ValueKey('patient-open-${p.id}'),
            onPressed: () => _open(p),
            style: OutlinedButton.styleFrom(
              backgroundColor: _input,
              foregroundColor: _muted,
              side: BorderSide(color: _border),
              minimumSize: const Size(130, 36),
            ),
            child: const Text(
              'Ver Prontuário',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          );
    final menu = PopupMenuButton<String>(
      tooltip: 'Opções de ${p.name}',
      icon: Icon(Icons.more_vert, color: _muted),
      onSelected: (v) {
        if (v == 'delete') widget.onDelete(p);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Excluir Paciente'),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('patient-card-${p.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(p),
          onLongPress: () => widget.onDelete(p),
          child: Container(
            padding: EdgeInsets.all(mobile ? 16 : 20),
            decoration: BoxDecoration(
              color: _surface,
              gradient: featured
                  ? LinearGradient(
                      colors: [
                        ClinicalAgendaStyle.tone(
                          const Color(0xFF121922),
                          Colors.white,
                        ),
                        _surface,
                      ],
                    )
                  : null,
              border: Border.all(
                color: featured ? _green.withValues(alpha: .65) : _border,
                width: featured ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth < 880
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 12,
                          runSpacing: 8,
                          children: [open, menu],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 24),
                        open,
                        const SizedBox(width: 16),
                        menu,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
