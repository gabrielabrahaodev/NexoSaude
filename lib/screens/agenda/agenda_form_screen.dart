import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'clinical_booking_view.dart';
import '../../models/patient_list_entry.dart' show patientMaskedCpf;

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
  TextEditingController? _patientSearchController;
  Future<void> _loadPatientContext() async {
    final id = _selectedPatientId;
    if (id == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('patients').doc(id).get();
      if (mounted && _selectedPatientId == id && doc.data()?['clinicId'] == _openedClinic) setState(() => _patientDetails = doc.data());
    } catch (_) {}
  }
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
  StreamSubscription<List<String>>? _availabilitySubscription;

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
    _availabilitySubscription?.cancel();
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
            }
         }
      }
      _procedureCtrl.text = widget.initialData!['procedure'] ?? '';
      _notesCtrl.text = widget.initialData!['notes'] ?? '';
      _fitIn = widget.initialData!['isFitIn'] == true;
      _tags = {for (final id in (widget.initialData!['procedureTagIds'] as List? ?? []).whereType<String>()) id: false};
    }

    // Inicia verificação após setup inicial
    _loadPatientContext();
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
  String? get _bookingProfessional => agendaBookingProfessionalId(
      role: SessionManager().userRole, userId: SessionManager().userId,
      selectedId: widget.initialData?['dentistId']?.toString());

  void _applyBusySlots(List<String> busy) {
    _occupiedSlots = busy;
    _selectedTimes.removeWhere(busy.contains);
  }

  Future<void> _checkAvailability() async {
    final version = ++_availabilityVersion;
    setState(() { _isLoadingSlots = true; _slotsError = null; });
    await _availabilitySubscription?.cancel();
    if (!mounted || version != _availabilityVersion) return;
    if (SessionManager().currentClinicId != _openedClinic || _bookingProfessional == null) {
      setState(() { _isLoadingSlots = false; _slotsError = 'Selecione um profissional na Agenda e reabra o formulário.'; });
      return;
    }
    _availabilitySubscription = _apptService.watchBusySlots(_openedClinic, _selectedDate,
      excludeId: widget.editAppointmentId, dentistId: _bookingProfessional).listen((busy) {
        if (!mounted || version != _availabilityVersion || SessionManager().currentClinicId != _openedClinic) return;
        setState(() { _applyBusySlots(busy); _isLoadingSlots = false; _slotsError = null; });
      }, onError: (Object error) {
        if (!mounted || version != _availabilityVersion) return;
        setState(() { _isLoadingSlots = false; _slotsError = 'Não foi possível conferir os horários. Tente outra data ou reabra a tela.'; });
      });
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

  Future<void> _saveBooking() async {
    if (_saving || _isLoadingSlots || _slotsError != null || _selectedTimes.isEmpty) return;
    final clinicId = SessionManager().currentClinicId;
    final isEditing = widget.editAppointmentId != null;
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
                  final chosenTimes = _selectedTimes.toList();
                  final busy = await _apptService.getBusySlots(clinicId, _selectedDate,
                      excludeId: widget.editAppointmentId, dentistId: finalDentistId);
                  if (!mounted) return;
                  if (SessionManager().currentClinicId != _openedClinic) throw StateError('Unidade alterada. Reabra a Agenda.');
                  if (chosenTimes.any(busy.contains) || chosenTimes.any((t) => !_selectedTimes.contains(t))) {
                    setState(() { _applyBusySlots(busy); _saving = false; });
                    toast(context, 'Este horário foi ocupado. Selecione outro horário livre.', error: true);
                    return;
                  }
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
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editAppointmentId != null;
    final clinicId = SessionManager().currentClinicId;
    final compact = MediaQuery.sizeOf(context).width >= 1000;
    final procedure = _catalog.values.where((d) => d['name'] == _procedureCtrl.text).firstOrNull;
    final patientField = isEditing
      ? Align(alignment: Alignment.centerLeft, child: Text(_selectedPatientName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)))
      : Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (option) => '${option['name']}',
          optionsBuilder: (value) => _searchPatients(value, clinicId),
          onSelected: (selection) => setState(() { _selectedPatientName = selection['name']; _selectedPatientId = selection['id']; _patientDetails = selection; _tags = {}; }),
          fieldViewBuilder: (context, controller, focus, onComplete) {
            _patientSearchController = controller;
            if (_selectedPatientName != null && controller.text.isEmpty) controller.text = _selectedPatientName!;
            return TextField(controller: controller, focusNode: focus, onEditingComplete: onComplete,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              onChanged: (value) { if (value != _selectedPatientName && _selectedPatientId != null) setState(() { _selectedPatientId = null; _patientDetails = null; _tags = {}; }); },
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), hintText: 'Busque o paciente pelo nome...', prefixIcon: Icon(Icons.search, size: 18), border: OutlineInputBorder()));
          });
    final risk = _selectedPatientId == null ? null : FutureBuilder<Map<String, dynamic>>(
      future: _risk.putIfAbsent(_selectedPatientId!, () => _patientService.getPatientRiskProfile(_selectedPatientId!)),
      builder: (context, snapshot) => snapshot.data?['level'] != 'red' ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 6), child: Text('Atenção ao histórico: ${snapshot.data?['missed']} falta(s)/cancelamento(s) recentes.', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
    );
    final cpf = patientMaskedCpf('${_patientDetails?['cpf'] ?? ''}');
    final record = '${_patientDetails?['recordNumber'] ?? _patientDetails?['prontuario'] ?? _patientDetails?['medicalRecordNumber'] ?? ''}';
    return Theme(data: PatientVisualStyle.forContext(context), child: ClinicalBookingView(
      title: isEditing ? 'Alterar Agendamento' : 'Novo Agendamento',
      clinic: SessionManager().currentClinicName ?? 'Unidade ativa', professional: _professionalName,
      patientField: patientField, recordNumber: record,
      patientSummary: _selectedPatientId == null ? null : 'CPF: ${cpf.isEmpty ? 'Não informado' : cpf}  •  WhatsApp: ${_patientDetails?['phone'] ?? 'Não informado'}',
      onNewPatient: isEditing ? null : _showNewPatientModal,
      onChangePatient: isEditing ? null : () => setState(() { _selectedPatientName = null; _selectedPatientId = null; _patientDetails = null; _tags = {}; _patientSearchController?.clear(); }),
      procedureField: TextField(controller: _procedureCtrl, onChanged: (_) => setState(() {}), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: 'Selecione ou descreva o procedimento')),
      procedureCategory: procedure?['category']?.toString(), procedurePrice: procedure == null ? null : parseBRL(procedure['price']),
      onProcedure: _chooseProcedure,
      tags: _selectedPatientId == null ? const Padding(padding: EdgeInsets.all(12), child: Text('Selecione o paciente para vincular as Tags do plano.', style: TextStyle(fontSize: 12))) : PatientProcedureTags(key: ValueKey(_selectedPatientId), patientId: _selectedPatientId!, selected: _tags, compact: compact, onChanged: (v) => setState(() => _tags = v)),
      risk: risk, notesController: _notesCtrl, selectedDate: _selectedDate,
      times: _timeSlots, selectedTimes: _selectedTimes, occupiedTimes: _occupiedSlots,
      loading: _isLoadingSlots, error: _slotsError, saving: _saving, fitIn: _fitIn,
      onFitIn: (v) => setState(() => _fitIn = v),
      onDate: (d) { setState(() { _selectedDate = d; _selectedTimes.clear(); _occupiedSlots = []; }); _checkAvailability(); },
      onTime: (time) => setState(() { if (_selectedTimes.contains(time)) { _selectedTimes.remove(time); } else { _selectedTimes.add(time); } }),
      onCancel: () => Navigator.pop(context),
      onSave: !_saving && !_isLoadingSlots && _slotsError == null && _selectedTimes.isNotEmpty && _procedureCtrl.text.trim().isNotEmpty && _selectedPatientId != null ? _saveBooking : null,
    ));
  }
}
