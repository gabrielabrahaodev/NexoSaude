import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/session_manager.dart';
import '../../services/agenda_professionals.dart';
import '../../services/appointment_service.dart';
import '../../services/patient_service.dart';
import '../../services/portal_mirror.dart';
import '../../models/appointment_model.dart';
import '../../models/patient_model.dart';
import '../../ui/app_theme.dart';
import '../../utils/display.dart';
import '../../widgets/patient_procedure_tags.dart';
import '../patients/clinical_patient_view.dart';
import '../../utils/report_export.dart' show reportMoney;
import '../../widgets/clinical_booking_calendar.dart';
import 'clinical_agenda_view.dart';

class AgendaFormScreen extends StatefulWidget {
  final String? editAppointmentId;
  final Map<String, dynamic>? initialData;
  const AgendaFormScreen({super.key, this.editAppointmentId, this.initialData});
  @override
  State<AgendaFormScreen> createState() => _AgendaFormScreenState();
}

class _AgendaFormScreenState extends State<AgendaFormScreen> {
  final AppointmentService _apptService = AppointmentService();
  final PatientService _patientService = PatientService();

  final String _openedClinic = SessionManager().currentClinicId ?? '';
  final String _bookingId = FirebaseFirestore.instance.collection('appointments').doc().id;
  Map<String, bool> _tags = {};
  bool _saving = false;
  String? _attemptPatient;
  bool _fitIn = false;
  String? _slotsError;
  int _availabilityVersion = 0;
  final _notesCtrl = TextEditingController();
  Map<String, dynamic>? _patientDetails;
  final Map<String, Map<String, dynamic>> _catalog = {};
  final Map<String, Future<Map<String, dynamic>>> _risk = {};
  String? _professionalName;
  Future<void> _loadProfessional() async {
    final id = widget.initialData?['dentistId']?.toString() ?? SessionManager().userId;
    if (id == null) return;
    try { final doc = await FirebaseFirestore.instance.collection('clinics').doc(_openedClinic).collection('members').doc(id).get();
      if (mounted && SessionManager().currentClinicId == _openedClinic) setState(() => _professionalName = doc.data()?['name']?.toString());
    } catch (_) {}
  }

  Future<void> _chooseProcedure() async {
    try {
    final snapshot = await FirebaseFirestore.instance.collection('procedures').where('clinicId', isEqualTo: _openedClinic).get();
    if (!mounted || SessionManager().currentClinicId != _openedClinic) return;
    _catalog.addEntries(snapshot.docs.map((d) => MapEntry(d.id, d.data())));
    final selected = await showDialog<String>(context: context, builder: (c) => SimpleDialog(title: const Text('Tabela de Procedimentos e Valores'), children: [for (final d in snapshot.docs.where((d) => d.data()['active'] != false)) SimpleDialogOption(onPressed: () => Navigator.pop(c, d.id), child: Text('${d.data()['name']} • ${reportMoney(parseBRL(d.data()['price']))}'))]));
    if (selected != null && mounted) setState(() => _procedureCtrl.text = '${_catalog[selected]?['name'] ?? ''}');
    } catch (_) { if (mounted) toast(context, 'Não foi possível carregar a tabela de procedimentos.'); }
  }

  // Dados do Agendamento
  String? _selectedPatientName;
  String? _selectedPatientId;
  late DateTime _selectedDate;
  List<String> _selectedTimes = [];

  // Lista de horários forçados (clicados na tela anterior)
  List<String> _forcedAvailableTimes = [];

  // Aceite LGPD no cadastro rápido (default desmarcado).
  bool _lgpdQuickConsent = false;

  final _procedureCtrl = TextEditingController();

  List<String> _timeSlots = [];
  List<String> _occupiedSlots = [];
  bool _isLoadingSlots = false;

  // --- CONTROLADORES DO MODAL ---
  final _nameNewCtrl = TextEditingController();
  final _phoneNewCtrl = TextEditingController();
  final _cpfNewCtrl = TextEditingController();
  final _rgNewCtrl = TextEditingController();
  final _birthNewCtrl = TextEditingController();
  final _addressNewCtrl = TextEditingController();

