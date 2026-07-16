import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
// Verifique se os caminhos dos imports abaixo estão corretos no seu projeto
import '../../../ui/app_theme.dart';
import '../../../services/financial_service.dart';
import '../../../services/user_service.dart'; 
import '../../../services/session_manager.dart'; 
import '../../../services/supplier_service.dart'; 
import '../../../models/financial_model.dart';
import '../../../models/expense_model.dart';
import '../../../models/user_model.dart';
import '../../../models/supplier_model.dart'; 

class PatientFinancialTab extends StatefulWidget {
  final String patientId;
  const PatientFinancialTab({super.key, required this.patientId});

  @override
  State<PatientFinancialTab> createState() => _PatientFinancialTabState();
}

class _PatientFinancialTabState extends State<PatientFinancialTab> {
  final FinancialService _finService = FinancialService();
  final UserService _userService = UserService();
  final SupplierService _supplierService = SupplierService();

  List<UserModel> _dentists = [];
  List<SupplierModel> _suppliers = []; 
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _loadData(); 
  }

  Future<void> _loadData() async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId != null) {
      setState(() => _isLoadingData = true);
      try {
        var dentistsList = await _userService.getDentistsForClinic(clinicId);
        List<SupplierModel> suppliersList = [];
        try {
           var stream = _supplierService.getAllStream();
           suppliersList = await stream.first; 
        } catch (e) { print("Info: Sem fornecedores ou erro: $e"); }

        if (mounted) {
          setState(() {
            _dentists = dentistsList;
            _suppliers = suppliersList;
            _isLoadingData = false;
          });
        }
      } catch (e) { 
        print("Erro loadData: $e");
        if(mounted) setState(() => _isLoadingData = false);
      }
    }
  }

  // --- NOVA LÓGICA DE ESTORNO ---
  void _confirmReversal(String id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // Verifica Despesas
    QuerySnapshot relatedExpenses = await FirebaseFirestore.instance
          .collection('expenses')
          .where('relatedFinancialId', isEqualTo: id)
          .get();

    // Verifica Pedidos de Laboratório
    QuerySnapshot relatedLabOrders = await FirebaseFirestore.instance
          .collection('lab_orders')
          .where('relatedFinancialId', isEqualTo: id)
          .get();

    if (!mounted) return;
    Navigator.pop(context); // Fecha loading

    bool hasLinkedData = relatedExpenses.docs.isNotEmpty || relatedLabOrders.docs.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Estornar Lançamento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Deseja cancelar o pagamento e tornar esta parcela pendente novamente?"),
            
            if (hasLinkedData) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.5))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.warning_amber, color: Colors.deepOrange, size: 20),
                      SizedBox(width: 8),
                      Text("Itens vinculados encontrados:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
                    ]),
                    const SizedBox(height: 5),
                    if (relatedExpenses.docs.isNotEmpty)
                      Text("• ${relatedExpenses.docs.length} Despesa(s) (Comissão/Custo)", style: const TextStyle(fontSize: 11)),
                    if (relatedLabOrders.docs.isNotEmpty)
                      Text("• ${relatedLabOrders.docs.length} Pedido(s) de Laboratório", style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 5),
                    const Text("Eles serão EXCLUÍDOS se você confirmar.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Exclui despesas
              for (var doc in relatedExpenses.docs) { await doc.reference.delete(); }
              // Exclui pedidos de lab
              for (var doc in relatedLabOrders.docs) { await doc.reference.delete(); }
              
              // Executa o estorno
              await _finService.voidPayment(id);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Estorno realizado com sucesso!")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("CONFIRMAR ESTORNO"),
          )
        ],
      ),
    );
  }

  // --- TIMELINE ITEM ---
  Widget _buildTimelineItem(dynamic item, bool isIncome) {
    String itemId = item.id;
    DateTime date = isIncome ? item.date : (item as ExpenseModel).dueDate; 
    String title = isIncome ? (item as FinancialModel).title : "${(item as ExpenseModel).category} (${(item as ExpenseModel).description})";
    double amount = item.amount;
    
    String status = isIncome 
        ? ((item as FinancialModel).isPaid ? "Pago" : "Pendente") 
        : (item as ExpenseModel).status;
    
    bool isPending = status.toLowerCase() == 'pendente';
    bool isPaid = !isPending;

    Color bgColor = isIncome 
        ? (isPending ? Colors.white : Colors.green[50]!) 
        : Colors.orange[50]!;
    Color borderColor = isIncome 
        ? (isPending ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.2)) 
        : Colors.orange.withOpacity(0.2);

    double taxVal = 0.0;
    double valorLiquido = 0.0;
    double feePercentage = 0.0;

    if (isIncome) {
      final finItem = item as FinancialModel;
      taxVal = finItem.taxVal;
      valorLiquido = finItem.valorLiquido;
      feePercentage = finItem.feePercentage;
    }

    return GestureDetector(
      onTap: () {
        if (isIncome && isPending) {
          _showReceiveDialog(context, item as FinancialModel);
        } else if (isIncome && isPaid) {
          _confirmReversal(itemId);
        }
      },
      child: Card(
        elevation: isPending ? 3 : 0, 
        color: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderColor)),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: isIncome ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(DateFormat('dd/MM').format(date), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: isIncome ? TextAlign.right : TextAlign.left),
              
              if (isIncome)
                Text((item as FinancialModel).description, 
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]), 
                  textAlign: TextAlign.right
                ),

              const SizedBox(height: 4),
              Text("R\$ ${amount.toStringAsFixed(2)}", 
                style: TextStyle(
                  color: isIncome ? (isPending ? Colors.red : Colors.green[700]) : Colors.orange[800], 
                  fontWeight: FontWeight.bold,
                  fontSize: 14
                )
              ),

              if (isIncome && taxVal > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.withOpacity(0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Taxa (${feePercentage.toStringAsFixed(1)}%): - R\$ ${taxVal.toStringAsFixed(2)}", style: TextStyle(fontSize: 10, color: Colors.red[800])),
                      const SizedBox(height: 2),
                      Text("Líquido: R\$ ${valorLiquido.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800])),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: isPaid ? Colors.green : (isPending ? Colors.red : Colors.orange), borderRadius: BorderRadius.circular(4)),
                child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- MODAL DE RECEBIMENTO (ATUALIZADO PARA PERFIS DE CARTÃO) ---
  void _showReceiveDialog(BuildContext context, FinancialModel item) async {
    final amountCtrl = TextEditingController(text: (item.amount - item.paidAmount).toStringAsFixed(2));
    final installmentsCtrl = TextEditingController(text: "1");
    final commPercentCtrl = TextEditingController(text: "0");
    final commValueCtrl = TextEditingController(text: "0.00");
    final costCtrl = TextEditingController(text: "0.00");

    String selectedMethod = "Dinheiro";
    List<String> methods = ["Dinheiro", "Pix", "Débito", "Cartão de Crédito"];
    
    // --- VARIÁVEL PARA O PERFIL DE TAXAS CARREGADO ---
    Map<String, dynamic>? feeProfile;
    String? profileName;
    
    double currentFeeRate = 0.0;
    double totalFeeValue = 0.0;
    double totalNetValue = 0.0;

    String? selectedProfessionalId;
    String? selectedSupplierId; 
    
    bool generateExpense = true; 
    bool hasCost = false;
    bool deductCostFromBase = false; 

    // VARIÁVEIS DE LABORATÓRIO
    bool generateLabOrder = false;
    String? selectedLabId;
    final labCostCtrl = TextEditingController(text: "0.00");
    DateTime labDeliveryDate = DateTime.now().add(const Duration(days: 7));

    DateTime costDueDate = DateTime.now().add(const Duration(days: 30));
    DateTime commissionDueDate = DateTime.now().add(const Duration(days: 30));

    double defaultPercent = 0.0;
    double defaultFixed = 0.0;
    String commissionType = 'percent'; 

    final clinicId = SessionManager().currentClinicId;

    // 1. CARREGA O PERFIL DE TAXAS ATIVO
    if (clinicId != null) {
      try {
        // Primeiro descobre qual é o perfil ativo
        final docSettings = await FirebaseFirestore.instance.collection('clinics').doc(clinicId).collection('settings').doc('fees').get();
        if (docSettings.exists) {
           final activeId = docSettings.data()?['activeProfileId'];
           if (activeId != null) {
             // Busca o documento do perfil específico
             final docProfile = await FirebaseFirestore.instance
                 .collection('clinics').doc(clinicId)
                 .collection('settings').doc('fees')
                 .collection('profiles').doc(activeId)
                 .get();
             
             if (docProfile.exists) {
               feeProfile = docProfile.data();
               profileName = feeProfile?['machine_name'];
             }
           }
        }
      } catch (e) { print("Erro ao carregar perfil de taxas: $e"); }
    }

    try {
      final proceduresRef = FirebaseFirestore.instance.collection('procedures');
      QuerySnapshot query = await proceduresRef.where('name', isEqualTo: item.title.trim()).limit(1).get();
      Map<String, dynamic>? procedureData;
      
      if (query.docs.isNotEmpty) {
        procedureData = query.docs.first.data() as Map<String, dynamic>;
      } else {
        final allDocs = await proceduresRef.get();
        try {
          final foundDoc = allDocs.docs.firstWhere((doc) => (doc['name'] as String).toLowerCase() == item.title.trim().toLowerCase());
          procedureData = foundDoc.data();
        } catch (e) { /* Não encontrou */ }
      }

      if (procedureData != null) {
        commissionType = procedureData['commissionType'] ?? 'percent';
        hasCost = procedureData['hasCost'] ?? false; 
        if (hasCost) {
          double defCost = (procedureData['cost'] ?? procedureData['operationalCost'] ?? 0.0).toDouble();
          costCtrl.text = defCost.toStringAsFixed(2);
        }
        if (commissionType == 'percent') defaultPercent = (procedureData['commissionValue'] ?? 0.0).toDouble();
        else defaultFixed = (procedureData['commissionValue'] ?? 0.0).toDouble();
      }
    } catch (e) { print(e); }

    if (item.dentistId != null && _dentists.any((d) => d.id == item.dentistId)) selectedProfessionalId = item.dentistId;

    double initialPay = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (commissionType == 'percent') {
      commPercentCtrl.text = defaultPercent.toString(); 
      commValueCtrl.text = (initialPay * (defaultPercent / 100)).toStringAsFixed(2);
    } else {
      commValueCtrl.text = defaultFixed.toStringAsFixed(2);
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            
            // --- CÁLCULO DE TAXAS ATUALIZADO (REGRAS DINÂMICAS) ---
            void calculateFees() {
              double total = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
              int parc = int.tryParse(installmentsCtrl.text) ?? 1;
              if (parc < 1) parc = 1;
              
              currentFeeRate = 0.0;

              if (feeProfile != null) {
                if (selectedMethod == "Débito") {
                  currentFeeRate = (feeProfile?['debit'] ?? 0.0).toDouble();
                } 
                else if (selectedMethod == "Cartão de Crédito") {
                  if (parc == 1) {
                    currentFeeRate = (feeProfile?['credit_1x'] ?? 0.0).toDouble();
                  } else {
                    // Busca na lista dinâmica de regras
                    final rules = List<Map<String, dynamic>>.from(feeProfile?['installment_rules'] ?? []);
                    // Encontra a regra onde a parcela se encaixa (ex: entre 2 e 6)
                    final matchingRule = rules.firstWhere(
                      (r) => parc >= (r['from'] ?? 0) && parc <= (r['to'] ?? 0),
                      orElse: () => {},
                    );
                    
                    if (matchingRule.isNotEmpty) {
                      currentFeeRate = (matchingRule['rate'] ?? 0.0).toDouble();
                    } else {
                      // Se não achar regra, zera ou usa um padrão (aqui zera para segurança)
                      currentFeeRate = 0.0;
                    }
                  }

                  // Adiciona Antecipação se habilitada
                  if (feeProfile?['anticipation_enabled'] == true) {
                    double antRate = (feeProfile?['anticipation_rate'] ?? 0.0).toDouble();
                    // Lógica simples: Taxa de Parcela + (Taxa Mensal * Num Parcelas)
                    // Ajuste conforme sua regra de negócio específica
                    currentFeeRate += (antRate * parc);
                  }
                }
              }
              
              totalFeeValue = total * (currentFeeRate / 100);
              totalNetValue = total - totalFeeValue;
            }
            
            calculateFees(); 

            void recalculateFromPercent() {
              double pay = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
              double pct = double.tryParse(commPercentCtrl.text.replaceAll(',', '.')) ?? 0.0;
              double cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
              double base = pay;
              if (deductCostFromBase) { base = pay - cost; if (base < 0) base = 0; }
              commValueCtrl.text = (base * (pct / 100)).toStringAsFixed(2);
              calculateFees();
            }

            void recalculateFromValue() {
              double pay = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
              double valRepasse = double.tryParse(commValueCtrl.text.replaceAll(',', '.')) ?? 0.0;
              double base = pay;
              if (deductCostFromBase) {
                  double cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  base = pay - cost; if (base < 0) base = 0;
              }
              if (base > 0) {
                double newPct = (valRepasse / base) * 100;
                commPercentCtrl.text = newPct.toStringAsFixed(2);
              }
            }

            Future<void> pickGenericDate(Function(DateTime) onDateSelected, DateTime initial) async {
              final picked = await showDatePicker(
                context: context, 
                initialDate: initial,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5))
              );
              if (picked != null) {
                setStateModal(() => onDateSelected(picked));
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Receber Pagamento", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                      decoration: const InputDecoration(labelText: "Valor Pago Agora", prefixText: "R\$ ", border: InputBorder.none),
                      onChanged: (v) => setStateModal(() => recalculateFromPercent()),
                    ),
                    const SizedBox(height: 10),
                    
                    const Text("Forma de Pagamento", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      children: methods.map((m) {
                        final isSelected = selectedMethod == m;
                        return ChoiceChip(
                          label: Text(m),
                          selected: isSelected,
                          onSelected: (val) {
                             if (val) {
                               if ((m == "Débito" || m == "Cartão de Crédito") && feeProfile == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Atenção: Configure as taxas (Perfil Padrão)."), backgroundColor: Colors.orange));
                               }
                               setStateModal(() {
                                 selectedMethod = m;
                                 if(m != "Cartão de Crédito") installmentsCtrl.text = "1";
                                 calculateFees();
                               });
                             }
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        );
                      }).toList(),
                    ),
                    
                    if (selectedMethod == "Cartão de Crédito") ...[
                      const SizedBox(height: 15),
                      TextField(
                        controller: installmentsCtrl, 
                        keyboardType: TextInputType.number, 
                        decoration: const InputDecoration(labelText: "Número de Parcelas", border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) => setStateModal(() => calculateFees()),
                      ),
                    ],

                    if (selectedMethod == "Débito" || selectedMethod == "Cartão de Crédito") 
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Column(
                          children: [
                            if (profileName != null)
                               Padding(
                                 padding: const EdgeInsets.only(bottom: 8.0),
                                 child: Row(children: [const Icon(Icons.settings_remote, size: 14, color: Colors.blue), const SizedBox(width: 5), Text("Máquina: $profileName", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12))]),
                               ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Taxa Maquininha (${currentFeeRate.toStringAsFixed(2)}%):", style: TextStyle(color: Colors.red[800], fontSize: 12)),
                                Text("- R\$ ${totalFeeValue.toStringAsFixed(2)}", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Valor Líquido Total:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text("R\$ ${totalNetValue.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // --- ÁREA DE REPASSE ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Repasse Profissional & Custos", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                              value: selectedProfessionalId,
                              isExpanded: true,
                              hint: const Text("Quem executou?"),
                              items: _dentists.map((user) => DropdownMenuItem(value: user.id, child: Text(user.name))).toList(),
                              onChanged: (val) { setStateModal(() { selectedProfessionalId = val; }); },
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                          ),
                          
                          if (selectedProfessionalId != null) ...[
                            const SizedBox(height: 15),
                            // Se tiver custo
                            if (hasCost) ...[
                               Container(
                                 padding: const EdgeInsets.all(8),
                                 margin: const EdgeInsets.only(bottom: 10),
                                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.brown.shade200)),
                                 child: Column(
                                   children: [
                                     const Align(alignment: Alignment.centerLeft, child: Text("Custo Operacional", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown))),
                                     const SizedBox(height: 5),
                                     DropdownButtonFormField<String>(
                                        value: selectedSupplierId,
                                        isExpanded: true,
                                        hint: const Text("Fornecedor"),
                                        items: _suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                        onChanged: (val) => setStateModal(() => selectedSupplierId = val),
                                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10), border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                                     ),
                                     const SizedBox(height: 8),
                                     Row(
                                       children: [
                                         Expanded(
                                           child: TextField(
                                              controller: costCtrl,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: "Valor Custo", prefixText: "R\$ ", isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                                              onChanged: (v) => recalculateFromPercent(),
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: InkWell(
                                             onTap: () => pickGenericDate((d) => costDueDate = d, costDueDate),
                                             child: InputDecorator(
                                               decoration: const InputDecoration(labelText: "Vencimento", isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                               child: Text(DateFormat('dd/MM').format(costDueDate), style: const TextStyle(fontSize: 13)),
                                             ),
                                           ),
                                         ),
                                       ],
                                     ),
                                     CheckboxListTile(
                                        title: const Text("Deduzir da base?", style: TextStyle(fontSize: 12)),
                                        value: deductCostFromBase,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        activeColor: Colors.brown,
                                        onChanged: (val) => setStateModal(() { deductCostFromBase = val ?? false; recalculateFromPercent(); })
                                     ),
                                   ],
                                 ),
                               ),
                            ],

                            Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: TextField(controller: commPercentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "%", isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true), onChanged: (v) => recalculateFromPercent()),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(controller: commValueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Valor Repasse", isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true, prefixText: "R\$ "), onChanged: (v) => recalculateFromValue()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                                value: generateExpense,
                                title: const Text("Gerar Conta?", style: TextStyle(fontSize: 12)),
                                dense: true,
                                activeColor: Colors.deepOrange,
                                onChanged: (v) => setStateModal(() => generateExpense = v!),
                            ),
                          ]
                        ],
                      ),
                    ),

                    // --- ÁREA DE LABORATÓRIO ---
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50], 
                        borderRadius: BorderRadius.circular(8), 
                        border: Border.all(color: Colors.blue.withOpacity(0.3))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            title: const Text("Gerar Pedido de Laboratório?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            value: generateLabOrder,
                            onChanged: (v) => setStateModal(() => generateLabOrder = v ?? false),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: Colors.blue,
                          ),
                          
                          if (generateLabOrder) ...[
                            const SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                                value: selectedLabId,
                                isExpanded: true,
                                hint: const Text("Selecione o Laboratório"),
                                items: _suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                onChanged: (val) => setStateModal(() => selectedLabId = val),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: labCostCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: "Custo Estimado", prefixText: "R\$ ", isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickGenericDate((d) => labDeliveryDate = d, labDeliveryDate),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(labelText: "Previsão Entrega", isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                      child: Text(DateFormat('dd/MM/yyyy').format(labDeliveryDate), style: const TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ]
                        ],
                      ),
                    ),
                    // ------------------------------------------

                    const SizedBox(height: 25),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final val = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                          final inst = int.tryParse(installmentsCtrl.text) ?? 1;
                          final finalCommission = double.tryParse(commValueCtrl.text.replaceAll(',', '.')) ?? 0.0;
                          final finalCost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
                          
                          if (val <= 0) return;

                          // Validação do Laboratório
                          if (generateLabOrder && selectedLabId == null) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione o laboratório."), backgroundColor: Colors.orange));
                             return;
                          }
                          
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          Navigator.pop(context);

                          String? dentistName;
                          if (selectedProfessionalId != null) {
                            try { dentistName = _dentists.firstWhere((d) => d.id == selectedProfessionalId).name; } catch (e) {/* */}
                          }

                          double? taxValPerInstallment;
                          double? netValPerInstallment;
                          
                          if (totalFeeValue > 0) {
                             taxValPerInstallment = totalFeeValue / inst;
                             netValPerInstallment = totalNetValue / inst;
                          }

                          // 1. Processa Pagamento
                          await _finService.processPayment(
                            originalTransaction: item, 
                            payValue: val, 
                            method: selectedMethod, 
                            installments: inst, 
                            payerName: item.patientName,
                            payerCpf: '', 
                            dentistId: selectedProfessionalId,
                            dentistName: dentistName,
                            feePercentage: currentFeeRate,
                            taxValPerInstallment: taxValPerInstallment,
                            netValPerInstallment: netValPerInstallment,
                          );

                          // 2. Comissão
                          if (selectedProfessionalId != null && finalCommission > 0 && generateExpense) {
                             await FirebaseFirestore.instance.collection('expenses').add({
                               'clinicId': clinicId,
                               'title': "Comissão - ${item.patientName}",
                               'description': "Ref. ${item.title} (${DateFormat('dd/MM').format(DateTime.now())})",
                               'amount': finalCommission,
                               'date': DateTime.now(),
                               'dueDate': commissionDueDate, 
                               'status': 'pendente',
                               'category': 'Comissões',
                               'supplierId': selectedProfessionalId,
                               'supplierName': dentistName,
                               'relatedPatientId': widget.patientId,
                               'isCommission': true,
                               'relatedFinancialId': item.id, 
                             });
                          }

                          // 3. Custo Operacional
                          if (hasCost && finalCost > 0) {
                             String? supplierName;
                             if (selectedSupplierId != null) {
                               try { supplierName = _suppliers.firstWhere((s) => s.id == selectedSupplierId).name; } catch (e) { /**/ }
                             }
                             await FirebaseFirestore.instance.collection('expenses').add({
                               'clinicId': clinicId,
                               'title': "Custo - ${item.title}",
                               'description': "Custo Operacional ref. ${item.title}",
                               'amount': finalCost,
                               'date': DateTime.now(),
                               'dueDate': costDueDate, 
                               'status': 'pendente',
                               'category': 'Custo Operacional',
                               'supplierId': selectedSupplierId, 
                               'supplierName': supplierName,
                               'relatedPatientId': widget.patientId,
                               'isCommission': false,
                               'relatedFinancialId': item.id, 
                             });
                          }

                          // 4. PEDIDO DE LABORATÓRIO (COM CREATED AT CORRETO)
                          if (generateLabOrder && selectedLabId != null) {
                             String? labName;
                             try { labName = _suppliers.firstWhere((s) => s.id == selectedLabId).name; } catch (e) {/**/}
                             
                             double labCost = double.tryParse(labCostCtrl.text.replaceAll(',', '.')) ?? 0.0;

                             await FirebaseFirestore.instance.collection('lab_orders').add({
                               'clinicId': clinicId,
                               'patientId': widget.patientId,
                               'patientName': item.patientName,
                               'dentistId': selectedProfessionalId,
                               'dentistName': dentistName,
                               'supplierId': selectedLabId,
                               'supplierName': labName,
                               'description': item.title, 
                               'cost': labCost,
                               'price': labCost, 
                               'deliveryDate': labDeliveryDate,
                               
                               // NOME DO CAMPO CORRIGIDO: createdAt
                               'createdAt': DateTime.now(), 
                               'status': 'Solicitado',
                               'relatedFinancialId': item.id,
                             });
                          }

                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text("Recebimento registrado com sucesso!"),
                              backgroundColor: Colors.green,
                            )
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text("CONFIRMAR RECEBIMENTO", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("R\$ ${value.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionManager(),
      builder: (context, child) {
        if (SessionManager().currentClinicId == null) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<List<FinancialModel>>(
          stream: _finService.getByPatientId(widget.patientId),
          builder: (context, snapshotFin) {
            
            if (snapshotFin.hasError) {
              return Center(child: Padding(padding: EdgeInsets.all(20), child: SelectableText("Erro Firestore: ${snapshotFin.error}\n(Clique no link acima se houver para criar índice)", style: TextStyle(color: Colors.red))));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('expenses')
                  .where('relatedPatientId', isEqualTo: widget.patientId)
                  .snapshots(),
              builder: (context, snapshotExp) {
                
                if (snapshotFin.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                List<dynamic> timeline = [];
                double totalContracted = 0;
                double totalPending = 0;
                double totalCost = 0;

                if (snapshotFin.hasData) {
                  for (var item in snapshotFin.data!) {
                    timeline.add(item);
                    totalContracted += item.amount;
                    if (!item.isPaid) totalPending += (item.amount - item.paidAmount);
                  }
                }

                if (snapshotExp.hasData) {
                  for (var doc in snapshotExp.data!.docs) {
                    final exp = ExpenseModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                    timeline.add(exp);
                    totalCost += exp.amount;
                  }
                }

                timeline.sort((a, b) {
                  DateTime dateA = (a is FinancialModel) ? a.date : (a as ExpenseModel).dueDate;
                  DateTime dateB = (b is FinancialModel) ? b.date : (b as ExpenseModel).dueDate;
                  return dateB.compareTo(dateA);
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _buildSummaryCard("TOTAL CONTRATADO", totalContracted, Colors.black87),
                          const SizedBox(width: 8),
                          _buildSummaryCard("A RECEBER", totalPending, totalPending > 0 ? Colors.red : Colors.green),
                          const SizedBox(width: 8),
                          _buildSummaryCard("CUSTO OPERACIONAL", totalCost, Colors.orange),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: timeline.isEmpty 
                        ? const Center(child: Text("Nenhuma movimentação financeira.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: timeline.length,
                            itemBuilder: (context, index) {
                              final item = timeline[index];
                              final bool isIncome = item is FinancialModel;

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: isIncome
                                          ? _buildTimelineItem(item, true) 
                                          : const SizedBox(),
                                    ),
                                    SizedBox(
                                      width: 30,
                                      child: Column(
                                        children: [
                                          Container(width: 2, height: 15, color: Colors.grey[300]),
                                          Container(
                                            width: 12, height: 12,
                                            decoration: BoxDecoration(
                                              color: isIncome 
                                                  ? ((item as FinancialModel).status == 'pending' ? Colors.red : Colors.green) 
                                                  : Colors.orange,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2)
                                            ),
                                          ),
                                          Expanded(child: Container(width: 2, color: Colors.grey[300])),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: !isIncome
                                          ? _buildTimelineItem(item, false)
                                          : const SizedBox(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                );
              }
            );
          },
        );
      }
    );
  }
}