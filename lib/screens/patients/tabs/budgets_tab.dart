import 'package:flutter/material.dart';
import '../../../ui/app_theme.dart';
import '../../../services/budget_service.dart';
import '../../../services/procedure_service.dart'; 
import '../../../services/session_manager.dart'; 
import '../../../models/budget_model.dart';
import '../../../models/procedure_model.dart';
// Adicione o import no topo:
import '../wizards/budget_approval_wizard.dart';
import '../../../utils/display.dart';

class BudgetsTab extends StatefulWidget {
  final String patientName;
  final String patientId; 
  const BudgetsTab({super.key, required this.patientName, required this.patientId});

  @override
  State<BudgetsTab> createState() => _BudgetsTabState();
}

class _BudgetsTabState extends State<BudgetsTab> {
  final BudgetService _budgetService = BudgetService();
  final ProcedureService _procedureService = ProcedureService(); 

  // --- MODAL DE CRIAÇÃO DE ORÇAMENTO ---
  void _showCreateBudgetDialog(BuildContext context) {
    List<Map<String, dynamic>> budgetRows = [];
    
    ProcedureModel? tempCategory;
    final TextEditingController tempDescriptionCtrl = TextEditingController();
    final TextEditingController tempPriceCtrl = TextEditingController();

    double getTotal() {
      double sum = 0;
      for (var row in budgetRows) {
        String text = (row['priceController'] as TextEditingController).text;
        sum += double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
      }
      return sum;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return StreamBuilder<List<ProcedureModel>>(
              stream: _procedureService.getAllStream(),
              builder: (context, snapshot) {
                final procedureList = snapshot.data ?? [];

                // --- CORREÇÃO DE SEGURANÇA ---
                // Se já temos um selecionado, verificamos se ele ainda existe na lista nova
                if (tempCategory != null) {
                  try {
                    // Tenta encontrar o objeto atualizado na lista nova usando o ID
                    tempCategory = procedureList.firstWhere((item) => item.id == tempCategory!.id);
                  } catch (e) {
                    // Se não achar (foi deletado ou lista mudou), limpa a seleção para não quebrar
                    tempCategory = null;
                    tempDescriptionCtrl.clear();
                    tempPriceCtrl.clear();
                  }
                }
                // -----------------------------
                
                return AlertDialog(
                  title: const Text("Novo Orçamento"),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.isDark
                                ? AppColors.background
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.2))
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("1. Selecione a Categoria/Procedimento", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              
                              snapshot.connectionState == ConnectionState.waiting 
                                ? const LinearProgressIndicator()
                                : DropdownButtonHideUnderline(
                                    child: DropdownButton<ProcedureModel>(
                                      isExpanded: true,
                                      hint: const Text("Selecione..."),
                                      value: tempCategory,
                                      items: procedureList.map((item) {
                                        return DropdownMenuItem<ProcedureModel>(
                                          value: item,
                                          child: Text("${item.name} (R\$ ${item.price.toStringAsFixed(0)})", overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setStateModal(() {
                                            tempCategory = val;
                                            tempDescriptionCtrl.text = val.name; 
                                            tempPriceCtrl.text = val.price.toStringAsFixed(2);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                              
                              if (tempCategory != null) ...[
                                const SizedBox(height: 10),
                                const Text("2. Personalize (Opcional)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: tempDescriptionCtrl,
                                  decoration: InputDecoration(labelText: "Descrição", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: tempPriceCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(labelText: "Valor (R\$)", hintText: "0,00", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (tempDescriptionCtrl.text.isEmpty || tempPriceCtrl.text.isEmpty) return;
                                        setStateModal(() {
                                          budgetRows.add({
                                            'model': tempCategory, 
                                            'description': tempDescriptionCtrl.text, 
                                            'priceController': TextEditingController(text: tempPriceCtrl.text) 
                                          });
                                          tempCategory = null;
                                          tempDescriptionCtrl.clear();
                                          tempPriceCtrl.clear();
                                        });
                                      },
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text("Incluir"),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                                    )
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(),
                        const Text("Itens do Orçamento:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 5),
                        Expanded(
                          child: budgetRows.isEmpty 
                            ? const Center(child: Text("Nenhum item incluído.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                            : Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: budgetRows.length,
                                  separatorBuilder: (c, i) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final row = budgetRows[index];
                                    final String desc = row['description'];
                                    final TextEditingController ctrl = row['priceController'];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 90,
                                            child: TextField(
                                              controller: ctrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.right,
                                              decoration: InputDecoration(prefixText: "R\$ ", prefixStyle: TextStyle(fontSize: 11, color: Colors.grey), isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), border: OutlineInputBorder()),
                                              onChanged: (val) { setStateModal(() {}); },
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                            onPressed: () { setStateModal(() { budgetRows.removeAt(index); }); },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${formatBRL(getTotal())}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                    ElevatedButton(
                      onPressed: budgetRows.isEmpty ? null : () { 
                        _saveBudgetFromRows(budgetRows); 
                        Navigator.pop(context); 
                      },
                      child: const Text("Salvar Orçamento"),
                    ),
                  ],
                );
              }
            );
          }
        );
      },
    );
  }

  Future<void> _saveBudgetFromRows(List<Map<String, dynamic>> rows) async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;

    List<Map<String, dynamic>> finalItems = [];
    double total = 0;

    for (var row in rows) {
      ProcedureModel originalModel = row['model'];
      String description = row['description'];
      TextEditingController ctrl = row['priceController'];
      double finalPrice = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
      
      finalItems.add({
        'id': originalModel.id, 
        'category': originalModel.category, 
        'name': description,     
        'price': finalPrice      
      });
      total += finalPrice;
    }

    try {
      final newBudget = BudgetModel(
        id: '', 
        clinicId: clinicId,
        patientId: widget.patientId,
        patientName: widget.patientName,
        total: total,
        status: 'Pendente',
        date: DateTime.now(),
        items: finalItems,
      );

      await _budgetService.add(newBudget);
      
      if (mounted) toast(context, "Orçamento criado!");
    } catch (e) {
      if (mounted) toast(context, "Erro ao salvar: $e", error: true);
    }
  }

  // --- LÓGICA DE APROVAÇÃO ---
  // SUBSTITUA O MÉTODO _approveBudget INTEIRO POR ESTE:
  Future<void> _approveBudget(BuildContext context, BudgetModel budget) async {
    // Abre o Wizard (Diálogo)
    // O Wizard retorna 'true' se finalizou com sucesso
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Obriga a usar os botões
      builder: (context) => BudgetApprovalWizard(budget: budget),
    );

    // Se aprovou, recarrega a tela (o StreamBuilder fará isso automaticamente, mas podemos dar um feedback)
    if (result == true) {
      // Opcional: Navegar para a aba de Tratamentos ou apenas mostrar mensagem
      // setState(() {}); 
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.patientId.isEmpty) {
      return const Center(child: Text("Erro: ID do paciente não fornecido."));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateBudgetDialog(context),
              icon: const Icon(Icons.add),
              label: const Text("NOVO ORÇAMENTO"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BudgetModel>>(
            stream: _budgetService.getByPatient(widget.patientId),
            builder: (context, snapshot) {
              // 1. TRATAMENTO DE ERRO (AQUI ESTÁ A CORREÇÃO PRINCIPAL)
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      const Text("Erro ao carregar orçamentos.", style: TextStyle(color: Colors.red)),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final budgets = snapshot.data ?? [];
              
              if (budgets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.request_quote_outlined, size: 50, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      const Text("Nenhum orçamento encontrado.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: budgets.length,
                itemBuilder: (context, index) {
                  final budget = budgets[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: Icon(budget.status == 'Aprovado' ? Icons.check_circle : Icons.request_quote, color: budget.status == 'Aprovado' ? Colors.green : Colors.orange),
                      title: Text("Orçamento - ${formatDateFull(budget.date)}"),
                      subtitle: Text("Total: ${formatBRL(budget.total)} • ${budget.status}"),
                      children: [
                        const Divider(),
                        ...budget.items.map((i) => ListTile(dense: true, title: Text(i['name'] ?? 'Procedimento'), trailing: Text("R\$ ${i['price'] ?? 0}"))),
                        if (budget.status == 'Pendente')
                          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _approveBudget(context, budget), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("APROVAR ORÇAMENTO"))))
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