  final maskPhone = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final maskCPF = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final maskDate = MaskTextInputFormatter(mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});

  // Busca de paciente com debounce (1 query por pausa, não por tecla).
  Timer? _searchDebounce;

  Future<Iterable<Map<String, dynamic>>> _searchPatients(
      TextEditingValue value, String? clinicId) {
    _searchDebounce?.cancel();
    final q = value.text.trim().toLowerCase();
    if (q.length < 2 || clinicId == null) {
      return Future.value(const Iterable.empty());
    }
    final completer = Completer<Iterable<Map<String, dynamic>>>();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        var snapshot = await FirebaseFirestore.instance.collection('patients')
            .where('clinicId', isEqualTo: clinicId)
            .where('searchKey', isGreaterThanOrEqualTo: q)
            .where('searchKey', isLessThan: '${q}z')
            .limit(10)
            .get();
        if (!completer.isCompleted) {
          completer.complete(snapshot.docs
              .map((doc) => {...doc.data(), 'name': doc['name'], 'id': doc.id}));
        }
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _procedureCtrl.dispose();
    _notesCtrl.dispose();
    _nameNewCtrl.dispose();
    _phoneNewCtrl.dispose();
    _cpfNewCtrl.dispose();
    _rgNewCtrl.dispose();
    _birthNewCtrl.dispose();
    _addressNewCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // 1. DATA LIMPA: Remove horas/minutos/segundos para evitar conflito
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    _generateTimeSlots();
    _loadProfessional();

    if (widget.initialData != null) {
      _selectedPatientName = widget.initialData!['patientName'];
      _selectedPatientId = widget.initialData!['patientId'];

      var rawDate = widget.initialData!['date'];
      DateTime dt = rawDate is Timestamp ? rawDate.toDate() : (rawDate as DateTime);
      // Normaliza a data vinda da tela anterior
      _selectedDate = DateTime(dt.year, dt.month, dt.day);

      if (widget.initialData!.containsKey('date')) {
         DateTime start = dt;
         int duration = widget.initialData!['durationMinutes'] ?? 30;
         int slots = (duration / 30).ceil();

         for (int i = 0; i < slots; i++) {
            DateTime slotTime = start.add(Duration(minutes: 30 * i));
            String timeStr = "${slotTime.hour.toString().padLeft(2,'0')}:${slotTime.minute.toString().padLeft(2,'0')}";

            // Só adiciona se o horário existir na grade
            if (_timeSlots.contains(timeStr)) {
               _selectedTimes.add(timeStr);
               // IMPORTANTE: Adiciona este horário à lista de proteção
               _forcedAvailableTimes.add(timeStr);
            }
         }
      }
      _procedureCtrl.text = widget.initialData!['procedure'] ?? '';
      _notesCtrl.text = widget.initialData!['notes'] ?? '';
      _fitIn = widget.initialData!['isFitIn'] == true;
      _tags = {for (final id in (widget.initialData!['procedureTagIds'] as List? ?? []).whereType<String>()) id: false};
    }

    // Inicia verificação após setup inicial
    _checkAvailability();
  }

  void _generateTimeSlots() {
    // Grade das 08:00 às 20:00
    int startMin = 8 * 60;
    int endMin = 20 * 60;
    List<String> slots = [];
    for (int i = startMin; i <= endMin; i += 30) {
      slots.add("${(i ~/ 60).toString().padLeft(2,'0')}:${(i % 60).toString().padLeft(2,'0')}");
    }
    setState(() => _timeSlots = slots);
  }

  // --- LÓGICA DE VERIFICAÇÃO DE DISPONIBILIDADE ---
  Future<void> _checkAvailability() async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;

    final version = ++_availabilityVersion;
    setState(() { _isLoadingSlots = true; _slotsError = null; });

    try {
      // Define intervalo exato do dia (00:00:00 até 23:59:59)
      DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      DateTime endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance.collection('appointments')
          .where('clinicId', isEqualTo: clinicId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      List<String> busyList = [];

      for (var doc in snapshot.docs) {
        if (widget.editAppointmentId != null && doc.id == widget.editAppointmentId) continue;

        final data = doc.data();
        final targetProfessional = agendaBookingProfessionalId(
          role: SessionManager().userRole, userId: SessionManager().userId,
          selectedId: widget.initialData?['dentistId']?.toString());
        final occupiedProfessional = (data['dentistId'] ?? data['userId'])?.toString();
        if (targetProfessional != null && occupiedProfessional != null &&
            occupiedProfessional != targetProfessional) continue;
        String status = (data['status'] ?? '').toString().toLowerCase();

        if (status == 'cancelado') continue;

        DateTime apptDate = (data['date'] as Timestamp).toDate();
        int duration = data['durationMinutes'] ?? 30;
        int slotsOccupied = (duration / 30).ceil();

        for (int i = 0; i < slotsOccupied; i++) {
          DateTime slotTime = apptDate.add(Duration(minutes: 30 * i));
          String timeStr = "${slotTime.hour.toString().padLeft(2,'0')}:${slotTime.minute.toString().padLeft(2,'0')}";
          busyList.add(timeStr);
        }
      }

      if (!mounted || version != _availabilityVersion) return;
      setState(() {
        _occupiedSlots = busyList;
        // Se houver horários selecionados que agora estão ocupados (e não são forçados), remove
        _selectedTimes.removeWhere((t) => busyList.contains(t) && !_forcedAvailableTimes.contains(t));
      });

    } catch (e) {
      if (mounted && version == _availabilityVersion) setState(() => _slotsError = 'Não foi possível conferir os horários. Tente outra data ou reabra a tela.');
    } finally {
      if (mounted && version == _availabilityVersion) setState(() => _isLoadingSlots = false);
    }
  }

  void _showNewPatientModal() {
    _nameNewCtrl.clear(); _phoneNewCtrl.clear(); _cpfNewCtrl.clear();
    _rgNewCtrl.clear(); _birthNewCtrl.clear(); _addressNewCtrl.clear();
    _lgpdQuickConsent = false;

    final formKeyModal = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModal) {
          return AlertDialog(
            title: const Text("Novo Paciente Rápido"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKeyModal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameNewCtrl,
                        decoration: const InputDecoration(labelText: "Nome *", border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneNewCtrl,
                        inputFormatters: [maskPhone],
                        decoration: const InputDecoration(labelText: "Telefone", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _rgNewCtrl, decoration: const InputDecoration(labelText: "RG", border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextFormField(controller: _cpfNewCtrl, inputFormatters: [maskCPF], decoration: const InputDecoration(labelText: "CPF", border: OutlineInputBorder()))),
                        ],
                      ),
                       const SizedBox(height: 10),
                      TextFormField(
                        controller: _birthNewCtrl,
                        inputFormatters: [maskDate],
                        decoration: const InputDecoration(labelText: "Nascimento", border: OutlineInputBorder()),
                      ),
                       const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressNewCtrl,
                        decoration: const InputDecoration(labelText: "Endereço", border: OutlineInputBorder()),
                      ),
                      CheckboxListTile(
                        value: _lgpdQuickConsent,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                            "Autorização LGPD — portal/WhatsApp",
                            style: TextStyle(fontSize: 13)),
                        onChanged: (v) =>
                            setModal(() => _lgpdQuickConsent = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  if (!formKeyModal.currentState!.validate()) return;

                  final currentClinicId = SessionManager().currentClinicId;
                  if (currentClinicId == null) {
                    toast(context, "Erro: Sessão de clínica inválida.");
                    return;
                  }

                  try {
                    final consent = _lgpdQuickConsent;
                    final data = PatientModel(
                      id: '',
                      name: _nameNewCtrl.text.trim(),
                      phone: _phoneNewCtrl.text.trim(),
                      cpf: _cpfNewCtrl.text.trim(),
                      rg: _rgNewCtrl.text.trim(),
                      birthDate: _birthNewCtrl.text.trim(),
                      address: _addressNewCtrl.text.trim(),
                      createdAt: DateTime.now(),
                      clinicId: currentClinicId,
                      searchKey: _nameNewCtrl.text.trim().toLowerCase(),
                      status: 'Ativo',
                    ).toMap()
                      ..['lgpdPortalConsent'] = {
                        'accepted': consent,
                        'at': FieldValue.serverTimestamp(),
                        'via': 'cadastro-rapido',
                      }
                      ..['portalToken'] = consent ? newPortalToken() : '';

                    final newRef = await FirebaseFirestore.instance
                        .collection('patients')
                        .add(data);

                    // Com aceite, o doc portal/{token} já nasce construído:
                    // sem isso, os deltas futuros (sessões) seriam
                    // descartados por doc inexistente.
                    if (consent) {
                      // Falha no espelho é observável (não só debugPrint).
                      if (!await PortalMirrorSync.patient(newRef.id) &&
                          mounted) {
                        toast(context,
                            "Espelho do portal desatualizado — confira no Financeiro.",
                            error: true);
                      }
                    }

                    setState(() {
                      _selectedPatientName = _nameNewCtrl.text.trim();
                      _tags = {};
                      _patientDetails = null;
                      _lgpdQuickConsent = false;
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      toast(context, "Paciente cadastrado! Selecione-o na busca.");
                    }
                  } catch (e) {
                    if (mounted) toast(context, "Erro ao salvar: $e");
                  }
                },
                child: const Text("Salvar"),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.editAppointmentId != null;
    final clinicId = SessionManager().currentClinicId;

    return Theme(data: PatientVisualStyle.forContext(context), child: Scaffold(
      backgroundColor: PatientVisualStyle.background,
      appBar: AppBar(title: Text(isEditing ? 'Alterar Agendamento' : 'Novo Agendamento', style: const TextStyle(fontWeight: FontWeight.w700)), actions: [Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? 120 : 300, child: Text('${SessionManager().currentClinicName ?? 'Unidade ativa'}${_professionalName == null ? '' : ' • $_professionalName'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1220), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PACIENTE
            const Text("1. Paciente", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: isEditing
                    ? Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Text(_selectedPatientName ?? "", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))
                      )
                      : Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (option) => option['name'],
                        optionsBuilder: (textEditingValue) =>
                            _searchPatients(textEditingValue, clinicId),
                        onSelected: (selection) => setState(() {
                          _selectedPatientName = selection['name'];
                          _selectedPatientId = selection['id'];
                          _patientDetails = selection;
                          _tags = {};
                        }),
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          if (_selectedPatientName != null && controller.text.isEmpty) {
                            controller.text = _selectedPatientName!;
                          }
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            onChanged: (v) { if (_selectedPatientName != v && _selectedPatientId != null) setState(() { _selectedPatientId = null; _patientDetails = null; _tags = {}; }); },
                            decoration: const InputDecoration(
                              hintText: "Digite o nome...",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search)
                            ),
                          );
                        },
                      ),
                ),
                if (!isEditing) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _showNewPatientModal,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySoft, foregroundColor: AppColors.primary),
                      child: const Icon(Icons.person_add),
                    ),
                  )
                ]
              ],
            ),

            if (_patientDetails != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('WhatsApp: ${_patientDetails?['phone'] ?? 'Não informado'}', style: TextStyle(color: PatientVisualStyle.textSecondary))),
            if (_selectedPatientId != null)
              FutureBuilder<Map<String, dynamic>>(
                future: _risk.putIfAbsent(_selectedPatientId!, () => _patientService.getPatientRiskProfile(_selectedPatientId!)),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!['level'] != 'red') return const SizedBox();

                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3))
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("ALERTA DE ALTO RISCO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text("Este paciente faltou/cancelou ${snapshot.data!['missed']} vezes recentemente.", style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),

            const SizedBox(height: 20),

            const Text("2. Procedimento", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _procedureCtrl,
              onChanged: (val) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Descrição",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services_outlined),
              ).copyWith(suffixIcon: IconButton(tooltip: 'Tabela de Procedimentos', onPressed: _chooseProcedure, icon: const Icon(Icons.swap_horiz))),
            ),

            const SizedBox(height: 20),

            if (_selectedPatientId != null) ...[
              PatientProcedureTags(key: ValueKey(_selectedPatientId), patientId: _selectedPatientId!, selected: _tags, onChanged: (v) => setState(() => _tags = v)),
              const SizedBox(height: 24),
            ],
            const Text("3. Data e Horários Disponíveis", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (_isLoadingSlots)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
              ],
            ),
            const SizedBox(height: 8),

            ClinicalBookingCalendar(selected: _selectedDate, onChanged: (d) {
              setState(() { _selectedDate = d; _selectedTimes.clear(); _occupiedSlots = []; _forcedAvailableTimes.clear(); });
              _checkAvailability();
            }),
            if (_slotsError != null) Text(_slotsError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _timeSlots.map((time) {
                bool isOccupied = _occupiedSlots.contains(time);
                bool isSelected = _selectedTimes.contains(time);

                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  selectedColor: PatientVisualStyle.accent,
                  disabledColor: AppColors.borderSoft,
                  labelStyle: TextStyle(
                    color: isOccupied ? PatientVisualStyle.textSecondary : isSelected ? ClinicalAgendaStyle.onAccent : PatientVisualStyle.textPrimary
                  ),
                  onSelected: (isOccupied || _isLoadingSlots || _slotsError != null) ? null : (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTimes.add(time);
                      } else {
                        _selectedTimes.remove(time);
                      }
                    });
                  }
                );
              }).toList()
            ),

            const SizedBox(height: 24),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Paciente de Encaixe / Urgência'), subtitle: const Text('Sinaliza a recepção; não cria uma vaga em horário ocupado.'), value: _fitIn, onChanged: (v) => setState(() => _fitIn = v)),
            TextField(controller: _notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações Clínicas ou Recomendações Pré-Atendimento (opcional)')),
            const SizedBox(height: 24),

          ],
        ))),
      ),
      bottomNavigationBar: SafeArea(child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), color: PatientVisualStyle.surface, child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: PatientVisualStyle.accent, foregroundColor: ClinicalAgendaStyle.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: (!_saving && !_isLoadingSlots && _slotsError == null && _selectedTimes.isNotEmpty && _procedureCtrl.text.isNotEmpty) ? () async {
                  if (clinicId == null || clinicId != _openedClinic) return;
                  if (_selectedPatientId == null) {
                     toast(context, "Selecione um Paciente.");
                     return;
                  }
                  final minutes = _selectedTimes.map((t) { final p = t.split(':'); return int.parse(p[0]) * 60 + int.parse(p[1]); }).toList()..sort();
                  if (minutes.last - minutes.first != (minutes.length - 1) * 30) { toast(context, 'Selecione horários consecutivos.'); return; }
                  if (_attemptPatient != null && _attemptPatient != _selectedPatientId) { toast(context, 'Reabra o formulário para agendar outro paciente.'); return; }
                  _attemptPatient = _selectedPatientId;
                  setState(() => _saving = true);
                  try {
                  final finalDentistId = agendaBookingProfessionalId(
                    role: SessionManager().userRole,
                    userId: SessionManager().userId ?? FirebaseAuth.instance.currentUser?.uid,
                    selectedId: widget.initialData?['dentistId']?.toString());
                  if (finalDentistId == null) { setState(() => _saving = false); toast(context, 'Selecione um profissional na Agenda antes de agendar.'); return; }
                  _selectedTimes.sort();
                  String startTime = _selectedTimes.first;
                  DateTime finalDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
                      int.parse(startTime.split(':')[0]), int.parse(startTime.split(':')[1]));
                  final appt = AppointmentModel(
                    id: widget.editAppointmentId ?? _bookingId,
                    patientId: _selectedPatientId!,
                    patientName: _selectedPatientName!,
                    date: finalDT,
                    status: widget.initialData?['status'] ?? 'Aguardando Confirmação',
                    procedure: _procedureCtrl.text.trim(),
                    clinicId: clinicId,
                    dentistId: finalDentistId,
                    procedureTagIds: _tags.keys.toList(),
                    isFitIn: _fitIn,
                    notes: '${_fitIn ? '[Encaixe / Urgência] ' : ''}${_notesCtrl.text.trim()}',
                    durationMinutes: _selectedTimes.length * 30,
                  );
                  if (isEditing) {
                    await _apptService.update(appt);
                  } else {
                    await _apptService.add(appt);
                  }
                  if (mounted) Navigator.pop(context);
                  } catch (e) { if (mounted) { setState(() => _saving = false); toast(context, 'Não foi possível salvar: $e'); } }
                } : null,
                child: Text(_saving ? 'Salvando…' : '✓ Confirmar Agendamento (${_selectedTimes.length * 30} min)')
              )
            ))),
    ));
  }
}
