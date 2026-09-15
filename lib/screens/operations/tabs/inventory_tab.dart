import 'package:flutter/material.dart';
import '../../../models/inventory_model.dart';
import '../../../services/inventory_service.dart';
import '../../../services/session_manager.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});
  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryService _service = InventoryService();

  void _showEditDialog({InventoryModel? model}) {
    final nameCtrl = TextEditingController(text: model?.name);
    final qtyCtrl = TextEditingController(text: model?.currentQty.toString() ?? '0');
    final minCtrl = TextEditingController(text: model?.minQty.toString() ?? '5');
    final unitCtrl = TextEditingController(text: model?.unit ?? 'un');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model == null ? "Novo Item" : "Editar Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome do Material")),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qtd Atual"))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Mínimo (Alerta)"))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: "Unidade (cx, un, L)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final clinicId = SessionManager().currentClinicId;
              if (clinicId == null) return;

              final newModel = InventoryModel(
                id: model?.id ?? '',
                clinicId: clinicId,
                name: nameCtrl.text,
                currentQty: int.tryParse(qtyCtrl.text) ?? 0,
                minQty: int.tryParse(minCtrl.text) ?? 5,
                unit: unitCtrl.text,
              );
              
              await _service.save(newModel);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<InventoryModel>>(
        stream: _service.getAllStream(),
        builder: (context, snapshot) {
          // --- TRATAMENTO DE ERRO (LINK VAI APARECER AQUI) ---
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 10),
                  const Text("Erro ao carregar estoque.", style: TextStyle(color: Colors.red)),
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
                  Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("Estoque vazio."),
                  const SizedBox(height: 5),
                  const Text("Clique no + para adicionar materiais", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final bool isLow = item.isLowStock;
              final Color statusColor = isLow ? Colors.red : Colors.green;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.inventory_2, color: statusColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Mínimo: ${item.minQty} ${item.unit}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            if (isLow) 
                              const Text("REPOR ESTOQUE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline), 
                        onPressed: () => _service.adjustQuantity(item.id, -1)
                      ),
                      Text("${item.currentQty}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline), 
                        onPressed: () => _service.adjustQuantity(item.id, 1)
                      ),
                      const SizedBox(width: 10),
                      IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: () => _showEditDialog(model: item)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}