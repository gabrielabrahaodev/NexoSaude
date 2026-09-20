import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/session_manager.dart';
import '../../models/psychology_schedule_model.dart';
import '../../models/appointment_model.dart';
import '../../ui/app_theme.dart';
import '../../utils/display.dart';

class PsychologyScheduleFormScreen extends StatefulWidget {
  final String? editScheduleId;
  final Map<String, dynamic>? initialData;
  // Novos parâmetros vindos da agenda
  final DateTime? preSelectedDate;
  final String? preSelectedDayOfWeek;
  final String? preSelectedTime;
  
  const PsychologyScheduleFormScreen({
    super.key, 
    this.editScheduleId, 
    this.initialData,
    this.preSelectedDate,
    this.preSelectedDayOfWeek,
    this.preSelectedTime,
  });
  
  @override
  State<PsychologyScheduleFormScreen> createState() => _PsychologyScheduleFormScreenState();
}

class _PsychologyScheduleFormScreenState extends State<PsychologyScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Patient
  String? _selectedPatientName;
  String? _selectedPatientId;

  // Schedule Type
  PsychologyScheduleType _scheduleType = PsychologyScheduleType.package;

  // Common fields
  late DateTime _startDate;
  String _selectedDayOfWeek = 'Segunda';
  String _selectedTime = '09:00';

  // Package fields
  final _packageValueCtrl = TextEditingController();
  final _sessionValueCtrl = TextEditingController();

  // Third party
  bool _fromThirdParty = false;
  final _thirdPartyDiscountCtrl = TextEditingController();

  // Contrato ativo? (edição) — cancelado esconde o botão de cancelar
  bool _isActive = true;
  bool _isCancelling = false;

  final _daysOfWeek = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  final _timeSlots = _generateDefaultTimeSlots();
  
  // Flags para saber se campos vieram pré-preenchidos (travados)
  bool get _isDateLocked => widget.preSelectedDate != null;
  bool get _isDayLocked => widget.preSelectedDayOfWeek != null;
  bool get _isTimeLocked => widget.preSelectedTime != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    
    // Inicializa com valores da agenda se fornecidos, senão usa padrão
    _startDate = widget.preSelectedDate ?? DateTime(now.year, now.month, now.day);
    if (_startDate != widget.preSelectedDate) {
      _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    }
    
    _selectedDayOfWeek = widget.preSelectedDayOfWeek ?? 'Segunda';
    _selectedTime = widget.preSelectedTime ?? '09:00';

    if (widget.initialData != null) {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    _selectedPatientName = data['patientName'];
    _selectedPatientId = data['patientId'];
    _scheduleType = data['scheduleType'] == 'session' ? PsychologyScheduleType.session : PsychologyScheduleType.package;

    var rawDate = data['startDate'];
    _startDate = rawDate is Timestamp ? rawDate.toDate() : (rawDate as DateTime);
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);

    _selectedDayOfWeek = data['dayOfWeek'] ?? 'Segunda';
    _selectedTime = data['time'] ?? '09:00';
    _isActive = (data['status']?.toString() ?? 'active') == 'active';
    _packageValueCtrl.text = (data['packageValue'] ?? 0.0).toString();
    _sessionValueCtrl.text = (data['sessionValue'] ?? 0.0).toString();
    _fromThirdParty = data['fromThirdParty'] ?? false;
    _thirdPartyDiscountCtrl.text = (data['thirdPartyDiscount'] ?? 0.0).toString();
  }

  static List<String> _generateDefaultTimeSlots() {
    final slots = <String>[];
    for (int h = 7; h <= 20; h++) {
      for (int m = 0; m < 60; m += 30) {
        slots.add("${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}");
      }
    }
    return slots;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      toast(context, "Selecione um paciente");
      return;
    }

    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;

    final schedule = PsychologyScheduleModel(
      id: widget.editScheduleId ?? '',
      clinicId: clinicId,
      patientId: _selectedPatientId!,
      patientName: _selectedPatientName!,
      scheduleType: _scheduleType,
      startDate: _startDate,
      dayOfWeek: _selectedDayOfWeek,
      time: _selectedTime,
      packageValue: double.tryParse(_packageValueCtrl.text) ?? 0.0,
      sessionValue: double.tryParse(_sessionValueCtrl.text) ?? 0.0,
      fromThirdParty: _fromThirdParty,
      thirdPartyDiscount: double.tryParse(_thirdPartyDiscountCtrl.text) ?? 0.0,
      status: 'active',
      createdAt: DateTime.now(),
    );

    try {
      if (widget.editScheduleId != null) {
        await FirebaseFirestore.instance
            .collection('psychology_schedules')
            .doc(widget.editScheduleId)
            .update(schedule.toMap());
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('psychology_schedules')
            .add(schedule.toMap());

        // Generate appointments/procedures
        await _generateAppointments(docRef.id, schedule);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Agendamento salvo e sessões geradas!")),
        );
      }
    } catch (e) {
      if (mounted) toast(context, "Erro: $e");
    }
  }

  Future<void> _generateAppointments(String scheduleId, PsychologyScheduleModel schedule) async {
    final clinicId = SessionManager().currentClinicId!;
    // Avulsa: somente a data selecionada. Pacote: recorrência semanal até 31/12.
    final List<DateTime> sessionDates;
    if (_scheduleType == PsychologyScheduleType.session) {
      final timeParts = schedule.time.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 8;
      final minute =
          timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      sessionDates = [
        DateTime(_startDate.year, _startDate.month, _startDate.day, hour, minute)
      ];
    } else {
      final endOfYear = DateTime(_startDate.year, 12, 31, 23, 59);
      sessionDates = schedule.generateSessionDates(endDate: endOfYear);
    }

    if (sessionDates.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    // Cria o plano de tratamento ("procedimentos do paciente")
    final planRef = FirebaseFirestore.instance.collection('treatment_plans').doc();
    final planItems = sessionDates.asMap().entries.map((entry) {
      return {
        'name': _scheduleType == PsychologyScheduleType.package
            ? 'Sessão de Psicologia ${entry.key + 1} (Pacote)'
            : 'Sessão de Psicologia (Avulsa)',
        'sessionNumber': entry.key + 1,
        'date': Timestamp.fromDate(entry.value),
        'status': 'pendente',
        'scheduleId': scheduleId,
      };
    }).toList();

    batch.set(planRef, {
      'clinicId': clinicId,
      'patientId': schedule.patientId,
      'patientName': schedule.patientName,
      'scheduleId': scheduleId,
      'scheduleType': _scheduleType.name,
      'totalValue': schedule.effectiveValue,
      'sessionValue': _scheduleType == PsychologyScheduleType.package && schedule.sessionValue <= 0
          ? schedule.packageValue / sessionDates.length
          : schedule.sessionValue,
      'thirdPartyDiscount': schedule.thirdPartyDiscount,
      'startDate': Timestamp.fromDate(_startDate),
      'dayOfWeek': schedule.dayOfWeek,
      'time': schedule.time,
      'status': 'active',
      'items': planItems,
      'type': 'psychology',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Para pacote: gera registros financeiros agrupados por mês
    // Para avulso: gera um registro financeiro por sessão
    if (_scheduleType == PsychologyScheduleType.package) {
      // Agrupa sessões por mês (YYYY-MM)
      final Map<String, List<DateTime>> sessionsByMonth = {};
      for (final date in sessionDates) {
        final key = "${date.year}-${date.month.toString().padLeft(2, '0')}"; // "2025-01"
        sessionsByMonth.putIfAbsent(key, () => []).add(date);
      }

      final sortedMonthKeys = sessionsByMonth.keys.toList()..sort();
      final totalMonths = sortedMonthKeys.length;
      int monthIndex = 0;

      // Cada pacote mensal tem o MESMO valor do pacote total definido na tela
      final monthlyPackageValue = schedule.packageValue;

      for (final monthKey in sortedMonthKeys) {
        final monthSessions = sessionsByMonth[monthKey]!;
        monthIndex++;
        final totalSessions = monthSessions.length;
        final amount = monthlyPackageValue; // Valor fixo por mês = valor do pacote

        // Due date = fixed day (10th of next month)
        final year = int.parse(monthKey.split('-')[0]);
        final month = int.parse(monthKey.split('-')[1]);
        final dueDate = DateTime(year, month + 1, 10);

        // Installment format: "Jan/2025 1/3"
        final monthName = DateFormat('MMM/yyyy', 'pt_BR').format(DateTime(year, month));
        final installmentNumber = "$monthName $monthIndex/$totalMonths";

        final finRef = FirebaseFirestore.instance.collection('financial').doc();
        batch.set(finRef, {
          'clinicId': clinicId,
          'patientId': schedule.patientId,
          'patientName': schedule.patientName,
          'title': 'Pacote de Psicologia',
          'description': 'Pacote $monthName - $totalSessions sessões (${schedule.dayOfWeek}s às ${schedule.time})',
          'amount': amount,
          'paidAmount': 0.0,
          'date': Timestamp.fromDate(DateTime.now()),
          'dueDate': Timestamp.fromDate(dueDate),
          'type': 'income',
          'status': 'pending',
          'paymentMethod': '',
          'planId': planRef.id,
          'installmentNumber': installmentNumber,
          'monthlyPeriod': monthKey,
          'billingKind': 'package_monthly',
          'scheduleId': scheduleId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Avulso: uma entrada financeira por sessão
      for (int i = 0; i < sessionDates.length; i++) {
        final finRef = FirebaseFirestore.instance.collection('financial').doc();
        final sessionDate = sessionDates[i];
        batch.set(finRef, {
          'clinicId': clinicId,
          'patientId': schedule.patientId,
          'patientName': schedule.patientName,
          'title': 'Sessão de Psicologia (Avulsa)',
          'description': 'Sessão ${i + 1} (${schedule.dayOfWeek}s às ${schedule.time})',
          'amount': schedule.sessionValue,
          'paidAmount': 0.0,
          'date': Timestamp.fromDate(DateTime.now()),
          'dueDate': Timestamp.fromDate(sessionDate.add(const Duration(days: 7))),
          'type': 'income',
          'status': 'pending',
          'paymentMethod': '',
          'planId': planRef.id,
          'installmentNumber': '${i + 1}/${sessionDates.length}',
          'billingKind': 'session',
          'scheduleId': scheduleId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    for (final sessionDate in sessionDates) {
      final apptRef = FirebaseFirestore.instance.collection('appointments').doc();
      final monthKey =
          "${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}";
      final appt = AppointmentModel(
        id: apptRef.id,
        patientId: schedule.patientId,
        patientName: schedule.patientName,
        date: sessionDate,
        status: 'Aguardando Confirmação',
        procedure: _scheduleType == PsychologyScheduleType.package
            ? 'Pacote Psicologia - Sessão'
            : 'Sessão Avulsa Psicologia',
        clinicId: clinicId,
        durationMinutes: 60,
        scheduleId: scheduleId,
        planId: planRef.id,
        monthlyPeriod: monthKey,
      );
      batch.set(apptRef, appt.toMap());
    }

    await batch.commit();
  }

  Future<void> _confirmCancelSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancelar contrato?"),
        content: const Text(
          "Sessões futuras (não finalizadas) serão canceladas e "
          "cobranças pendentes do plano também.\n\n"
          "Sessões já realizadas e valores pagos NÃO são alterados.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Voltar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("SIM, CANCELAR"),
          ),
        ],
      ),
    );
    if (confirm == true) await _cancelSchedule();
  }

  /// Cancela o contrato: futuras não finalizadas → Cancelado,
  /// financeiros pendentes/pending do plano → Cancelado.
  /// Finalizados e pagos ficam intactos.
  Future<void> _cancelSchedule() async {
    final scheduleId = widget.editScheduleId;
    if (scheduleId == null) return;
    setState(() => _isCancelling = true);

    try {
      final db = FirebaseFirestore.instance;
      final today = DateTime.now();
      final startOfToday =
          DateTime(today.year, today.month, today.day);

      // 1. Sessões futuras do contrato (não finalizadas)
      final apptsSnap = await db
          .collection('appointments')
          .where('scheduleId', isEqualTo: scheduleId)
          .get();

      final planIds = <String>{};
      final futureAppts = <DocumentSnapshot>[];
      for (final doc in apptsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = '${data['status']}'.toLowerCase();
        if (status == 'finalizado' || status == 'cancelado') continue;
        final planId = data['planId']?.toString();
        if (planId != null && planId.isNotEmpty) planIds.add(planId);
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date != null && date.isBefore(startOfToday)) continue;
        futureAppts.add(doc);
      }

      // 2. Financeiros pendentes dos planos do contrato
      final pendingFins = <DocumentSnapshot>[];
      for (final planId in planIds) {
        final finsSnap = await db
            .collection('financial')
            .where('planId', isEqualTo: planId)
            .get();
        for (final doc in finsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = '${data['status']}';
          if (status == 'pendente' || status == 'pending') {
            pendingFins.add(doc);
          }
        }
      }

      // 3. Batch (em blocos de 450 por segurança)
      final writes = <void Function(WriteBatch)>[
        (b) => b.update(
            db.collection('psychology_schedules').doc(scheduleId),
            {'status': 'cancelled'}),
      ];
      for (final doc in futureAppts) {
        writes.add((b) => b.update(doc.reference, {
              'status': 'Cancelado',
              'cancellationSource': 'Clínica',
              'cancellationReason': 'Contrato cancelado',
            }));
      }
      for (final doc in pendingFins) {
        writes.add((b) =>
            b.update(doc.reference, {'status': 'Cancelado'}));
      }

      var batch = db.batch();
      var count = 0;
      for (final w in writes) {
        w(batch);
        count++;
        if (count >= 450) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Contrato cancelado: ${futureAppts.length} sessão(ões) e ${pendingFins.length} cobrança(s) pendentes canceladas."),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao cancelar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showPatientPicker() {
    final clinicId = SessionManager().currentClinicId!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (ctx, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Selecionar Paciente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('patients')
                    .where('clinicId', isEqualTo: clinicId)
                    .where('status', isEqualTo: 'Ativo')
                    .snapshots(),
                builder: (ctx, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['name'] ?? ''),
                        subtitle: Text(data['phone'] ?? ''),
                        onTap: () {
                          setState(() {
                            _selectedPatientName = data['name'];
                            _selectedPatientId = docs[i].id;
                          });
                          Navigator.pop(ctx); // Use ctx do bottom sheet para fechar
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.isDark
            ? const Color(0xFF262B31)
            : AppColors.surface,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editScheduleId != null ? "Editar Agenda Psicologia" : "Nova Agenda Psicologia"),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Paciente
              const Text("1. Paciente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showPatientPicker,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 12),
                      Text(_selectedPatientName ?? "Toque para selecionar"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Tipo de Agendamento
              const Text("2. Tipo de Agendamento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              SegmentedButton<PsychologyScheduleType>(
                segments: const [
                  ButtonSegment(
                    value: PsychologyScheduleType.package,
                    label: Text("Pacote"),
                    icon: Icon(Icons.card_membership),
                  ),
                  ButtonSegment(
                    value: PsychologyScheduleType.session,
                    label: Text("Sessão Avulsa"),
                    icon: Icon(Icons.event),
                  ),
                ],
                selected: {_scheduleType},
                onSelectionChanged: (set) => setState(() => _scheduleType = set.first),
              ),

              const SizedBox(height: 20),

              // 3. Data de Início
              const Text("3. Data de Início", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _isDateLocked
                  ? _buildLockedField(
                      label: "Data de Início (vinda da agenda)",
                      value: formatDateFull(_startDate),
                      icon: Icons.lock,
                    )
                  : InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(formatDateFull(_startDate)),
                      ),
                    ),

              const SizedBox(height: 20),

              // 4. Dia da Semana e Horário
              const Text("4. Dia da Semana e Horário", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _isDayLocked
                        ? _buildLockedField(
                            label: "Dia da Semana",
                            value: _selectedDayOfWeek,
                            icon: Icons.lock,
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedDayOfWeek,
                            items: _daysOfWeek.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (v) => setState(() => _selectedDayOfWeek = v!),
                            decoration: const InputDecoration(labelText: "Dia da Semana", border: OutlineInputBorder()),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isTimeLocked
                        ? _buildLockedField(
                            label: "Horário",
                            value: _selectedTime,
                            icon: Icons.lock,
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedTime,
                            items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _selectedTime = v!),
                            decoration: const InputDecoration(labelText: "Horário", border: OutlineInputBorder()),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 5. Valores
              const Text("5. Valores", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (_scheduleType == PsychologyScheduleType.package) ...[
                TextFormField(
                  controller: _packageValueCtrl,
                  decoration: const InputDecoration(labelText: "Valor do Pacote (Total)", border: OutlineInputBorder(), prefixText: "R\$ "),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? "Obrigatório" : null,
                ),
                const SizedBox(height: 12),
              ] else ...[
                TextFormField(
                  controller: _sessionValueCtrl,
                  decoration: const InputDecoration(labelText: "Valor da Sessão", border: OutlineInputBorder(), prefixText: "R\$ "),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? "Obrigatório" : null,
                ),
                const SizedBox(height: 12),
              ],

              // 6. Veio de Terceiro
              const Text("6. Origem / Desconto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text("Veio de Terceiro (Convênio/Indicação)"),
                value: _fromThirdParty,
                onChanged: (v) => setState(() => _fromThirdParty = v),
              ),
              if (_fromThirdParty) ...[
                TextFormField(
                  controller: _thirdPartyDiscountCtrl,
                  decoration: const InputDecoration(labelText: "Valor do Desconto", border: OutlineInputBorder(), prefixText: "R\$ "),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text("SALVAR E GERAR SESSÕES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (widget.editScheduleId != null && _isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isCancelling ? null : _confirmCancelSchedule,
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined,
                            color: Colors.red),
                    label: const Text("CANCELAR CONTRATO",
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}