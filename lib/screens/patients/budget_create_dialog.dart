import 'package:flutter/material.dart';
import '../../models/procedure_model.dart';
import '../../utils/display.dart';
import '../../utils/report_export.dart' show reportMoney;
import '../agenda/clinical_agenda_view.dart';
import '../care/clinical_care_view.dart';

class BudgetDraftItem {
  BudgetDraftItem(ProcedureModel procedure)
    : id = procedure.id,
      category = procedure.category,
      name = procedure.name,
      unitPrice = procedure.price;
  final String id, category;
  String name, region = '';
  double unitPrice, quantity = 1, discountPercent = 0;
  double get subtotal {
    final value = unitPrice * quantity * (1 - discountPercent / 100);
    return value.isFinite && (value * 100).isFinite
        ? (value * 100).round() / 100
        : 0;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'name': name.trim(),
    'region': region.trim(),
    'unitPrice': unitPrice,
    'quantity': quantity,
    'discountPercent': discountPercent,
    'discountAmount': ((unitPrice * quantity - subtotal) * 100).round() / 100,
    'price': subtotal,
  };
  bool get valid =>
      name.trim().isNotEmpty &&
      unitPrice.isFinite &&
      unitPrice >= 0 &&
      quantity.isFinite &&
      quantity >= 1 &&
      quantity == quantity.roundToDouble() &&
      discountPercent.isFinite &&
      discountPercent >= 0 &&
      discountPercent <= 100 &&
      (unitPrice * quantity * 100).isFinite;
}

class BudgetCreateDialog extends StatefulWidget {
  const BudgetCreateDialog({
    super.key,
    required this.patientName,
    required this.clinicName,
    required this.procedures,
    required this.onSave,
  });
  final String patientName, clinicName;
  final Stream<List<ProcedureModel>> procedures;
  final Future<void> Function(
    List<Map<String, dynamic>>,
    double,
    Map<String, dynamic>,
  )
  onSave;
  @override
  State<BudgetCreateDialog> createState() => _BudgetCreateDialogState();
}

