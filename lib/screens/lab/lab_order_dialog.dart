import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/lab_order.dart';
import '../../models/supplier_model.dart';
import '../../models/user_model.dart';
import '../../services/lab_service.dart';
import '../../services/session_manager.dart';
import '../../services/supplier_service.dart';
import '../../services/user_service.dart';
import '../../utils/display.dart';
import '../patients/clinical_patient_view.dart';

class LabOption {
  const LabOption(this.id, this.name, {this.patientId});
  final String id, name;
  final String? patientId;
}

Future<void> showLabOrderDialog(
  BuildContext context, {
  String? patientId,
}) async {
  final clinic = SessionManager().currentClinicId;
  if (clinic == null) return;
  try {
    final db = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> patients = db.collection('patients');
    Query<Map<String, dynamic>> plans = db.collection('treatment_plans');
    if (patientId != null) {
      patients = patients.where(FieldPath.documentId, isEqualTo: patientId);
      plans = plans.where('patientId', isEqualTo: patientId);
    }
    final results = await Future.wait<Object>([
      SessionManager().applyFilter(patients).get(),
      SessionManager().applyFilter(plans).get(),
      SupplierService().getAllStream().first,
      UserService().getDentistsForClinic(clinic),
    ]);
    if (!context.mounted || SessionManager().currentClinicId != clinic) return;
    final patientDocs =
        (results[0] as QuerySnapshot<Map<String, dynamic>>).docs;
    final planDocs = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs;
    if (patientId != null && !patientDocs.any((p) => p.id == patientId)) {
      throw StateError('Paciente indisponível nesta unidade.');
    }
    final service = LabService();
    final id = service.newOrderId();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: PatientVisualStyle.forContext(ctx),
        child: LabOrderDialog(
          orderId: id,
          clinicId: clinic,
          initialPatientId: patientId,
          patients: [
            for (final p in patientDocs)
              LabOption(p.id, '${p.data()['name'] ?? 'Paciente'}'),
          ],
          plans: [
            for (final p in planDocs)
              LabOption(
                p.id,
                'Tratamento ${p.id}',
                patientId: p.data()['patientId']?.toString(),
              ),
          ],
          suppliers: (results[2] as List<SupplierModel>)
              .where(
                (s) =>
                    s.category.toLowerCase().contains('lab') &&
                    !s.isProfessional,
              )
              .toList(),
          dentists: results[3] as List<UserModel>,
          onCreate: (order) async {
            if (SessionManager().currentClinicId != clinic) {
              throw StateError('A unidade foi alterada. Abra um novo pedido.');
            }
            await service.createOrder(order);
          },
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o pedido: $e')),
      );
    }
  }
}

class LabOrderDialog extends StatefulWidget {
  const LabOrderDialog({
    super.key,
    required this.orderId,
    required this.clinicId,
    required this.patients,
    required this.plans,
    required this.suppliers,
    required this.dentists,
    required this.onCreate,
    this.initialPatientId,
  });
  final String orderId, clinicId;
  final String? initialPatientId;
  final List<LabOption> patients, plans;
  final List<SupplierModel> suppliers;
  final List<UserModel> dentists;
  final Future<void> Function(LabOrderModel) onCreate;
  @override
  State<LabOrderDialog> createState() => _LabOrderDialogState();
}

