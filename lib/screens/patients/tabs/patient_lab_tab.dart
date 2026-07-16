import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/lab_order.dart'; // IMPORT CORRIGIDO
import '../../../services/lab_service.dart';
import '../../../services/treatment_service.dart'; 
import '../../../services/session_manager.dart';
import '../../../services/user_service.dart'; 
import '../../../models/user_model.dart';     
import '../../../widgets/lab_kanban_board.dart'; 

class PatientLabTab extends StatefulWidget {
  final String patientId;
  const PatientLabTab({super.key, required this.patientId});

  @override
  State<PatientLabTab> createState() => _PatientLabTabState();
}

class _PatientLabTabState extends State<PatientLabTab> {
  final LabService _labService = LabService();
  final TreatmentService _treatmentService = TreatmentService();
  final UserService _userService = UserService(); 

  // --- MODAL: NOVO PEDIDO MANUAL ---
  void _showManualOrderDialog() async {
    // ... (MANTENHA A LÓGICA DE BUSCA IGUAL À ANTERIOR)
    QuerySnapshot plansSnapshot;
    try {
      plansSnapshot = await _treatmentService.getPlansStream(widget.patientId).first;
    } catch(e) {
      plansSnapshot = await FirebaseFirestore.instance.collection('treatments').where('patientId', isEqualTo: widget.patientId).get();
    }
    
    final activePlans = plansSnapshot.docs.toList();
    
    List<UserModel> dentists = [];
    final clinicId = SessionManager().currentClinicId;
    if (clinicId != null) {
      dentists = await _userService.getDentistsForClinic(clinicId);
    }

    if (!mounted) return;

    final descCtrl = TextEditingController();
    String? selectedPlanId;
    String selectedPlanName = "";
    String? selectedDentistId; 

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text("Novo Pedido de Lab"),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Vincular a Tratamento (Opcional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        hint: const Text("Selecione..."),
                        value: selectedPlanId,
                        items: activePlans.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          DateTime date = DateTime.now();
                          if (data['startDate'] != null) date = (data['startDate'] as Timestamp).toDate();
                          else if (data['createdAt'] != null) date = (data['createdAt'] as Timestamp).toDate();

                          final total = data['totalValue'] ?? 0;
                          String label = "${DateFormat('dd/MM').format(date)} (R\$ $total)";
                          return DropdownMenuItem(value: doc.id, child: Text(label, style: const TextStyle(fontSize: 13)), onTap: () => selectedPlanName = "Tratamento ${DateFormat('dd/MM').format(date)}");
                        }).toList(),
                        onChanged: (val) => setStateModal(() => selectedPlanId = val),
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 15),
                      
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedDentistId,
                        hint: const Text("Solicitante (Dentista)"),
                        items: dentists.map((user) => DropdownMenuItem(value: user.id, child: Text(user.name))).toList(),
                        onChanged: (val) => setStateModal(() => selectedDentistId = val),
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 15),

                      TextField(
                        controller: descCtrl, 
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: "Descrição do Trabalho", hintText: "Ex: Coroa E-max dente 11, cor A2...", border: OutlineInputBorder())
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    if (descCtrl.text.isEmpty) return;
                    if (clinicId == null) return;
                    
                    String pName = "Paciente";
                    try { final pDoc = await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).get(); pName = pDoc.data()?['name'] ?? "Paciente"; } catch (e) {/* */}

                    String? dName;
                    if (selectedDentistId != null) {
                      try { dName = dentists.firstWhere((d) => d.id == selectedDentistId).name; } catch (e) {}
                    }

                    final newOrder = LabOrderModel(
                      id: '', 
                      clinicId: clinicId, 
                      patientId: widget.patientId, 
                      patientName: pName,
                      dentistId: selectedDentistId, 
                      dentistName: dName,           
                      relatedPlanId: selectedPlanId, 
                      description: descCtrl.text, 
                      procedureName: selectedPlanName, 
                      // MANTIDO 'pending_send' AQUI PARA NÃO QUEBRAR O HÁBITO, MAS O KANBAN AGORA ACEITA
                      status: 'pending_send', 
                      createdAt: DateTime.now(),
                    );
                    await _labService.createOrder(newOrder);
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text("CRIAR PEDIDO"),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualOrderDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Novo Pedido", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<List<LabOrderModel>>(
        stream: _labService.getByPatient(widget.patientId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.science_outlined, size: 50, color: Colors.grey[300]),
                   const SizedBox(height: 10),
                   Text("Nenhum pedido de laboratório.", style: TextStyle(color: Colors.grey[500])),
                 ],
               ),
             );
          }
          
          return LabKanbanBoard(
            orders: orders,
            showPatientName: false, 
          );
        },
      ),
    );
  }
}