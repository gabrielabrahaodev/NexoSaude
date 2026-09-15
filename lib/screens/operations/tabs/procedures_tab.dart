import 'package:flutter/material.dart';
import '../../../models/procedure_model.dart';
import '../../../services/procedure_service.dart';
import '../../../services/session_manager.dart';
import '../../../ui/app_theme.dart';

class ProceduresTab extends StatefulWidget {
  const ProceduresTab({super.key});
  @override
  State<ProceduresTab> createState() => _ProceduresTabState();
}

class _ProceduresTabState extends State<ProceduresTab> {
  final ProcedureService _service = ProcedureService();

  void _showEditDialog({ProcedureModel? model}) {
    final nameCtrl = TextEditingController(text: model?.name);
    final priceCtrl = TextEditingController(text: model?.price.toStringAsFixed(2));
    final categoryCtrl = TextEditingController(text: model?.category ?? 'Geral');
    
    // Controlador da Comissão
    final commissionValueCtrl = TextEditingController(
      text: model?.commissionValue.toStringAsFixed(model.commissionType == 'percent' ? 1 : 2) ?? '0.0'
    );
    
    // Variáveis de estado locais
    bool hasCost = model?.hasCost ?? false;
    bool generatesMonthlyFee = model?.generatesMonthlyFee ?? false;
    String commissionType = model?.commissionType ?? 'percent'; // 'percent' ou 'fixed'

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(model == null ? "Novo Procedimento" : "Editar Procedimento"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome")),
                    const SizedBox(height: 10),
                    TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: "Categoria (Ex: Cirurgia)")),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceCtrl, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Preço Sugerido (R\$)", prefixText: "R\$ ")
                    ),
                    const SizedBox(height: 20),
                    
                    // --- SEÇÃO DE COMISSÃO / REPASSE ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Repasse Profissional (Comissão)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Opção Porcentagem
                              Expanded(
                                child: InkWell(
                                  onTap: () => setStateModal(() => commissionType = 'percent'),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'percent',
                                        groupValue: commissionType,
                                        activeColor: AppColors.primary,
                                        onChanged: (val) => setStateModal(() => commissionType = val!),
                                      ),
                                      const Text("Porcentagem (%)", style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                              // Opção Valor Fixo
                              Expanded(
                                child: InkWell(
                                  onTap: () => setStateModal(() => commissionType = 'fixed'),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'fixed',
                                        groupValue: commissionType,
                                        activeColor: AppColors.primary,
                                        onChanged: (val) => setStateModal(() => commissionType = val!),
                                      ),
                                      const Text("Valor Fixo (R\$)", style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextField(
                            controller: commissionValueCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: commissionType == 'percent' ? "Porcentagem do Repasse" : "Valor do Repasse",
                              suffixText: commissionType == 'percent' ? "%" : null,
                              prefixText: commissionType == 'fixed' ? "R\$ " : null,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Divider(),
                    
                    // --- FLAGS ---
                    SwitchListTile(
                      title: const Text("Gera Custos/Despesas?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Ex: Laboratório, Protético", style: TextStyle(fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                      value: hasCost,
                      activeColor: Colors.orange,
                      onChanged: (val) => setStateModal(() => hasCost = val),
                    ),
                    
                    SwitchListTile(
                      title: const Text("Gera Mensalidade?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Ex: Manutenção Ortodôntica (12x)", style: TextStyle(fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                      value: generatesMonthlyFee,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setStateModal(() => generatesMonthlyFee = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () async {
                    final clinicId = SessionManager().currentClinicId;
                    if (clinicId == null) return;

                    final newModel = ProcedureModel(
                      id: model?.id ?? '', 
                      clinicId: clinicId,
                      name: nameCtrl.text,
                      category: categoryCtrl.text,
                      price: double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
                      hasCost: hasCost,
                      generatesMonthlyFee: generatesMonthlyFee,
                      // Novos Campos
                      commissionType: commissionType,
                      commissionValue: double.tryParse(commissionValueCtrl.text.replaceAll(',', '.')) ?? 0.0,
                    );
                    
                    await _service.save(newModel);
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Salvar"),
                )
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ProcedureModel>>(
        stream: _service.getAllStream(),
        builder: (context, snapshot) {
          // ... (Tratamentos de erro e loading iguais) ...
          if (snapshot.hasError) return const Center(child: Text("Erro ao carregar"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final list = snapshot.data!;
          if (list.isEmpty) return const Center(child: Text("Nenhum procedimento cadastrado"));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = list[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(item.name.isNotEmpty ? item.name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: AppColors.primary)),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${item.category} • Repasse: ${item.formattedCommission}"), // Mostra o repasse aqui
                    if (item.hasCost || item.generatesMonthlyFee)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (item.hasCost) 
                              Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(4)),
                                child: const Text("Gera Custo", style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
                              ),
                            if (item.generatesMonthlyFee) 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                                child: const Text("Mensalidade", style: TextStyle(fontSize: 10, color: Colors.blue)),
                              ),
                          ],
                        ),
                      )
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("R\$ ${item.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 10),
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