class _BudgetCreateDialogState extends State<BudgetCreateDialog> {
  final _items = <BudgetDraftItem>[];
  final _conditions = TextEditingController();
  String _search = '';
  String? _method;
  int? _installments, _validDays;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _conditions.dispose();
    super.dispose();
  }

  double get total => _items.fold<double>(0, (sum, i) => sum + i.subtotal);
  Future<void> _save() async {
    if (_saving) return;
    if (_items.isEmpty ||
        _items.any((i) => !i.valid) ||
        !total.isFinite ||
        total < 0) {
      setState(
        () => _error =
            'Inclua procedimentos e confira descrição, quantidade inteira, valor e desconto de 0 a 100%.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    try {
      await widget.onSave(_items.map((i) => i.toMap()).toList(), total, {
        if (_conditions.text.trim().isNotEmpty)
          'paymentConditions': _conditions.text.trim(),
        if (_method != null) 'paymentMethod': _method,
        if (_installments != null) 'suggestedInstallments': _installments,
        if (_validDays != null)
          'validUntil': DateTime(now.year, now.month, now.day + _validDays!),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Não foi possível salvar. Confira a unidade e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ClinicalCareStyle.forContext(context),
    child: PopScope(
      canPop: !_saving,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 900,
          height: MediaQuery.sizeOf(context).height * .9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: ClinicalAgendaStyle.elevated.withValues(alpha: .4),
                padding: const EdgeInsets.fromLTRB(20, 16, 10, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.post_add,
                      color: ClinicalAgendaStyle.blue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Novo Orçamento Clínico',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Paciente: ${widget.patientName} • Unidade: ${widget.clinicName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ClinicalAgendaStyle.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _saving,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('1. SELECIONAR CATEGORIA / PROCEDIMENTO'),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('budget-procedure-search'),
                          onChanged: (v) =>
                              setState(() => _search = v.trim().toLowerCase()),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText:
                                'Buscar procedimento por nome ou categoria…',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: StreamBuilder<List<ProcedureModel>>(
                            stream: widget.procedures,
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return const Center(
                                  child: Text(
                                    'Não foi possível carregar o catálogo.',
                                  ),
                                );
                              }
                              if (!snap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final list = snap.data!
                                  .where(
                                    (p) =>
                                        p.active &&
                                        '${p.name} ${p.category}'
                                            .toLowerCase()
                                            .contains(_search),
                                  )
                                  .toList();
                              if (list.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Nenhum procedimento encontrado.',
                                  ),
                                );
                              }
                              return ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final p = list[i];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    leading: Icon(
                                      Icons.medical_services_outlined,
                                      color: ClinicalAgendaStyle.blue,
                                    ),
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${p.category} • ${reportMoney(p.price)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: FilledButton(
                                      onPressed: () => setState(
                                        () => _items.add(BudgetDraftItem(p)),
                                      ),
                                      child: const Text('Adicionar'),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _label(
                          '2. ITENS INCLUÍDOS NO ORÇAMENTO (${_items.length})',
                        ),
                        const SizedBox(height: 10),
                        if (_items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Nenhum item incluído.'),
                          ),
                        for (final row in _items)
                          _BudgetDraftRow(
                            key: ObjectKey(row),
                            item: row,
                            onChanged: () => setState(() {}),
                            onRemove: () => setState(() => _items.remove(row)),
                          ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 250,
                              child: DropdownButtonFormField<String>(
                                initialValue: _method,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Forma sugerida (opcional)',
                                ),
                                items: [
                                  for (final m in [
                                    'Cartão de Crédito',
                                    'Pix',
                                    'Boleto',
                                    'Dinheiro',
                                  ])
                                    DropdownMenuItem(value: m, child: Text(m)),
                                ],
                                onChanged: (v) => setState(() => _method = v),
                              ),
                            ),
                            SizedBox(
                              width: 250,
                              child: DropdownButtonFormField<int>(
                                initialValue: _installments,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Parcelamento sugerido',
                                ),
                                items: [
                                  for (final n in [1, 2, 3, 6, 10, 12])
                                    DropdownMenuItem(
                                      value: n,
                                      child: Text(
                                        n == 1
                                            ? 'À vista'
                                            : '${n}x de ${reportMoney(total / n)}',
                                      ),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _installments = v),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<int>(
                                initialValue: _validDays,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Validade (opcional)',
                                ),
                                items: [
                                  for (final n in [7, 15, 30])
                                    DropdownMenuItem(
                                      value: n,
                                      child: Text('$n dias'),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _validDays = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _conditions,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Condições da proposta (opcional)',
                            hintText: 'Informe as condições acordadas.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Condições sugeridas; a aprovação confirma o plano e os lançamentos financeiros no assistente existente.',
                          style: TextStyle(
                            fontSize: 11,
                            color: ClinicalAgendaStyle.muted,
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: ClinicalAgendaStyle.danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                color: ClinicalAgendaStyle.background,
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL DO ORÇAMENTO',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          reportMoney(total),
                          key: const ValueKey('budget-draft-total'),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: ClinicalAgendaStyle.accent,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('budget-save'),
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: Text(
                            _saving ? 'Salvando…' : 'Salvar Orçamento',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _label(String label) => Text(
    label,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: ClinicalAgendaStyle.muted,
    ),
  );
}

class _BudgetDraftRow extends StatefulWidget {
  const _BudgetDraftRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });
  final BudgetDraftItem item;
  final VoidCallback onChanged, onRemove;
  @override
  State<_BudgetDraftRow> createState() => _BudgetDraftRowState();
}

class _BudgetDraftRowState extends State<_BudgetDraftRow> {
  @override
  Widget build(BuildContext context) {
    final row = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row.name,
                    decoration: const InputDecoration(
                      labelText: 'Procedimento',
                    ),
                    onChanged: (v) {
                      row.name = v;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Remover item',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    initialValue: row.region,
                    decoration: const InputDecoration(
                      labelText: 'Dente / Região',
                    ),
                    onChanged: (v) {
                      row.region = v;
                      widget.onChanged();
                    },
                  ),
                ),
                for (final input in [
                  ('Quantidade', '1', (double v) => row.quantity = v),
                  (
                    'Valor unitário',
                    row.unitPrice.toStringAsFixed(2),
                    (double v) => row.unitPrice = v,
                  ),
                  ('Desconto (%)', '0', (double v) => row.discountPercent = v),
                ])
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      initialValue: input.$2,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: input.$1),
                      onChanged: (v) {
                        input.$3(parseBRL(v));
                        widget.onChanged();
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Subtotal: ${reportMoney(row.subtotal.isFinite ? row.subtotal : 0)}',
                    style: TextStyle(
                      color: ClinicalAgendaStyle.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
