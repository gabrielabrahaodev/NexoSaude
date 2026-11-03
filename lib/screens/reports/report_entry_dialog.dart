import 'package:flutter/material.dart';
import '../../utils/display.dart';
import '../care/clinical_care_view.dart';

/// A single manual cash entry; existing patient and laboratory workflows keep
/// their own links and financial rules.
class ReportEntryDialog extends StatefulWidget {
  const ReportEntryDialog({
    super.key,
    required this.income,
    required this.month,
    required this.onSave,
  });
  final bool income;
  final DateTime month;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<ReportEntryDialog> createState() => _ReportEntryDialogState();
}

class _ReportEntryDialogState extends State<ReportEntryDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _party = TextEditingController();
  final _category = TextEditingController(text: 'Geral');
  late DateTime _date;
  bool _paid = false, _saving = false;
  String _method = 'Dinheiro';
  String? _error;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = now.year == widget.month.year && now.month == widget.month.month
        ? DateTime(now.year, now.month, now.day)
        : DateTime(widget.month.year, widget.month.month);
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _party.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        'description': _description.text.trim(),
        'title': _description.text.trim(),
        'amount': parseBRL(_amount.text),
        'party': _party.text.trim(),
        'category': _category.text.trim(),
        'date': _date,
        'paid': _paid,
        'paymentMethod': _method,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Não foi possível salvar. Verifique a conexão e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ClinicalCareStyle.forContext(context),
    child: PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.income ? 'Novo Lançamento' : 'Nova Despesa'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.income)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Receita avulsa da clínica. Para cobrar um paciente, utilize a aba Pagamentos do seu cadastro.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  TextFormField(
                    controller: _description,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Descrição *'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe a descrição'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$) *',
                      hintText: '0,00',
                    ),
                    validator: (v) {
                      final n = parseBRL(v);
                      return !n.isFinite || n <= 0
                          ? 'Informe um valor maior que zero'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!widget.income) ...[
                    TextFormField(
                      controller: _party,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _category,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Categoria *'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe a categoria'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (date != null && mounted) {
                              setState(() => _date = date);
                            }
                          },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Vencimento: ${formatDateFull(_date)}'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.income ? 'Já recebido' : 'Já pago'),
                    subtitle: const Text(
                      'Se marcado, a data acima será também a data da baixa.',
                    ),
                    value: _paid,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _paid = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
                    ),
                    items: [
                      for (final m in [
                        'Dinheiro',
                        'Pix',
                        'Débito',
                        'Boleto',
                        'Transferência',
                        'Outros',
                      ])
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _method = v!),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando…' : 'Salvar lançamento'),
          ),
        ],
      ),
    ),
  );
}
