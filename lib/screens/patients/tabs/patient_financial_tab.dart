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
  
  // Lista de perfis de máquina para o Dropdown
  List<Map<String, dynamic>> _machineProfiles = [];
  
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

        // Carrega perfis para o dropdown
        List<Map<String, dynamic>> profiles = [];
        try {
          final profilesSnap = await FirebaseFirestore.instance
              .collection('clinics').doc(clinicId)
              .collection('settings').doc('fees')
              .collection('profiles')
              .get();
          
          profiles = profilesSnap.docs.map((d) => {
            'id': d.id,
            ...d.data()
          }).toList();
        } catch (e) { print("Erro perfis: $e"); }

        if (mounted) {
          setState(() {
            _dentists = dentistsList;
            _suppliers = suppliersList;
            _machineProfiles = profiles;
            _isLoadingData = false;
          });
        }
      } catch (e) { 
        print("Erro loadData: $e");
        if(mounted) setState(() => _isLoadingData = false);
      }
    }
  }

  // --- FUNÇÃO DE WHATSAPP ---
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
      
      String msg = "Olá, lembrete da parcela de R\$ ${item.amount.toStringAsFixed(2)} vencendo em ${DateFormat('dd/MM').format(item.dueDate ?? DateTime.now())}.";
      final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(msg)}");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) { print(e); }
  }

  // --- LÓGICA DE ESTORNO ---
  void _confirmReversal(String id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // Verifica Despesas vinculadas
    QuerySnapshot relatedExpenses = await FirebaseFirestore.instance
          .collection('expenses')
          .where('relatedFinancialId', isEqualTo: id)
          .get();

    // Verifica Pedidos de Laboratório vinculados
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
  // --- TIMELINE ITEM ---
  Widget _buildTimelineItem(dynamic item, bool isIncome) {
    String itemId = item.id;
    DateTime date = isIncome ? item.date : (item as ExpenseModel).dueDate; 
    String title = isIncome ? (item as FinancialModel).title : "${(item as ExpenseModel).category} (${(item as ExpenseModel).description})";
    double amount = item.amount;
    
    // Status seguro
    bool isPaid = false;
    String status = "";
    
    if (isIncome) {
      final fin = item as FinancialModel;
      
      // --- MÁGICA DA ARQUITETURA (VISÃO PACIENTE VS TESOURARIA) ---
      // Se for Cartão de Crédito/Débito, a dívida do paciente está quitada.
      // Mantemos o status real intacto (pending) para a Antecipação funcionar nos bastidores.
      bool isCard = (fin.paymentMethod ?? '').toLowerCase().contains('cart');
      bool isSystemPaid = fin.status == 'paid' || fin.status == 'pago' || fin.status == 'anticipated' || fin.status == 'antecipado';
      
      isPaid = isSystemPaid || (fin.paidAmount >= fin.amount && fin.amount > 0) || (isCard && (fin.status == 'pending' || fin.status == 'pendente'));
      
      status = isPaid ? "Pago" : "Pendente";
    } else {
      final exp = item as ExpenseModel;
      status = exp.status;
      isPaid = status.toLowerCase() == 'paid' || status.toLowerCase() == 'pago';
    }

    bool isPending = !isPaid;

    Color bgColor = isIncome 
        ? (isPending ? Colors.white : Colors.green[50]!) 
        : Colors.orange[50]!;
    Color borderColor = isIncome 
        ? (isPending ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.2)) 
        : Colors.orange.withOpacity(0.2);

    // Variáveis visuais
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
                      Text("Taxa (${feePercentage.toStringAsFixed(2)}%): - R\$ ${taxVal.toStringAsFixed(2)}", style: TextStyle(fontSize: 10, color: Colors.red[800])),
                      const SizedBox(height: 2),
                      Text("Líquido: R\$ ${valorLiquido.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800])),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isIncome && isPending)
                     Padding(
                       padding: const EdgeInsets.only(right: 8.0),
                       child: IconButton(
                         icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                         onPressed: () => _sendPaymentReminder(item as FinancialModel),
                         tooltip: "Enviar Lembrete",
                         padding: EdgeInsets.zero,
                         constraints: const BoxConstraints(),
                       ),
                     ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isPaid ? Colors.green : (isPending ? Colors.red : Colors.orange), borderRadius: BorderRadius.circular(4)),
                    child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- MODAL DE RECEBIMENTO (BLINDADO) ---
  void _showReceiveDialog(BuildContext context, FinancialModel item, {Map<String, dynamic>? preFilledData}) async {
    final amountCtrl = TextEditingController(text: preFilledData?['amount']?.toStringAsFixed(2) ?? (item.amount - item.paidAmount).toStringAsFixed(2));
    final installmentsCtrl = TextEditingController(text: preFilledData?['installments']?.toString() ?? "1");
    final commPercentCtrl = TextEditingController(text: "0");
    final commValueCtrl = TextEditingController(text: "0.00");
    final costCtrl = TextEditingController(text: "0.00");

    String selectedMethod = preFilledData?['method'] ?? "Dinheiro";
    List<String> methods = ["Dinheiro", "Pix", "Débito", "Cartão de Crédito"];
    
    String? selectedProfileId = preFilledData?['profileId'];
    Map<String, dynamic>? feeProfile;
    
    if (selectedProfileId == null && _machineProfiles.isNotEmpty) {
       selectedProfileId = _machineProfiles.first['id'];
       feeProfile = _machineProfiles.first;
    } else if (selectedProfileId != null) {
       feeProfile = _machineProfiles.firstWhere((p) => p['id'] == selectedProfileId, orElse: () => {});
    }

    double currentFeeRate = 0.0;
    double totalFeeValue = 0.0;
    double totalNetValue = 0.0;

    String? selectedProfessionalId;
    String? selectedSupplierId; 
    
    bool generateExpense = true; 
    bool hasCost = false;
    bool deductCostFromBase = false; 

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

    // --- 🛡️ WAR ROOM: O MOTOR DE PARSE INVENCÍVEL ---
    // Impede crashs mesmo que a clínica digite "R$ 1.500,50" ou se o banco estiver corrompido
    double safeParse(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        String s = value.trim();
        if (s.isEmpty) return 0.0;
        // Se for formato US (1500.50)
        if (s.contains('.') && !s.contains(',')) {
           return double.tryParse(s.replaceAll(RegExp(r'[^0-9\-\.]'), '')) ?? 0.0;
        }
        // Se for formato BR (1.500,50)
        String cleanString = s.replaceAll('.', '').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9\-\.]'), '');
        return double.tryParse(cleanString) ?? 0.0;
      }
      return 0.0;
    }

    // --- 🛡️ WAR ROOM: BUSCA TOLERANTE A FALHAS NO FIREBASE ---
    try {
      final proceduresRef = FirebaseFirestore.instance.collection('procedures');
      Map<String, dynamic>? procedureData;

      final allDocs = await proceduresRef.get();
      final String targetName = item.title.trim().toLowerCase();

      for (var doc in allDocs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // A interrogação dupla aqui impede o crash se 'name' não existir
        final String procName = (data['name']?.toString() ?? '').trim().toLowerCase();
        
        if (procName == targetName) {
          // Proteção Multi-tenant
          if (data.containsKey('clinicId') && data['clinicId'] != null && data['clinicId'] != clinicId) {
             continue; 
          }
          procedureData = data;
          break; 
        }
      }

      if (procedureData != null) {
        // Cobre nomenclaturas digitadas incorretamente
        String cType = (procedureData['commissionType']?.toString() ?? 'percent').toLowerCase();
        commissionType = (cType.contains('percent') || cType.contains('%') || cType.contains('porcentagem')) ? 'percent' : 'fixed';
        
        hasCost = procedureData['hasCost'] == true || procedureData['hasCost'] == 'true'; 
        
        if (hasCost) {
          double defCost = safeParse(procedureData['cost'] ?? procedureData['operationalCost']);
          costCtrl.text = defCost.toStringAsFixed(2);
        }
        
        // Cobre variações comuns de colunas de banco
        double commVal = safeParse(procedureData['commissionValue'] ?? procedureData['commission'] ?? procedureData['repasse']);
        
        if (commissionType == 'percent') {
          defaultPercent = commVal;
        } else {
          defaultFixed = commVal;
        }
      }
    } catch (e) { 
      print("War Room Debug - Erro Crítico silencioso evitado: $e"); 
    }

    if (item.dentistId != null && _dentists.any((d) => d.id == item.dentistId)) selectedProfessionalId = item.dentistId;

    // Usa o safeParse para garantir que 1.000,00 não vire 0.0
    double initialPay = safeParse(amountCtrl.text);
    
    if (commissionType == 'percent') {
      commPercentCtrl.text = defaultPercent.toStringAsFixed(2); 
      commValueCtrl.text = (initialPay * (defaultPercent / 100)).toStringAsFixed(2);
    } else {
      commPercentCtrl.text = "0.00"; 
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
            
            // --- CÁLCULOS AGORA USAM SAFEPARSE GLOBALMENTE ---
            void calculateFees() {
              double total = safeParse(amountCtrl.text);
              int parc = int.tryParse(installmentsCtrl.text) ?? 1;
              if (parc < 1) parc = 1;
              
              currentFeeRate = 0.0;

              if (feeProfile != null && (selectedMethod == "Débito" || selectedMethod == "Cartão de Crédito")) {
                if (selectedMethod == "Débito") {
                  currentFeeRate = safeParse(feeProfile?['debit']);
                } else {
                  if (parc == 1) {
                    currentFeeRate = safeParse(feeProfile?['credit_1x']);
                  } else {
                    final rules = List<Map<String, dynamic>>.from(feeProfile?['installment_rules'] ?? []);
                    final matchingRule = rules.firstWhere(
                      (r) => parc >= (r['from'] ?? 0) && parc <= (r['to'] ?? 0),
                      orElse: () => {},
                    );
                    if (matchingRule.isNotEmpty) {
                      currentFeeRate = safeParse(matchingRule['rate']);
                    }
                  }
                  if (feeProfile?['anticipation_enabled'] == true) {
                    double antRate = safeParse(feeProfile?['anticipation_rate']);
                    currentFeeRate += (antRate * parc); 
                  }
                }
              }
              
              totalFeeValue = double.parse((total * (currentFeeRate / 100)).toStringAsFixed(2));
              totalNetValue = total - totalFeeValue;
            }
            
            calculateFees(); 

            void recalculateFromPercent() {
              double pay = safeParse(amountCtrl.text);
              double pct = safeParse(commPercentCtrl.text);
              double cost = safeParse(costCtrl.text);
              double base = pay;
              if (deductCostFromBase) { base = pay - cost; if (base < 0) base = 0; }
              commValueCtrl.text = (base * (pct / 100)).toStringAsFixed(2);
              calculateFees();
            }

            void recalculateFromValue() {
              double pay = safeParse(amountCtrl.text);
              double valRepasse = safeParse(commValueCtrl.text);
              double base = pay;
              if (deductCostFromBase) {
                  double cost = safeParse(costCtrl.text);
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
                    const Text("Receber Pagamento", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    
                    if (selectedMethod == "Débito" || selectedMethod == "Cartão de Crédito") ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedProfileId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: "Selecione a Máquina", border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.settings_remote)),
                        items: _machineProfiles.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['machine_name'] ?? 'Sem Nome'))).toList(),
                        onChanged: (val) {
                          setStateModal(() {
                            selectedProfileId = val;
                            feeProfile = _machineProfiles.firstWhere((p) => p['id'] == val);
                            calculateFees();
                          });
                        },
                      ),
                    ],

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
                            if (feeProfile != null)
                               Padding(
                                 padding: const EdgeInsets.only(bottom: 8.0),
                                 child: Row(children: [const Icon(Icons.settings_remote, size: 14, color: Colors.blue), const SizedBox(width: 5), Text("Máquina: ${feeProfile!['machine_name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12))]),
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
                    
                    // --- ÁREA DE REPASSE E DESPESAS ---
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

                    const SizedBox(height: 25),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final val = safeParse(amountCtrl.text);
                          final inst = int.tryParse(installmentsCtrl.text) ?? 1;
                          final finalCommission = safeParse(commValueCtrl.text);
                          final finalCost = safeParse(costCtrl.text);
                          
                          if (val <= 0) return;

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

                          try {
                            WriteBatch batch = FirebaseFirestore.instance.batch();

                            // 🎯 WAR ROOM: O repasse do Cartão de Crédito é mantido
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
                              status: selectedMethod.contains('Cartão') ? 'paid' : 'pending',
                              isPaid: selectedMethod.contains('Cartão') ? true : false,
                              paymentDate: selectedMethod.contains('Cartão') ? DateTime.now() : null,
                            );

                            if (selectedMethod == "Cartão de Crédito" && inst > 1) {
                               if (item.id.isNotEmpty) {
                                  batch.delete(FirebaseFirestore.instance.collection('financial').doc(item.id));
                               }
                            } else {
                               if (selectedProfileId != null) {
                                  String? machineName = feeProfile?['machine_name'];
                                  if (item.id.isNotEmpty) {
                                     batch.update(FirebaseFirestore.instance.collection('financial').doc(item.id), {
                                       'machineProfileId': selectedProfileId,
                                       'machineProfileName': machineName
                                     });
                                  }
                               }
                            }

                            if (selectedProfessionalId != null && finalCommission > 0 && generateExpense) {
                               DocumentReference expRef = FirebaseFirestore.instance.collection('expenses').doc();
                               batch.set(expRef, {
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

                            if (hasCost && finalCost > 0) {
                               String? supplierName;
                               if (selectedSupplierId != null) {
                                 try { supplierName = _suppliers.firstWhere((s) => s.id == selectedSupplierId).name; } catch (e) { /**/ }
                               }
                               DocumentReference costRef = FirebaseFirestore.instance.collection('expenses').doc();
                               batch.set(costRef, {
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

                            if (generateLabOrder && selectedLabId != null) {
                               String? labName;
                               try { labName = _suppliers.firstWhere((s) => s.id == selectedLabId).name; } catch (e) {/**/}
                               
                               double labCost = safeParse(labCostCtrl.text);

                               DocumentReference labRef = FirebaseFirestore.instance.collection('lab_orders').doc();
                               batch.set(labRef, {
                                 'clinicId': clinicId,
                                 'patientId': widget.patientId,
                                 'patientName': item.patientName,
                                 'dentistId': selectedProfessionalId,
                                 'dentistName': dentistName,
                                 'supplierId': selectedLabId,
                                 'supplierName': labName,
                                 'procedureName': item.title, 
                                 'interactions': [],          
                                 'description': item.title, 
                                 'cost': labCost,
                                 'price': labCost, 
                                 'deliveryDate': labDeliveryDate,
                                 'createdAt': DateTime.now(), 
                                 'status': 'Solicitado', 
                                 'relatedFinancialId': item.id,
                               });
                            }

                            await batch.commit();

                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text("Recebimento registrado com sucesso!"),
                                backgroundColor: Colors.green,
                              )
                            );

                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text("Erro ao registrar recebimento: $e"),
                                backgroundColor: Colors.red,
                              )
                            );
                          }
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

  void _checkForGroupPayment(BuildContext context, String budgetId, String method, int installments, String? profileId, Map<String, dynamic>? profile) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('financial')
        .where('relatedBudgetId', isEqualTo: budgetId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    final otherItems = snapshot.docs.toList(); 

    if (otherItems.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Pagamento em Grupo"),
          content: Text("Existem mais ${otherItems.length} itens deste orçamento pendentes. Deseja pagá-los também com $method em ${installments}x?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Não, pagar depois")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final nextItemModel = FinancialModel.fromMap(otherItems.first.id, otherItems.first.data());
                _showReceiveDialog(context, nextItemModel, preFilledData: {
                  'method': method,
                  'installments': installments,
                  'profileId': profileId,
                  'amount': nextItemModel.amount
                });
              },
              child: const Text("Sim, pagar próximo"),
            )
          ],
        )
      );
    }
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
                    
                    // --- TOTALIZADORES ---
                    // Como agora estamos DELETANDO o título original na função _showReceiveDialog quando parcelamos,
                    // podemos somar tudo normalmente sem filtros complexos. A matemática se resolve sozinha.
                    totalContracted += item.amount;

                    bool isPaid = item.status == 'paid' || item.status == 'anticipated' || (item.paidAmount >= item.amount && item.amount > 0);
                    
                    if (!isPaid) totalPending += (item.amount - item.paidAmount);
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