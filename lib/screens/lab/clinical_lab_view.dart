import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../models/lab_order.dart';
import '../../utils/display.dart';
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

String formatLabMoney(num value) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);

String labStage(String status) => switch (status.toLowerCase().trim()) {
  'sent' || 'enviado' => 'sent',
  'pending_return' || 'aguardando retorno' => 'pending_return',
  'delivered' || 'concluído' || 'entregue' => 'delivered',
  _ => 'pending_send',
};

const labStages = [
  (
    id: 'pending_send',
    label: 'Aguardando Envio',
    color: Color(0xFFFFA000),
    background: Color(0xFFFEF3C7),
    ink: Color(0xFF854410),
  ),
  (
    id: 'sent',
    label: 'Enviado (No Lab)',
    color: Color(0xFF19B9E7),
    background: Color(0xFFDFF3FC),
    ink: Color(0xFF006B9C),
  ),
  (
    id: 'pending_return',
    label: 'Aguardando Retorno',
    color: Color(0xFFBB7AF4),
    background: Color(0xFFF3E8FF),
    ink: Color(0xFF7128AF),
  ),
  (
    id: 'delivered',
    label: 'Entregue',
    color: Color(0xFF22C55E),
    background: Color(0xFFDCFCE7),
    ink: Color(0xFF166534),
  ),
];

class ClinicalLabView extends StatefulWidget {
  const ClinicalLabView({
    super.key,
    required this.orders,
    required this.onNew,
    required this.onExport,
    required this.onMove,
    required this.onAction,
    this.individual = false,
    this.loading = false,
    this.creating = false,
    this.error,
  });
  final List<LabOrderModel> orders;
  final VoidCallback onNew;
  final ValueChanged<List<LabOrderModel>> onExport;
  final void Function(LabOrderModel, String) onMove;
  final void Function(LabOrderModel, String) onAction;
  final bool individual, loading, creating;
  final String? error;
  @override
  State<ClinicalLabView> createState() => _ClinicalLabViewState();
}

class _ClinicalLabViewState extends State<ClinicalLabView> {
  String _query = '';
  String? _supplier, _dentist, _type;
  List<LabOrderModel> get _filtered => widget.orders
      .where(
        (o) =>
            (_query.isEmpty ||
                '${o.patientName} ${o.id} ${o.description} ${o.procedureName} ${o.workType ?? ''}'
                    .toLowerCase()
                    .contains(_query)) &&
            (_supplier == null || o.supplierId == _supplier) &&
            (_dentist == null || o.dentistId == _dentist) &&
            (_type == null ||
                (o.workType?.trim().isNotEmpty == true
                        ? o.workType
                        : 'Não informado') ==
                    _type),
      )
      .toList();

