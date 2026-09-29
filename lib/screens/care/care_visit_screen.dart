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
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../services/whatsapp_helper.dart';
import '../../ui/app_theme.dart';
import '../../utils/display.dart';
import '../../utils/external_link.dart';

/// Ficha de atendimento em 3 blocos (spec 3.1): evolução rápida,
/// cobrança e próxima sessão. Glue fino: regras puras vivem em
/// `care_day.dart` (testado); escritas usam os services existentes.
///
/// `CareVisitScreen` = rota push (compat). `CareVisitPanel` = mesmo
/// conteúdo embutível (modal do Meu dia, sem nova tela).
class CareVisitScreen extends StatelessWidget {
  final AppointmentModel appointment;
  const CareVisitScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(appointment.patientName)),
      body: CareVisitPanel(appointment: appointment),
    );
  }
}

class CareVisitPanel extends StatefulWidget {
  final AppointmentModel appointment;
  const CareVisitPanel({super.key, required this.appointment});

  @override
  State<CareVisitPanel> createState() => _CareVisitPanelState();
}

class _CareVisitPanelState extends State<CareVisitPanel> {
  final _detailsCtrl = TextEditingController();
  String? _template;
  String _method = 'Pix';
  bool _evolutionSaved = false;
  bool _saving = false;
  String? _phone;
  DateTime? _nextDate;

  // Cobrança: SOMENTE baixa de lançamento existente (criado em Pagamentos).
  List<FinancialModel> _openCharges = [];
  String? _selectedChargeId;
  bool _loadingCharges = false;

  // Próxima sessão: profissional (padrão = do agendamento atual).
  List<UserModel> _nextDentists = [];
  String? _nextDentistId;

  static const _methods = [
    'Dinheiro',
    'Pix',
    'Cartão de crédito',
    'Cartão de débito',
  ];

  @override
  void initState() {
    super.initState();
    _nextDentistId = widget.appointment.dentistId;
    _loadPhone();
    _loadOpenCharges();
    _loadNextDentists();
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  /// Profissionais da clínica p/ a próxima sessão.
  Future<void> _loadNextDentists() async {
    try {
      final clinicId = widget.appointment.clinicId;
      final list = await UserService().getDentistsForClinic(clinicId);
      if (!mounted) return;
      setState(() {
        _nextDentists = list;
        // Padrão = dentista do agendamento atual (se ainda atender).
        if ((_nextDentistId ?? '').isEmpty ||
            !list.any((d) => d.id == _nextDentistId)) {
          _nextDentistId =
              list.isNotEmpty ? list.first.id : widget.appointment.dentistId;
        }
      });
    } catch (_) {}
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

  Future<void> _repeatNextWeek() async {
    final a = widget.appointment;
    final candidate = AppointmentService.repeatNextWeek(a.date);
    final did = (_nextDentistId?.isNotEmpty == true
            ? _nextDentistId
            : a.dentistId) ??
        '';
    final hhmm =
        "${candidate.hour.toString().padLeft(2, '0')}:${candidate.minute.toString().padLeft(2, '0')}";
    final busy = await AppointmentService()
        .getBusySlots(a.clinicId, candidate, dentistId: did);
    if (!mounted) return;
    if (busy.contains(hhmm)) {
      toast(context, "Horário ocupado na próxima semana.",
          error: true);
      return;
    }
    setState(() => _nextDate = candidate);
    await _scheduleNext();
  }

  Future<void> _pickNext() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final a = widget.appointment;
    final did = (_nextDentistId?.isNotEmpty == true
            ? _nextDentistId
            : a.dentistId) ??
        '';
    // Somente horários livres DESSE profissional.
    final busy = await AppointmentService()
        .getBusySlots(a.clinicId, date, dentistId: did);
    final grade = await clinicGrade(a.clinicId);
    final free = grade.where((t) => !busy.contains(t)).toList();
    if (free.isEmpty) {
      if (mounted) {
        toast(context, "Dia sem horário livre para este profissional.");
      }
      return;
    }
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Horários livres"),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in free)
                ChoiceChip(
                  label: Text(t),
                  selected: false,
                  onSelected: (_) => Navigator.pop(ctx, t),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
    if (picked == null) return;
    final parts = picked.split(':');
    setState(() => _nextDate = DateTime(date.year, date.month, date.day,
        int.parse(parts[0]), int.parse(parts[1])));
  }

  Future<void> _scheduleNext() async {
    final tab = openBlankTab();
    if (_nextDate == null) {
      try {
        tab?.close();
      } catch (_) {}
      toast(context, "Escolha a data da próxima sessão.");
      return;
    }
    setState(() => _saving = true);
    try {
      final a = widget.appointment;
      final did = (_nextDentistId?.isNotEmpty == true
              ? _nextDentistId
              : a.dentistId) ??
          '';
      // Revalida no vivo (alguém pode ter ocupado após a escolha).
      final hhmm =
          "${_nextDate!.hour.toString().padLeft(2, '0')}:${_nextDate!.minute.toString().padLeft(2, '0')}";
      final busy = await AppointmentService()
          .getBusySlots(a.clinicId, _nextDate!, dentistId: did);
      if (busy.contains(hhmm)) {
        if (mounted) {
          toast(context,
              "Horário ocupado para este profissional. Escolha outro.",
              error: true);
        }
        return;
      }
      await AppointmentService().add(AppointmentModel(
        id: '',
        patientId: a.patientId,
        patientName: a.patientName,
        date: _nextDate!,
        status: 'Aguardando Confirmação',
        procedure: a.procedure,
        clinicId: a.clinicId,
        dentistId: did.isEmpty ? a.dentistId : did,
        durationMinutes: a.durationMinutes,
      ));
      final msg = nextSessionText(
          patientName: a.patientName, date: _nextDate!);
      if ((_phone ?? '').isEmpty) {
        try {
          tab?.close();
        } catch (_) {}
        if (mounted) {
          toast(context, "Agendado! Telefone não cadastrado p/ WhatsApp.");
        }
      } else {
        await openWhatsAppSafe(context, tab, phone: _phone!, message: msg);
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
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
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
          // 2. COBRANÇA (somente baixa de existente — novo lançamento
          // nasce na aba Pagamentos).
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("2. Cobrança", style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  if (_loadingCharges)
                    const Center(
                        child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)))
                  else if (_openCharges.isEmpty)
                    const Text(
                        "Nada em aberto. Crie o lançamento na aba Pagamentos."),
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
                  DropdownButtonFormField<String>(
                    value: _nextDentists.any((d) => d.id == _nextDentistId)
                        ? _nextDentistId
                        : null,
                    decoration: InputDecoration(
                        labelText: "Profissional",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    items: [
                      for (final d in _nextDentists)
                        DropdownMenuItem(
                            value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() {
                      _nextDentistId = v;
                      _nextDate = null;
                    }),
                  ),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _saving ? null : _repeatNextWeek,
                          icon: const Icon(Icons.repeat, size: 18),
                          label: const Text("Repetir próxima semana"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _scheduleNext,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text("Agendar e chamar no WhatsApp"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }
}
