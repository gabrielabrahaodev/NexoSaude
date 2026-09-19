import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/session_manager.dart';
import '../../services/appointment_service.dart';
import '../../services/patient_service.dart'; 
import '../../models/appointment_model.dart';
import '../../models/patient_model.dart';
import '../../utils/display.dart';

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

  // Dados do Agendamento
  String? _selectedPatientName;
  String? _selectedPatientId;
  late DateTime _selectedDate; 
  List<String> _selectedTimes = [];
  
  // Lista de horários forçados (clicados na tela anterior)
  List<String> _forcedAvailableTimes = [];

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

  @override
  void initState() {
    super.initState();
    
    // 1. DATA LIMPA: Remove horas/minutos/segundos para evitar conflito
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    _generateTimeSlots();
    
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

    setState(() => _isLoadingSlots = true);

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
      
      setState(() {
        _occupiedSlots = busyList;
        // Se houver horários selecionados que agora estão ocupados (e não são forçados), remove
        _selectedTimes.removeWhere((t) => busyList.contains(t) && !_forcedAvailableTimes.contains(t));
      });

    } catch (e) {
      debugPrint("Erro ao buscar slots: $e");
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  void _showNewPatientModal() {
    _nameNewCtrl.clear(); _phoneNewCtrl.clear(); _cpfNewCtrl.clear();
    _rgNewCtrl.clear(); _birthNewCtrl.clear(); _addressNewCtrl.clear();

    final formKeyModal = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Novo Paciente Rápido"),
        content: SizedBox(
          width: 500,
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Sessão de clínica inválida.")));
                return;
              }

              try {
                // CORREÇÃO AQUI: Adicionados campos rg, birthDate e status
                final newPatient = PatientModel(
                  id: '', 
                  name: _nameNewCtrl.text.trim(),
                  phone: _phoneNewCtrl.text.trim(),
                  cpf: _cpfNewCtrl.text.trim(),
                  rg: _rgNewCtrl.text.trim(), // Adicionado
                  birthDate: _birthNewCtrl.text.trim(), // Adicionado
                  address: _addressNewCtrl.text.trim(), 
                  createdAt: DateTime.now(),
                  clinicId: currentClinicId,
                  searchKey: _nameNewCtrl.text.trim().toLowerCase(),
                  status: 'Ativo', // Adicionado para seguir o padrão
                );

                await _patientService.add(newPatient);
                
                setState(() {
                  _selectedPatientName = newPatient.name;
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paciente cadastrado! Selecione-o na busca.")));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
              }
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.editAppointmentId != null;
    final clinicId = SessionManager().currentClinicId;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Alterar" : "Novo Agendamento")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20), 
        child: Column(
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
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), 
                        child: Text(_selectedPatientName ?? "", style: const TextStyle(fontWeight: FontWeight.bold))
                      )
                    : Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (option) => option['name'],
                        optionsBuilder: (textEditingValue) async {
                          if (textEditingValue.text.isEmpty) return const Iterable.empty();
                          
                          var snapshot = await FirebaseFirestore.instance.collection('patients')
                              .where('clinicId', isEqualTo: clinicId)
                              .where('searchKey', isGreaterThanOrEqualTo: textEditingValue.text.toLowerCase())
                              .where('searchKey', isLessThan: '${textEditingValue.text.toLowerCase()}z')
                              .limit(10)
                              .get();
                              
                          return snapshot.docs.map((doc) => {'name': doc['name'], 'id': doc.id});
                        },
                        onSelected: (selection) => setState(() { 
                          _selectedPatientName = selection['name']; 
                          _selectedPatientId = selection['id']; 
                        }),
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          if (_selectedPatientName != null && controller.text.isEmpty) {
                            controller.text = _selectedPatientName!;
                          }
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[50], foregroundColor: Colors.blue),
                      child: const Icon(Icons.person_add),
                    ),
                  )
                ]
              ],
            ),

            if (_selectedPatientId != null)
              FutureBuilder<Map<String, dynamic>>(
                future: _patientService.getPatientRiskProfile(_selectedPatientId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!['level'] != 'red') return const SizedBox();
                  
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
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
                prefixIcon: Icon(Icons.medical_services_outlined)
              ),
            ),

            const SizedBox(height: 20),

            const Text("3. Data e Horários", style: TextStyle(fontWeight: FontWeight.bold)),
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
            
            SizedBox(
              height: 280,
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                onDateChanged: (d) {
                  setState(() { 
                    _selectedDate = DateTime(d.year, d.month, d.day); 
                    _selectedTimes.clear(); 
                    _occupiedSlots = []; 
                    _forcedAvailableTimes.clear(); 
                  });
                  _checkAvailability();
                },
              ),
            ),
            
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
                  selectedColor: Colors.greenAccent, 
                  disabledColor: Colors.grey[300],
                  labelStyle: TextStyle(
                    color: slotCardColor(
                        isOccupied: isOccupied, isSelected: isSelected)
                  ),
                  onSelected: isOccupied ? null : (selected) {
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
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity, 
              height: 50, 
              child: ElevatedButton(
                onPressed: (_selectedTimes.isNotEmpty && _procedureCtrl.text.isNotEmpty) ? () async {
                  if (clinicId == null) return;
                  if (_selectedPatientId == null) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione um Paciente.")));
                     return;
                  }
                  String? finalDentistId;
                  final userRole = SessionManager().userRole;
                  if (userRole == 'dentista') {
                    finalDentistId = FirebaseAuth.instance.currentUser?.uid;
                  } else {
                    finalDentistId = widget.initialData?['dentistId'];
                  }
                  _selectedTimes.sort();
                  String startTime = _selectedTimes.first;
                  DateTime finalDT = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 
                      int.parse(startTime.split(':')[0]), int.parse(startTime.split(':')[1]));
                  final appt = AppointmentModel(
                    id: widget.editAppointmentId ?? '',
                    patientId: _selectedPatientId!,
                    patientName: _selectedPatientName!,
                    date: finalDT,
                    status: 'Aguardando Confirmação',
                    procedure: _procedureCtrl.text.trim(),
                    clinicId: clinicId,
                    dentistId: finalDentistId,
                    durationMinutes: _selectedTimes.length * 30, 
                  );
                  if (isEditing) {
                    await _apptService.update(appt);
                  } else {
                    await _apptService.add(appt);
                  }
                  if (mounted) Navigator.pop(context); 
                } : null, 
                child: Text("SALVAR (${_selectedTimes.length * 30} min)")
              )
            )
          ],
        ),
      ),
    );
  }
}