import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
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
      
      var dentistsList = await _userService.getDentistsForClinic(clinicId);
      List<SupplierModel> suppliersList = [];
      try {
        suppliersList = await _supplierService.getAllStream().first; 
      } catch (e) {
        print("Erro ao carregar fornecedores: $e");
      }

      if (mounted) setState(() {
        _dentists = dentistsList;
        _suppliers = suppliersList;
        _isLoadingData = false;
      });
    }
  }

  Future<void> _sendPaymentReminder(FinancialModel item) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).get();
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      String? phone = data['phone'] ?? data['celular'] ?? data['whatsapp'];
      
      if (phone == null || phone.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Telefone não cadastrado.")));
        return;
      }

      phone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!phone.startsWith('55')) phone = '55$phone';

      String msg = "Olá, lembrete da parcela de R\$ ${item.amount.toStringAsFixed(2)} vencendo em ${DateFormat('dd/MM').format(item.dueDate)}.";
      final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(msg)}");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print(e);
    }
  }

  void _confirmReversal(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Estornar Lançamento"),
        content: const Text("Deseja cancelar o pagamento e tornar esta parcela pendente novamente?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              await _finService.voidPayment(id);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Estorno realizado!")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("CONFIRMAR"),
          )
        ],
      ),
    );
  }

  // --- MODAL DE RECEBIMENTO (VERSÃO FINAL: CÁLCULO PRÉVIO) ---
  void _showReceiveDialog(BuildContext context, FinancialModel item) async {
    final amountCtrl = TextEditingController(text: (item.amount - item.paidAmount).toStringAsFixed(2));
    final installmentsCtrl = TextEditingController(text: "1");
    final commPercentCtrl = TextEditingController(text: "0");
    final commValueCtrl = TextEditingController(text: "0.00");
    final costCtrl = TextEditingController(text: "0.00");

    String selectedMethod = "Dinheiro";
    List<String> methods = ["Dinheiro", "Pix", "Débito", "Cartão de Crédito"];
    
    // Variáveis de Taxa
    Map<String, dynamic>? feeConfig;
    double currentFeeRate = 0.0;
    
    // Totais para exibição e cálculo
    double totalFeeValue = 0.0; // Valor total da taxa (Ex: R$ 3,50)
    double totalNetValue = 0.0; // Valor total líquido (Ex: R$ 96,50)

    String? selectedProfessionalId;
    String? selectedSupplierId; 
    
    bool generateExpense = true; 
    bool hasCost = false;
    bool deductCostFromBase = false; 

    DateTime costDueDate = DateTime.now().add(const Duration(days: 30));
    DateTime commissionDueDate = DateTime.now().add(const Duration(days: 30));

    double defaultPercent = 0.0;
    double defaultFixed = 0.0;
    String commissionType = 'percent'; 

    final clinicId = SessionManager().currentClinicId;

    // 1. CARREGAR TAXAS
    if (clinicId != null) {
      try {
        final docFees = await FirebaseFirestore.instance.collection('clinics').doc(clinicId).collection('settings').doc('fees').get();
        if (docFees.exists) feeConfig = docFees.data();
      } catch (e) { print("Erro taxas: $e"); }
    }

    // 2. BUSCAR REGRA COMISSÃO
    try {
       // (Sua lógica existente de busca de comissão...)
       final query = await FirebaseFirestore.instance.collection('procedures').where('name', isEqualTo: item.title.trim()).limit(1).get();
       if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          commissionType = data['commissionType'] ?? 'percent';
          hasCost = data['hasCost'] ?? false;
          if(hasCost) costCtrl.text = (data['cost'] ?? 0.0).toString();
          
          if(commissionType == 'percent') defaultPercent = (data['commissionValue'] ?? 0.0).toDouble();
          else defaultFixed = (data['commissionValue'] ?? 0.0).toDouble();
       }
    } catch (e) { print("Erro regra: $e"); }

    if (item.dentistId != null && _dentists.any((d) => d.id == item.dentistId)) {
      selectedProfessionalId = item.dentistId;
    }

    // Inicializa valores
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
            
            // --- CÁLCULO DE TAXAS ---
            void calculateFees() {
              double total = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
              int parc = int.tryParse(installmentsCtrl.text) ?? 1;
              if (parc < 1) parc = 1;
              
              currentFeeRate = 0.0;

              if (feeConfig != null) {
                if (selectedMethod == "Débito") {
                  currentFeeRate = (feeConfig?['debit'] ?? 0.0).toDouble();
                } else if (selectedMethod == "Cartão de Crédito") {
                  if (parc == 1) currentFeeRate = (feeConfig?['credit_1x'] ?? 0.0).toDouble();
                  else if (parc >= 2 && parc <= 3) currentFeeRate = (feeConfig?['credit_2_3x'] ?? 0.0).toDouble();
                  else if (parc >= 4 && parc <= 6) currentFeeRate = (feeConfig?['credit_4_6x'] ?? 0.0).toDouble();
                  else if (parc >= 7 && parc <= 10) currentFeeRate = (feeConfig?['credit_7_10x'] ?? 0.0).toDouble();
                  else if (parc >= 12) currentFeeRate = (feeConfig?['credit_12plus'] ?? 0.0).toDouble();
                }
              }

              totalFeeValue = total * (currentFeeRate / 100);
              totalNetValue = total - totalFeeValue;
            }

            calculateFees(); // Chama ao abrir

            // (Funções auxiliares recalculateFromPercent/Value e pickDate iguais às anteriores...)
            void recalculateFromPercent() { 
               calculateFees(); // Recalcula taxas se mudar o valor
               // ... (lógica de comissão)
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ... (Seus campos de Valor, Método, Parcelas...) ...
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Valor Pago", prefixText: "R\$ "),
                      onChanged: (v) => setStateModal(() => recalculateFromPercent()),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: methods.map((m) => ChoiceChip(
                        label: Text(m),
                        selected: selectedMethod == m,
                        onSelected: (val) {
                          if (val) setStateModal(() { selectedMethod = m; if(m!="Cartão de Crédito") installmentsCtrl.text="1"; calculateFees(); });
                        },
                      )).toList(),
                    ),
                    
                    if (selectedMethod == "Cartão de Crédito")
                      TextField(controller: installmentsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Parcelas"), onChanged: (v) => setStateModal(() => calculateFees())),

                    // --- RESUMO DAS TAXAS ---
                    if (selectedMethod == "Débito" || selectedMethod == "Cartão de Crédito")
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(10),
                        color: Colors.grey[100],
                        child: Column(
                          children: [
                            Text("Taxa (${currentFeeRate}%): - R\$ ${totalFeeValue.toStringAsFixed(2)}", style: TextStyle(color: Colors.red)),
                            Text("Líquido Total: R\$ ${totalNetValue.toStringAsFixed(2)}", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),

                    // ... (Restante do formulário de comissão/custo...) ...

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                         double val = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                         int inst = int.tryParse(installmentsCtrl.text) ?? 1;
                         if (val <= 0) return;

                         Navigator.pop(context);

                         // PREPARAÇÃO DOS DADOS CALCULADOS
                         double? taxValPerInstallment;
                         double? netValPerInstallment;

                         if (totalFeeValue > 0) {
                            // Divide a taxa total pelo número de parcelas para salvar unitário
                            taxValPerInstallment = totalFeeValue / inst;
                            // Divide o líquido total pelo número de parcelas
                            netValPerInstallment = totalNetValue / inst;
                         }

                         // CHAMA O SERVICE JÁ PASSANDO OS DADOS
                         await _finService.processPayment(
                            originalTransaction: item, 
                            payValue: val, 
                            method: selectedMethod, 
                            installments: inst, 
                            payerName: item.patientName,
                            payerCpf: '', 
                            dentistId: selectedProfessionalId,
                            dentistName: null, 
                            // PARÂMETROS NOVOS SENDO ENVIADOS
                            feePercentage: currentFeeRate,
                            taxValPerInstallment: taxValPerInstallment,
                            netValPerInstallment: netValPerInstallment,
                         );
                         
                         // (Geração de Comissão e Custo no Firestore conforme código anterior...)
                      },
                      child: const Text("CONFIRMAR RECEBIMENTO"),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  // --- WIDGETS AUXILIARES (Timeline) ---
  
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

  Widget _buildTimelineItem(dynamic item, bool isIncome) {
    String itemId = item.id;
    DateTime date = isIncome ? item.date : (item as ExpenseModel).dueDate; 
    String title = isIncome ? (item as FinancialModel).title : "${(item as ExpenseModel).category} (${(item as ExpenseModel).description})";
    double amount = item.amount;
    String status = isIncome ? ((item as FinancialModel).isPaid ? "Pago" : "Pendente") : (item as ExpenseModel).status;
    
    bool isPending = status.toLowerCase() == 'pendente';
    bool isPaid = !isPending;
    Color bgColor;
    Color borderColor;
    
    String? installmentInfo;

    if (isIncome) {
      final finItem = item as FinancialModel;
      
      if (finItem.description.contains(RegExp(r'\d+/\d+'))) {
         installmentInfo = finItem.description;
         if (installmentInfo.startsWith(title)) {
           installmentInfo = installmentInfo.substring(title.length).trim();
         }
      }

      if (isPending) {
        bgColor = Colors.white;
        borderColor = Colors.red.withOpacity(0.5);
      } else {
        bgColor = Colors.green[50]!;
        borderColor = Colors.green.withOpacity(0.2);
      }
    } else {
      bgColor = Colors.orange[50]!;
      borderColor = Colors.orange.withOpacity(0.2);
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
              
              if (installmentInfo != null && installmentInfo.isNotEmpty)
                Text(
                  installmentInfo, 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  textAlign: isIncome ? TextAlign.right : TextAlign.left
                ),

              Text("R\$ ${amount.toStringAsFixed(2)}", style: TextStyle(color: isIncome ? (isPending ? Colors.red : Colors.green[700]) : Colors.orange[800], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: isPaid ? Colors.green : (isPending ? Colors.red : Colors.orange), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9)),
                    if (isPending && isIncome) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.touch_app, size: 10, color: Colors.white)),
                    if (isPaid && isIncome) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.replay, size: 10, color: Colors.white70))
                  ],
                ),
              )
            ],
          ),
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