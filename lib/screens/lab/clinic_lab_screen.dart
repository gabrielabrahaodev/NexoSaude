import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import '../../services/lab_service.dart';
import '../../widgets/lab_kanban_board.dart';
import '../../services/supplier_service.dart';
import '../../models/supplier_model.dart';
import '../../services/user_service.dart'; 
import '../../models/user_model.dart';
import '../../models/lab_order.dart'; // IMPORT CORRIGIDO

class ClinicLabScreen extends StatefulWidget {
  const ClinicLabScreen({super.key});

  @override
  State<ClinicLabScreen> createState() => _ClinicLabScreenState();
}

class _ClinicLabScreenState extends State<ClinicLabScreen> {
  final LabService _labService = LabService();
  final SupplierService _supplierService = SupplierService();
  final UserService _userService = UserService(); 
  
  String _searchQuery = "";
  String? _selectedSupplierId;
  String? _selectedDentistId; 

  List<SupplierModel> _suppliers = [];
  List<UserModel> _dentists = []; 

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId != null) {
      // Carrega laboratórios
      try {
        final allSuppliers = await _supplierService.getAllStream().first;
        // Filtra apenas laboratórios (opcional, dependendo de como você classifica)
        _suppliers = allSuppliers; 
      } catch (e) { debugPrint("$e"); }

      // Carrega dentistas
      try {
        _dentists = await _userService.getDentistsForClinic(clinicId);
      } catch (e) { debugPrint("$e"); }

      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager().currentClinicId;

    if (clinicId == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // --- CABEÇALHO E FILTROS ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Gestão de Laboratório (Kanban)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                

              Row(
                children: [
                  // 1. BUSCA (Elástica - Ocupa a maior parte: flex 4)
                  Expanded(
                    flex: 4, 
                    child: TextField(
                      // Mantenha seu InputDecoration e onChanged aqui
                      decoration: const InputDecoration(
                                        hintText: "Buscar Paciente...",
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                                      ),
                                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    ),
                  ),
                  
                  const SizedBox(width: 12), // Espaço fixo pequeno entre os itens
                  
                  // 2. PRIMEIRO DROPDOWN (Elástico - flex 3)
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true, // 🔥 A MÁGICA AQUI: Impede o overflow interno!
                      value: _selectedSupplierId,
                                      decoration: const InputDecoration(
                                        hintText: "Todos Laboratórios",
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                                      ),
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text("Todos")),
                                        ..._suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                                      ],
                                      onChanged: (val) => setState(() => _selectedSupplierId = val),
                    ),
                  ),
                  
                  const SizedBox(width: 12), // Espaço fixo pequeno entre os itens
                  
                  // 3. SEGUNDO DROPDOWN (Elástico - flex 3)
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true, // 🔥 A MÁGICA AQUI TAMBÉM!
                    value: _selectedDentistId,
                                      decoration: const InputDecoration(
                                        hintText: "Todos Dentistas",
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                                      ),
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text("Todos")),
                                        ..._dentists.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)))
                                      ],
                                      onChanged: (val) => setState(() => _selectedDentistId = val),
                    ),
                  ),
                ],
              )
              ],
            ),
          ),
          
          // --- KANBAN BOARD ---
          Expanded(
            child: StreamBuilder<List<LabOrderModel>>(
              stream: _labService.getByClinic(clinicId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // Aplica filtros na memória
                List<LabOrderModel> filteredList = snapshot.data!.where((order) {
                  bool matchesName = _searchQuery.isEmpty || order.patientName.toLowerCase().contains(_searchQuery);
                  bool matchesSupplier = _selectedSupplierId == null || order.supplierId == _selectedSupplierId;
                  bool matchesDentist = _selectedDentistId == null || order.dentistId == _selectedDentistId;

                  return matchesName && matchesSupplier && matchesDentist;
                }).toList();

                return LabKanbanBoard(
                  orders: filteredList,
                  showPatientName: true, // Mostra o nome do paciente no card
                );
              },
            ),
          )
        ],
      ),
    );
  }
}