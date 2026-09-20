import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment_model.dart';
import '../../models/financial_model.dart';
import '../../services/appointment_service.dart';
import '../../services/care_day.dart';
import '../../services/clinical_record_service.dart';
import '../../services/financial_service.dart';
import '../../services/portal_mirror.dart';
import '../../services/session_manager.dart';
import '../../services/whatsapp_helper.dart';
import '../../ui/app_theme.dart';
import '../../utils/display.dart';

/// Ficha de atendimento em 3 blocos (spec 3.1): evolução rápida,
/// cobrança e próxima sessão. Glue fino: regras puras vivem em
/// `care_day.dart` (testado); escritas usam os services existentes.
class CareVisitScreen extends StatefulWidget {
  final AppointmentModel appointment;
  const CareVisitScreen({super.key, required this.appointment});

  @override
  State<CareVisitScreen> createState() => _CareVisitScreenState();
}

class _CareVisitScreenState extends State<CareVisitScreen> {
  final _detailsCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _template;
  String _method = 'Pix';
  bool _evolutionSaved = false;
  bool _saving = false;
  String? _phone;
  DateTime? _nextDate;

  // Cobrança: nova ou baixa de existente (aba Pagamentos).
  bool _useExisting = false;
  List<FinancialModel> _openCharges = [];
  String? _selectedChargeId;
  bool _loadingCharges = false;

  static const _methods = [
    'Dinheiro',
    'Pix',
    'Cartão de crédito',
    'Cartão de débito',
  ];

