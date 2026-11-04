import '../clinical_records_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../../../services/session_manager.dart';
import '../../../services/clinical_record_service.dart';
import '../../../services/treatment_service.dart';
import '../../../utils/display.dart'; // Import para buscar tratamentos

class ClinicalRecordTab extends StatefulWidget {
  final String patientName;
  final String patientId; 

  // Removemos treatmentId e procedures do construtor, pois agora é uma aba geral
  const ClinicalRecordTab({
    super.key, 
    required this.patientName, 
    required this.patientId, 
  });

  @override
  State<ClinicalRecordTab> createState() => _ClinicalRecordTabState();
}

class _ClinicalRecordTabState extends State<ClinicalRecordTab> {
  final ClinicalRecordService _service = ClinicalRecordService();
  final TreatmentService _treatmentService = TreatmentService();
  final _noteController = TextEditingController();
  
  String? _selectedTreatmentId;
  String? _selectedProcedure;
  List<dynamic> _proceduresOfSelectedPlan = [];

  late Stream<QuerySnapshot> _records = _service.getByPatient(widget.patientId);

  @override
  void didUpdateWidget(covariant ClinicalRecordTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) _records = _service.getByPatient(widget.patientId);
  }

  @override
  void dispose() { _noteController.dispose(); super.dispose(); }

  // Modal para Adicionar/Editar
  void _showAddNoteModal({DocumentSnapshot? docToEdit}) {
    final openedClinic = SessionManager().currentClinicId;
    final openedPatient = widget.patientId;
    final plans = _treatmentService.getPlansStream(openedPatient);
    bool saving = false;
    String? error;
    if (docToEdit != null) {
      final data = docToEdit.data() as Map<String, dynamic>;
      _noteController.text = data['description'] ?? '';
      _selectedProcedure = data['procedureName'];
      _selectedTreatmentId = data['treatmentId'];
      _proceduresOfSelectedPlan = [];
      // Se for edição, idealmente carregaríamos os procedimentos daquele tratamento, 
      // mas para simplificar, permitimos editar o texto.
    } else {
      _noteController.clear();
      _selectedProcedure = null;
      _selectedTreatmentId = null;
      _proceduresOfSelectedPlan = [];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: Text(docToEdit == null ? "Nova Evolução" : "Editar Registro"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. SELECIONAR TRATAMENTO (Novo passo)
                  if (docToEdit == null) ...[
                    StreamBuilder<QuerySnapshot>(
                      stream: plans,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return const Text('Não foi possível carregar os tratamentos. Você pode salvar uma evolução geral.');
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        
                        // Apenas planos ativos
                        final activePlans = snapshot.data!.docs.where((doc) {
                           final d = doc.data() as Map<String, dynamic>;
                           return d['status'] == 'active';
                        }).toList();

                        if (activePlans.isEmpty) {
                          return const Text("Nenhum tratamento ativo para vincular.", style: TextStyle(color: Colors.red, fontSize: 12));
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedTreatmentId,
                          hint: const Text("Selecione o Tratamento"),
                          isExpanded: true,
                          items: activePlans.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final rawDate = data['startDate'];
                            final date = rawDate is Timestamp ? rawDate.toDate() : null;
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(date == null ? 'Tratamento sem data cadastrada' : 'Iniciado em ${formatDateShortYear(date)}'),
                              onTap: () {
                                setStateModal(() {
                                  _proceduresOfSelectedPlan = List.from(data['items'] ?? []);
                                  _selectedProcedure = null; // Reseta procedimento
                                });
                              },
                            );
                          }).toList(),
                          onChanged: (val) => setStateModal(() => _selectedTreatmentId = val),
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                        );
                      }
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 2. SELECIONAR PROCEDIMENTO (Baseado no tratamento)
                  if (_selectedTreatmentId != null || docToEdit != null) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProcedure,
                      hint: const Text("Procedimento Realizado"),
                      isExpanded: true,
                      items: _proceduresOfSelectedPlan.isEmpty && docToEdit != null
                        ? [DropdownMenuItem(value: _selectedProcedure, child: Text(_selectedProcedure ?? 'Original'))] // Fallback edição
                        : _proceduresOfSelectedPlan.map<DropdownMenuItem<String>>((item) {
                          String val = item is Map ? item['name'] : item.toString();
                          return DropdownMenuItem(value: val, child: Text(val));
                        }).toList(),
                      onChanged: (val) => setStateModal(() => _selectedProcedure = val),
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Descrição da Evolução",
                      hintText: "Descreva o que foi feito, observações...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: saving ? null : () async {
                  if (_noteController.text.trim().isEmpty) return;
                  
                  final clinicId = SessionManager().currentClinicId;
                  if (clinicId == null || clinicId != openedClinic || widget.patientId != openedPatient) {
                    setStateModal(() => error = 'A unidade ou paciente mudou. Feche e reabra o formulário.'); return;
                  }
                  setStateModal(() { saving = true; error = null; });
                  final data = <String, dynamic>{
                    'clinicId': clinicId,
                    'treatmentId': _selectedTreatmentId ?? docToEdit?['treatmentId'], // Mantém ID se editando
                    'patientId': widget.patientId,
                    'patientName': widget.patientName,
                    'procedureName': _selectedProcedure ?? 'Geral',
                    'description': _noteController.text.trim(),
                    if (docToEdit == null) ...{
                      'dentistName': SessionManager().userName ?? 'Não informado',
                      'operatorName': SessionManager().userName ?? 'Não informado',
                      'date': DateTime.now(),
                    } else ...{
                      'editedBy': SessionManager().userName ?? 'Não informado',
                      'editedAt': FieldValue.serverTimestamp(),
                    },
                  };

                  try {
                  if (docToEdit == null) {
                    await _service.add(data);
                  } else {
                    await _service.update(docToEdit.id, data);
                  }
                  
                  if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (context.mounted) setStateModal(() { saving = false; error = 'Não foi possível salvar. Seu texto foi mantido.'; });
                  }
                },
                child: const Text("Salvar"),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: _records,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Center(child: Text('Não foi possível carregar o prontuário. Reabra a ficha para tentar novamente.'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final docs = {for (final doc in snapshot.data!.docs) doc.id: doc};
      return ClinicalRecordsView(
        records: docs.values.map((d) => ClinicalRecordEntry(d.id, Map<String, dynamic>.from(d.data() as Map))).toList(),
        onNew: () => _showAddNoteModal(),
        onEdit: (id) => _showAddNoteModal(docToEdit: docs[id]),
        onDelete: (id) async {
          final clinic = SessionManager().currentClinicId;
          final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Excluir registro?'), content: const Text('Esta ação remove o registro do prontuário.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir'))]));
          if (confirm != true || !mounted || clinic != SessionManager().currentClinicId) return;
          try { await _service.delete(id); }
          catch (_) { if (mounted && context.mounted) toast(context, 'Não foi possível excluir o registro.', error: true); }
        },
      );
    },
  );
}
