import 'package:flutter/material.dart';
import '../../../models/supplier_model.dart';
import '../../../services/supplier_service.dart';
import '../../../services/session_manager.dart';
import '../../../ui/app_theme.dart';

class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key});

  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  final SupplierService _service = SupplierService();

  // Categorias padrão para facilitar
  final List<String> _categories = [
    'Laboratório de Prótese', 
    'Dentista Parceiro', 
    'Materiais de Consumo', 
    'Manutenção', 
    'Serviços Gerais', 
    'Impostos/Taxas'
  ];

  void _showEditDialog({SupplierModel? model}) {
    final nameCtrl = TextEditingController(text: model?.name);
    final taxCtrl = TextEditingController(text: model?.taxId); // CPF ou CNPJ
    final phoneCtrl = TextEditingController(text: model?.phone);
    
    // Estado local do Dialog
    String selectedCategory = model?.category ?? _categories.first;
    bool isProfessional = model?.isProfessional ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: Text(model == null ? "Novo Fornecedor" : "Editar Fornecedor"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome / Razão Social")),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _categories.contains(selectedCategory) ? selectedCategory : _categories.first,
                    decoration: const InputDecoration(labelText: "Categoria"),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setStateModal(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: taxCtrl, decoration: const InputDecoration(labelText: "CPF ou CNPJ"), keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefone / WhatsApp"), keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  const Divider(),
                  SwitchListTile(
                    title: const Text("É Dentista da Equipe?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Marque se este fornecedor recebe comissão (repasse).", style: TextStyle(fontSize: 12)),
                    value: isProfessional,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setStateModal(() => isProfessional = val),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  final clinicId = SessionManager().currentClinicId;
                  if (clinicId == null || nameCtrl.text.isEmpty) return;

                  final newModel = SupplierModel(
                    id: model?.id ?? '', 
                    clinicId: clinicId,
                    name: nameCtrl.text,
                    category: selectedCategory,
                    taxId: taxCtrl.text,
                    phone: phoneCtrl.text,
                    isProfessional: isProfessional,
                  );
                  
                  await _service.save(newModel);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: Colors.purple, // Cor diferente para destacar
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<List<SupplierModel>>(
        stream: _service.getAllStream(),
        builder: (context, snapshot) {
          // --- TRATAMENTO DE ERRO (LINK DE ÍNDICE) ---
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 10),
                  const Text("Erro ao carregar fornecedores.", style: TextStyle(color: Colors.red)),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText(
                      "${snapshot.error}", 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontSize: 12, color: Colors.grey)
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final list = snapshot.data!;

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("Nenhum fornecedor cadastrado."),
                  const SizedBox(height: 5),
                  const Text("Cadastre laboratórios, dentistas ou serviços.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = list[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.isProfessional ? Colors.blue[100] : Colors.purple[100],
                  child: Icon(
                    item.isProfessional ? Icons.medical_services : Icons.store, 
                    color: item.isProfessional ? Colors.blue : Colors.purple
                  ),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${item.category} • ${item.phone}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: () => _showEditDialog(model: item)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _service.delete(item.id)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}