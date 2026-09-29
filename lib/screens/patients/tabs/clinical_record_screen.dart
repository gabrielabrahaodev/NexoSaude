import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../../../ui/app_theme.dart';
import '../../../services/session_manager.dart';
import '../../../services/clinical_record_service.dart';
import '../../../services/treatment_service.dart';
import '../../../utils/display.dart'; // Import para buscar tratamentos
import '../../../widgets/status_chip.dart';

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

  // Modal para Adicionar/Editar
  void _showAddNoteModal({DocumentSnapshot? docToEdit}) {
    if (docToEdit != null) {
      final data = docToEdit.data() as Map<String, dynamic>;
      _noteController.text = data['description'] ?? '';
      _selectedProcedure = data['procedureName'];
      _selectedTreatmentId = data['treatmentId'];
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
                      stream: _treatmentService.getPlansStream(widget.patientId),
                      builder: (context, snapshot) {
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
                          value: _selectedTreatmentId,
                          hint: const Text("Selecione o Tratamento"),
                          isExpanded: true,
                          items: activePlans.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final date = (data['startDate'] as Timestamp).toDate();
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text("Iniciado em ${formatDateShortYear(date)}"),
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
                      value: _selectedProcedure,
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  if (_noteController.text.trim().isEmpty) return;
                  
                  final clinicId = SessionManager().currentClinicId;
                  final data = {
                    'clinicId': clinicId,
                    'treatmentId': _selectedTreatmentId ?? docToEdit?['treatmentId'], // Mantém ID se editando
                    'patientId': widget.patientId,
                    'patientName': widget.patientName,
                    'procedureName': _selectedProcedure ?? 'Geral',
                    'description': _noteController.text.trim(),
                    'dentistName': SessionManager().userName ?? 'Dr(a).',
                    'date': docToEdit == null ? DateTime.now() : (docToEdit['date'] as Timestamp).toDate(),
                  };

                  if (docToEdit == null) {
                    await _service.add(data);
                  } else {
                    await _service.update(docToEdit.id, data);
                  }
                  
                  if (mounted) Navigator.pop(context);
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
  Widget build(BuildContext context) {
    // REMOVIDO SCAFFOLD PARA CABER NA ABA
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _service.getByPatient(widget.patientId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text("Erro ao carregar."));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_edu, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    const Text("Nenhum registro clínico encontrado.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            
              return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Espaço para o FAB
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp).toDate();
                // Cobrança (WhatsApp) vs atendimento: visual distinto.
                final isCharge =
                    '${data['procedureName'] ?? ''}' ==
                        'Cobrança via WhatsApp';
                final accent =
                    isCharge ? Colors.green : AppColors.primary;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: accent.withValues(alpha: 0.4))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(
                                    data['procedureName'] ??
                                        'Procedimento',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold))),
                            StatusChip(
                              label:
                                  isCharge ? "Cobrança" : "Atendimento",
                              color: accent,
                              horizontal: 8,
                              vertical: 2,
                              fontSize: 10,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(formatDateTimeFull(date),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text("Realizado por: ${data['dentistName'] ?? 'Profissional'}", style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                        const Divider(),
                        Text(data['description'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
                        
                        Align(
                          alignment: Alignment.centerRight, 
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.grey), 
                                onPressed: () => _showAddNoteModal(docToEdit: doc)
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red), 
                                onPressed: () async {
                                  final confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Excluir?"), actions: [TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Não")), TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Sim"))]));
                                  if (confirm == true) await _service.delete(doc.id);
                                }
                              ),
                            ],
                          )
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        
        // FAB FLUTUANTE MANUALMENTE POSICIONADO (Já que não temos Scaffold)
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddNoteModal(), 
            label: const Text("NOVO REGISTRO"), 
            icon: const Icon(Icons.edit_note),
            backgroundColor: AppColors.primary,
          ),
        )
      ],
    );
  }
}