  @override
  void initState() {
    super.initState();
    _loadPhone();
    _loadOpenCharges();
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  /// Em aberto do paciente (igual à aba Pagamentos): não-pagos e não-cancelados.
  Future<void> _loadOpenCharges() async {
    setState(() => _loadingCharges = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('financial')
          .where('patientId', isEqualTo: widget.appointment.patientId)
          .limit(50)
          .get();
      final list = <FinancialModel>[];
      for (final d in snap.docs) {
        final m = d.data();
        final status = '${m['status'] ?? ''}'.toLowerCase();
        if (status == 'cancelado') continue;
        if (FinancialModel.isPaidOf(
          status: '${m['status'] ?? ''}',
          paidAmount: parseBRL(m['paidAmount']),
          amount: parseBRL(m['amount']),
        )) continue;
        list.add(FinancialModel.fromMap(d.id, m));
      }
      list.sort((a, b) {
        final da = a.dueDate ?? a.date;
        final db = b.dueDate ?? b.date;
        return da.compareTo(db);
      });
      if (mounted) setState(() => _openCharges = list);
    } catch (_) {
      // Sem em-aberto: segue só com nova cobrança.
    } finally {
      if (mounted) setState(() => _loadingCharges = false);
    }
  }

  Future<void> _loadPhone() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.appointment.patientId)
          .get();
      if (mounted) setState(() => _phone = '${doc.data()?['phone'] ?? ''}');
    } catch (_) {
      // Sem telefone: avisa só na hora de chamar no WhatsApp.
    }
  }

  Future<void> _saveEvolution() async {
    final text = ((_template ?? '') +
            (_detailsCtrl.text.trim().isEmpty
                ? ''
                : '\n${_detailsCtrl.text.trim()}'))
        .trim();
    if (text.isEmpty) {
      toast(context, "Escolha um modelo ou descreva a evolução.");
      return;
    }
    setState(() => _saving = true);
    try {
      final a = widget.appointment;
      await ClinicalRecordService().add({
        'clinicId': a.clinicId,
        'treatmentId': null,
        'patientId': a.patientId,
        'patientName': a.patientName,
        'procedureName': a.procedure,
        'description': text,
        'dentistName': SessionManager().userName ?? 'Profissional',
        'date': DateTime.now(),
      });
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(a.id)
          .update({'status': 'Finalizado'});
      if (mounted) {
        setState(() => _evolutionSaved = true);
        toast(context, "Evolução salva.", ok: true);
      }
    } catch (e) {
      if (mounted) toast(context, "Erro ao salvar: $e", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _receiveExisting() async {
    final sel = _openCharges.where((c) => c.id == _selectedChargeId);
    if (sel.isEmpty) {
      toast(context, "Escolha um lançamento em aberto.");
      return;
    }
    final charge = sel.first;
    final remaining = charge.amount - charge.paidAmount;
    if (remaining <= 0) {
      toast(context, "Lançamento já quitado.", error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await FinancialService().processPayment(
        originalTransaction: charge,
        payValue: remaining,
        method: _method,
        installments: 1,
        payerName: widget.appointment.patientName,
        payerCpf: '',
        dentistId: widget.appointment.dentistId,
        dentistName: SessionManager().userName,
      );
      if (mounted) {
        setState(() {
          _openCharges.removeWhere((c) => c.id == charge.id);
          _selectedChargeId = null;
        });
        toast(context, "Recebido ${formatBRL(remaining)}.", ok: true);
      }
    } catch (e) {
      if (mounted) toast(context, "Erro ao receber: $e", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _chargeMap(String id, bool receiveNow) {
    final a = widget.appointment;
    final amount = parseBRL(_amountCtrl.text);
    final rec = FinancialService.recordingFor(_method);
    return FinancialModel(
      id: id,
      clinicId: a.clinicId,
      patientId: a.patientId,
      patientName: a.patientName,
      title:
          "Atendimento ${a.procedure} ${formatDateShort(a.date)}",
      description: '',
      amount: amount,
      paidAmount: receiveNow ? amount : 0.0,
      date: DateTime.now(),
      dueDate: DateTime.now(),
      type: 'income',
      status: receiveNow ? rec.status : 'pendente',
      paymentMethod: _method,
      dentistId: a.dentistId,
      dentistName: SessionManager().userName,
    ).toMap();
  }

  Future<void> _charge(bool receiveNow) async {
    if (parseBRL(_amountCtrl.text) <= 0) {
      toast(context, "Informe o valor da sessão.", error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final ref =
          FirebaseFirestore.instance.collection('financial').doc();
      final map = _chargeMap(ref.id, receiveNow);
      await ref.set(map);
      await PortalMirrorSync.upsertDebt(
        patientId: widget.appointment.patientId,
        debt: {
          'id': ref.id,
          'title': '${map['title'] ?? 'Lançamento'}',
          'amount': (map['amount'] as num?)?.toDouble() ?? 0.0,
          'paidAmount': (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
          'dueDate': (map['dueDate'] as Timestamp?)?.toDate(),
          'status': '${map['status'] ?? ''}',
        },
      );
      if (mounted) {
        toast(
            context,
            receiveNow
                ? "Recebido ${formatBRL(parseBRL(_amountCtrl.text))}."
                : "Lançamento pendente criado.",
            ok: true);
      }
    } catch (e) {
      if (mounted) toast(context, "Erro ao cobrar: $e", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickNext() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _nextDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _scheduleNext() async {
    if (_nextDate == null) {
      toast(context, "Escolha a data da próxima sessão.");
      return;
    }
    setState(() => _saving = true);
    try {
      final a = widget.appointment;
      await AppointmentService().add(AppointmentModel(
        id: '',
        patientId: a.patientId,
        patientName: a.patientName,
        date: _nextDate!,
        status: 'Aguardando Confirmação',
        procedure: a.procedure,
        clinicId: a.clinicId,
        dentistId: a.dentistId,
        durationMinutes: a.durationMinutes,
      ));
      final msg = nextSessionText(
          patientName: a.patientName, date: _nextDate!);
      if ((_phone ?? '').isEmpty) {
        if (mounted) {
          toast(context, "Agendado! Telefone não cadastrado p/ WhatsApp.");
        }
      } else {
        await WhatsAppHelper.openWhatsApp(phone: _phone!, message: msg);
      }
      if (mounted) setState(() => _nextDate = null);
    } catch (e) {
      if (mounted) toast(context, "Erro ao agendar: $e", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final templates =
        attendanceTemplates(SessionManager().clinicType);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(a.patientName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "${formatDateTimeShort(a.date)} • ${a.procedure} • ${a.status}",
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 16),
          // 1. EVOLUÇÃO
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("1. Evolução", style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final t in templates)
                        ChoiceChip(
                          label: Text(t,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          selected: _template == t,
                          onSelected: (_) =>
                              setState(() => _template = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _detailsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: "Detalhes (opcional)",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed:
                              _evolutionSaved ? null : _saveEvolution,
                          icon: Icon(_evolutionSaved
                              ? Icons.check
                              : Icons.save_outlined),
                          label: Text(_evolutionSaved
                              ? "Evolução salva"
                              : "Salvar evolução"),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 2. COBRANÇA (nova ou baixa de existente)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("2. Cobrança", style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text("Nova"),
                          icon: Icon(Icons.add, size: 18)),
                      ButtonSegment(
                          value: true,
                          label: Text("Em aberto"),
                          icon: Icon(Icons.list_alt, size: 18)),
                    ],
                    selected: {_useExisting},
                    onSelectionChanged: (s) =>
                        setState(() => _useExisting = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_useExisting) ...[
                    if (_loadingCharges)
                      const Center(
                          child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)))
                    else if (_openCharges.isEmpty)
                      const Text(
                          "Nada em aberto. Volte para Nova."),
                    if (_openCharges.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedChargeId,
                        decoration: InputDecoration(
                            labelText: "Lançamento",
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12))),
                        items: [
                          for (final c in _openCharges)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                "${c.title} — ${formatBRL(c.amount - c.paidAmount)}",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(
                            () => _selectedChargeId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _method,
                              decoration: InputDecoration(
                                  labelText: "Meio",
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12))),
                              items: [
                                for (final m in _methods)
                                  DropdownMenuItem(
                                      value: m, child: Text(m)),
                              ],
                              onChanged: (v) => setState(
                                  () => _method = v ?? 'Pix'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving
                                  ? null
                                  : _receiveExisting,
                              child: const Text("Receber"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                              labelText: "Valor (R\$)",
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _method,
                          decoration: InputDecoration(
                              labelText: "Meio",
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12))),
                          items: [
                            for (final m in _methods)
                              DropdownMenuItem(
                                  value: m, child: Text(m)),
                          ],
                          onChanged: (v) =>
                              setState(() => _method = v ?? 'Pix'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _saving ? null : () => _charge(false),
                          child: const Text("Lançar pendente"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _saving ? null : () => _charge(true),
                          child: const Text("Receber agora"),
                        ),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 3. PRÓXIMA SESSÃO
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("3. Próxima sessão", style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(_nextDate == null
                            ? "Nenhuma data escolhida"
                            : DateFormat('dd/MM HH:mm')
                                .format(_nextDate!)),
                      ),
                      TextButton(
                          onPressed: _pickNext,
                          child: const Text("Escolher data")),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _scheduleNext,
                    icon: const Icon(Icons.send_outlined),
                    label:
                        const Text("Agendar e chamar no WhatsApp"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