class _LabOrderDialogState extends State<LabOrderDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _cost = TextEditingController();
  String? _patient, _supplier, _dentist, _plan, _type;
  bool? _hasCost;
  bool _saving = false;
  String? _error;
  DateTime _delivery = DateTime.now().add(const Duration(days: 7));
  DateTime _due = DateTime.now();
  @override
  void initState() {
    super.initState();
    _patient = widget.initialPatientId;
  }

  @override
  void dispose() {
    _description.dispose();
    _cost.dispose();
    super.dispose();
  }

  Widget _dropdown(
    String label,
    String? value,
    List<LabOption> options,
    ValueChanged<String?> onChanged, {
    bool required = false,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('lab-$label-$_patient'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final o in options)
        DropdownMenuItem(
          value: o.id,
          child: Text(o.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _saving ? null : onChanged,
    validator: (v) => required && v == null ? 'Selecione $label' : null,
  );

  Widget _date(String label, DateTime value, ValueChanged<DateTime> changed) =>
      OutlinedButton.icon(
        onPressed: _saving
            ? null
            : () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(DateTime.now().year + 10),
                );
                if (date != null && mounted) setState(() => changed(date));
              },
        icon: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text('$label: ${formatDateFull(value)}'),
      );

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_hasCost == null) {
      setState(() => _error = 'Informe se houve custo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final patient = widget.patients.firstWhere((p) => p.id == _patient);
    final supplier = widget.suppliers.firstWhere((s) => s.id == _supplier);
    final dentist = widget.dentists.where((d) => d.id == _dentist).firstOrNull;
    final cost = _hasCost == true
        ? double.parse(parseBRL(_cost.text).toStringAsFixed(2))
        : 0.0;
    try {
      await widget.onCreate(
        LabOrderModel(
          id: widget.orderId,
          clinicId: widget.clinicId,
          patientId: patient.id,
          patientName: patient.name,
          supplierId: supplier.id,
          supplierName: supplier.name,
          dentistId: dentist?.id,
          dentistName: dentist?.name,
          relatedPlanId: _plan,
          description: _description.text.trim(),
          procedureName: _description.text.trim(),
          price: cost,
          costDueDate: _hasCost == true ? _due : null,
          deliveryDate: _delivery,
          createdAt: DateTime.now(),
          status: 'pending_send',
          workType: _type,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Pedido não confirmado: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Novo Pedido de Laboratório'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dropdown(
                  'Paciente',
                  _patient,
                  widget.patients,
                  widget.initialPatientId != null
                      ? (_) {}
                      : (v) => setState(() {
                          _patient = v;
                          _plan = null;
                        }),
                  required: true,
                ),
                const SizedBox(height: 14),
                _dropdown(
                  'Laboratório',
                  _supplier,
                  [for (final s in widget.suppliers) LabOption(s.id, s.name)],
                  (v) => setState(() => _supplier = v),
                  required: true,
                ),
                if (widget.suppliers.isEmpty)
                  const Text(
                    'Cadastre um fornecedor na categoria Laboratório em Gestão antes de criar o pedido.',
                  ),
                const SizedBox(height: 14),
                _dropdown('Solicitante (opcional)', _dentist, [
                  for (final d in widget.dentists) LabOption(d.id, d.name),
                ], (v) => setState(() => _dentist = v)),
                const SizedBox(height: 14),
                _dropdown(
                  'Tratamento (opcional)',
                  _plan,
                  widget.plans.where((p) => p.patientId == _patient).toList(),
                  (v) => setState(() => _plan = v),
                ),
                const SizedBox(height: 14),
                _dropdown('Tipo (opcional)', _type, [
                  for (final t in ['Prótese', 'Alinhador', 'Exame', 'Outros'])
                    LabOption(t, t),
                ], (v) => setState(() => _type = v)),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('lab-description'),
                  controller: _description,
                  enabled: !_saving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição do trabalho',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a descrição'
                      : null,
                ),
                const SizedBox(height: 14),
                _date('Previsão de entrega', _delivery, (d) => _delivery = d),
                const SizedBox(height: 14),
                const Text(
                  'Houve custo com este pedido?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in [false, true])
                      ChoiceChip(
                        label: Text(
                          v ? 'Sim, gerar conta a pagar' : 'Não houve custo',
                        ),
                        selected: _hasCost == v,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                _hasCost = v;
                                _error = null;
                              }),
                      ),
                  ],
                ),
                if (_hasCost == true) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('lab-cost'),
                    controller: _cost,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Custo do laboratório',
                      prefixText: 'R\$ ',
                    ),
                    validator: (v) =>
                        !parseBRL(v ?? '').isFinite || double.parse(parseBRL(v ?? '').toStringAsFixed(2)) <= 0
                        ? 'Informe um custo maior que zero'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _date('Vencimento do custo', _due, (d) => _due = d),
                  const Text(
                    'Será criada uma conta pendente em Relatórios → A Pagar. O pagamento ao laboratório é registrado por lá.',
                  ),
                ],
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
          child: Text(_saving ? 'Criando…' : 'Criar pedido'),
        ),
      ],
    ),
  );
}