  Widget _filter(
    String label,
    String? value,
    Map<String, String> choices,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('lab-filter-$label-$value'),
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(
      prefixIcon: Icon(
        label == 'Todos Dentistas'
            ? Icons.badge_outlined
            : Icons.science_outlined,
        size: 18,
      ),
      filled: true,
      fillColor: ClinicalAgendaStyle.elevated,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
    items: [
      DropdownMenuItem<String>(
        value: null,
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      for (final e in choices.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) => setState(() => changed(v)),
  );

  @override
  Widget build(BuildContext context) {
    final orders = _filtered;
    final activeCount = orders
        .where((o) => labStage(o.status) != 'delivered')
        .length;
    final suppliers = {
      for (final o in widget.orders)
        if (o.supplierId != null)
          o.supplierId!: o.supplierName ?? 'Laboratório não informado',
    };
    final dentists = {
      for (final o in widget.orders)
        if (o.dentistId != null)
          o.dentistId!: o.dentistName ?? 'Solicitante não informado',
    };
    final types = {
      for (final o in widget.orders)
        (o.workType?.trim().isNotEmpty == true
            ? o.workType!
            : 'Não informado'): (o.workType?.trim().isNotEmpty == true
            ? o.workType!
            : 'Não informado'),
    };
    // A filter remains visible if its last order disappears from the live snapshot.
    if (_supplier != null) {
      suppliers.putIfAbsent(_supplier!, () => 'Laboratório selecionado');
    }
    if (_dentist != null) {
      dentists.putIfAbsent(_dentist!, () => 'Solicitante selecionado');
    }
    if (_type != null) types.putIfAbsent(_type!, () => _type!);
    return Theme(
      data: ClinicalCareStyle.forContext(context),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 740;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ClinicalAgendaStyle.elevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.biotech_outlined,
                  color: ClinicalAgendaStyle.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Gestão de Laboratório (Kanban)',
                          style: TextStyle(
                            fontSize: narrow ? 20 : 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ClinicalAgendaStyle.accent.withValues(
                              alpha: .12,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$activeCount ${activeCount == 1 ? 'ordem ativa' : 'ordens ativas'}',
                            style: TextStyle(
                              color: ClinicalAgendaStyle.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.individual
                          ? 'Pedidos e custos de laboratório deste paciente'
                          : 'Fluxo integrado de próteses, alinhadores e comunicação com laboratórios parceiros',
                      style: TextStyle(
                        color: ClinicalAgendaStyle.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed:
                    widget.loading || widget.error != null || orders.isEmpty
                    ? null
                    : () => widget.onExport(orders),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Exportar'),
              ),
              FilledButton.icon(
                onPressed: widget.creating ? null : widget.onNew,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(
                  widget.creating ? 'Abrindo…' : '+ Novo Pedido de Laboratório',
                ),
              ),
            ],
          );
          final filterWidth = narrow ? c.maxWidth - 44 : (c.maxWidth - 98) / 4;
          return ColoredBox(
            color: ClinicalAgendaStyle.background,
            child: SingleChildScrollView(
              child: SizedBox(
                height: math.max(
                  c.maxHeight.isFinite ? c.maxHeight : 800,
                  narrow ? 1050 : 700,
                ),
                child: Padding(
                  padding: EdgeInsets.all(narrow ? 12 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.maxWidth > 1100)
                        Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 16),
                            actions,
                          ],
                        )
                      else ...[
                        title,
                        const SizedBox(height: 14),
                        actions,
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ClinicalAgendaStyle.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: filterWidth,
                              child: TextField(
                                key: const ValueKey('lab-search'),
                                onChanged: (v) => setState(
                                  () => _query = v.toLowerCase().trim(),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Buscar paciente ou trabalho…',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                  ),
                                  filled: true,
                                  fillColor: ClinicalAgendaStyle.elevated,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: filterWidth,
                              child: _filter(
                                'Todos Laboratórios',
                                _supplier,
                                suppliers,
                                (v) => _supplier = v,
                              ),
                            ),
                            SizedBox(
                              width: filterWidth,
                              child: _filter(
                                'Todos Dentistas',
                                _dentist,
                                dentists,
                                (v) => _dentist = v,
                              ),
                            ),
                            SizedBox(
                              width: filterWidth,
                              child: _filter(
                                'Todos os Tipos',
                                _type,
                                types,
                                (v) => _type = v,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (widget.loading) const LinearProgressIndicator(),
                      Expanded(
                        child: widget.error != null
                            ? Center(
                                child: Text(
                                  widget.error!,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : widget.loading
                            ? const Center(child: Text('Carregando pedidos…'))
                            : LayoutBuilder(
                                builder: (context, board) {
                                  final width = math.max(
                                    250.0,
                                    (board.maxWidth - 60) / 4,
                                  );
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final stage in labStages) ...[
                                          DragTarget<LabOrderModel>(
                                            onWillAcceptWithDetails: (d) =>
                                                labStage(d.data.status) !=
                                                stage.id,
                                            onAcceptWithDetails: (d) =>
                                                widget.onMove(d.data, stage.id),
                                            builder: (context, candidates, rejected) => Container(
                                              key: ValueKey(
                                                'lab-column-${stage.id}',
                                              ),
                                              width: width,
                                              height: board.maxHeight,
                                              clipBehavior: Clip.antiAlias,
                                              decoration: BoxDecoration(
                                                color: candidates.isEmpty
                                                    ? ClinicalAgendaStyle
                                                          .surface
                                                    : stage.color.withValues(
                                                        alpha: .12,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    height: 72,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                        ),
                                                    color: stage.background,
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration:
                                                              BoxDecoration(
                                                                color:
                                                                    stage.color,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            stage.label,
                                                            style: TextStyle(
                                                              color: stage.ink,
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                        CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor:
                                                              const Color(
                                                                0xFF181C22,
                                                              ),
                                                          child: Text(
                                                            '${orders.where((o) => labStage(o.status) == stage.id).length}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child:
                                                        orders.any(
                                                          (o) =>
                                                              labStage(
                                                                o.status,
                                                              ) ==
                                                              stage.id,
                                                        )
                                                        ? ListView(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  18,
                                                                ),
                                                            children: [
                                                              for (final order
                                                                  in orders.where(
                                                                    (o) =>
                                                                        labStage(
                                                                          o.status,
                                                                        ) ==
                                                                        stage
                                                                            .id,
                                                                  ))
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        bottom:
                                                                            18,
                                                                      ),
                                                                  child: _draggable(
                                                                    order,
                                                                    stage.color,
                                                                    width - 36,
                                                                  ),
                                                                ),
                                                            ],
                                                          )
                                                        : _empty(stage.id),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (stage.id != labStages.last.id)
                                            const SizedBox(width: 20),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _draggable(LabOrderModel order, Color color, double width) {
    final feedback = Material(
      color: Colors.transparent,
      child: SizedBox(width: width, child: _card(order, color)),
    );
    final faded = Opacity(opacity: .35, child: _card(order, color));
    return _MouseLabDraggable(
      data: order,
      feedback: feedback,
      childWhenDragging: faded,
      child: LongPressDraggable<LabOrderModel>(
        data: order,
        delay: const Duration(milliseconds: 300),
        feedback: feedback,
        childWhenDragging: faded,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: _card(order, color),
        ),
      ),
    );
  }

  Widget _empty(String stage) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.fact_check_outlined,
          size: 36,
          color: ClinicalAgendaStyle.muted.withValues(alpha: .5),
        ),
        const SizedBox(height: 14),
        Text(
          stage == 'delivered'
              ? 'Nenhum pedido finalizado'
              : 'Nenhum pedido nesta etapa',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ClinicalAgendaStyle.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stage == 'delivered'
              ? 'Arraste os trabalhos prontos para esta coluna'
              : 'Os pedidos aparecerão aqui conforme o andamento',
          textAlign: TextAlign.center,
          style: TextStyle(color: ClinicalAgendaStyle.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _card(LabOrderModel o, Color color) {
    final date = labStage(o.status) == 'delivered'
        ? o.deliveredDate
        : o.returnDate ?? o.deliveryDate;
    final now = DateTime.now();
    final overdue =
        date != null &&
        DateTime(
          date.year,
          date.month,
          date.day,
        ).isBefore(DateTime(now.year, now.month, now.day)) &&
        labStage(o.status) != 'delivered';
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ClinicalAgendaStyle.accent),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: ClinicalAgendaStyle.text),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: ValueKey('lab-card-${o.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ClinicalAgendaStyle.tone(
          const Color(0xFF1C2026),
          const Color(0xFFF3F6FA),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: ClinicalAgendaStyle.muted,
                ),
                const SizedBox(width: 6),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Ações do pedido',
                  iconSize: 18,
                  onSelected: (v) => v.startsWith('move:')
                      ? widget.onMove(o, v.substring(5))
                      : widget.onAction(o, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Text('Ver detalhes'),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('Histórico de interações'),
                    ),
                    for (final s in labStages)
                      if (labStage(o.status) != s.id)
                        PopupMenuItem(
                          value: 'move:${s.id}',
                          child: Text('Mover: ${s.label}'),
                        ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir pedido'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.individual
                      ? (o.procedureName.isEmpty
                            ? o.description
                            : o.procedureName)
                      : o.patientName,
                  style: TextStyle(
                    color: ClinicalAgendaStyle.text,
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.individual
                                ? o.workType ?? 'Tipo não informado'
                                : (o.procedureName.isEmpty
                                      ? o.description
                                      : o.procedureName),
                            style: TextStyle(
                              color: ClinicalAgendaStyle.isDark
                                  ? color
                                  : color.withValues(
                                      red: color.r * .65,
                                      green: color.g * .65,
                                      blue: color.b * .65,
                                    ),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 74,
                      child: Text(
                        o.price > 0
                            ? formatLabMoney(o.price)
                            : o.hasCost == false
                            ? 'Sem custo'
                            : 'Custo não informado',
                        style: TextStyle(
                          color: ClinicalAgendaStyle.muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                line(
                  Icons.person_outline,
                  o.dentistName ?? 'Solicitante não informado',
                ),
                line(
                  Icons.apartment_outlined,
                  o.supplierName ?? 'Laboratório não informado',
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
            color: ClinicalAgendaStyle.background.withValues(alpha: .35),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: overdue
                      ? ClinicalAgendaStyle.danger
                      : ClinicalAgendaStyle.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date == null
                        ? 'Sem previsão registrada'
                        : '${formatDateShort(date)}${overdue ? ' (Atrasado)' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: overdue
                          ? ClinicalAgendaStyle.danger
                          : ClinicalAgendaStyle.blue,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Adicionar interação',
                  onPressed: () => widget.onAction(o, 'interaction'),
                  style: IconButton.styleFrom(
                    backgroundColor: ClinicalAgendaStyle.elevated,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mouse drags start immediately; touch remains a long press in the child,
/// so the horizontal board and vertical lists can still scroll on phones.
class _MouseLabDraggable extends Draggable<LabOrderModel> {
  const _MouseLabDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  });
  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => ImmediateMultiDragGestureRecognizer(
    supportedDevices: const {
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
    },
    allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
  )..onStart = onStart;
}
