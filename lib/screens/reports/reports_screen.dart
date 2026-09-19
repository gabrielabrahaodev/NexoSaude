import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/session_manager.dart';
import '../../models/financial_model.dart';
import '../financial/financial_report_screen.dart'; 
import '../financial/expenses_screen.dart'; 

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _currentMonth = DateTime.now();
  String? _clinicId;

  late Stream<double> _revenueStream;
  late Stream<double> _expensesStream;
  late Stream<double> _availableAnticipationStream; 

  Timer? _debounceTimer;
  bool _isChangingMonth = false;

  @override
  void initState() {
    super.initState();
    _clinicId = SessionManager().currentClinicId;
    if (_clinicId != null) {
      _initStreams();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _initStreams() {
    _revenueStream = _getRevenueStream(_clinicId!);
    _expensesStream = _getExpensesStream(_clinicId!);
    _availableAnticipationStream = _getAvailableAnticipationStream(_clinicId!); 
  }

  void _changeMonth(int i) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + i, 1);
      _isChangingMonth = true; 
    });

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_clinicId != null && mounted) {
        setState(() {
          _initStreams(); 
          _isChangingMonth = false; 
        });
      }
    });
  }

  DateTime get _startOfMonth => DateTime(_currentMonth.year, _currentMonth.month, 1);

  // --- STREAMS ---

  Stream<double> _getRevenueStream(String clinicId) {
    final start = _startOfMonth;
    return FirebaseFirestore.instance.collection('financial')
        .where('clinicId', isEqualTo: clinicId)
        .snapshots()
        .map((snap) {
             double total = 0.0;
             for (var doc in snap.docs) {
               final data = doc.data();
               if (data['type'] != 'income') continue;

                final status = (data['status'] ?? '').toString().toLowerCase().trim();
                final method = (data['paymentMethod'] ?? '').toString().toLowerCase();

                // Definição única de "pago" (+ flag crua legada).
                final isPaidDoc = FinancialModel.isPaidOf(
                        status: data['status']?.toString() ?? '',
                        paidAmount: data['paidAmount'],
                        amount: data['amount'],
                      ) ||
                    data['isPaid'] == true;
               
               final isCreditCard = method.contains('cart') || method.contains('crédit') || method.contains('credit'); 
               final isNotCanceled = !status.contains('cancel');
               final isAnticipated = status.contains('anticipat') || status.contains('antecipad');

               Timestamp? ts;
               // O NOVO FLUXO DE DATAS (REGIME DE CAIXA)
               if (isCreditCard) {
                   if (isAnticipated) {
                       ts = data['paidDate'] as Timestamp? ?? data['paymentDate'] as Timestamp? ?? data['date'] as Timestamp?;
                   } else {
                       ts = data['dueDate'] as Timestamp? ?? data['date'] as Timestamp?;
                   }
                } else {
                    if (isPaidDoc) {
                       ts = data['paidDate'] as Timestamp? ?? data['paymentDate'] as Timestamp? ?? data['date'] as Timestamp?;
                   } else {
                       ts = data['dueDate'] as Timestamp? ?? data['date'] as Timestamp?;
                   }
               }
               
               if (ts == null) continue;
               
               DateTime docDate = ts.toDate();
               bool isWithinMonth = (docDate.year == start.year && docDate.month == start.month);

                if ((isPaidDoc || isCreditCard) && isNotCanceled && isWithinMonth) {
                   total += double.tryParse(data['amount'].toString()) ?? 0.0;
               }
             }
             return total;
        });
  }

  Stream<double> _getExpensesStream(String clinicId) {
    final start = _startOfMonth;
    return FirebaseFirestore.instance.collection('expenses')
        .where('clinicId', isEqualTo: clinicId)
        .snapshots()
        .map((snap) {
             double total = 0.0;
              for (var doc in snap.docs) {
                final data = doc.data();
                // Definição única de "pago" (+ flag crua legada).
                final isPaidExpense = FinancialModel.isPaidOf(
                        status: data['status']?.toString() ?? '',
                        paidAmount: data['paidAmount'],
                        amount: data['amount'],
                      ) ||
                    data['isPaid'] == true;
               
               Timestamp? ts = data['paidDate'] as Timestamp? ?? 
                               data['paymentDate'] as Timestamp? ?? 
                               data['dueDate'] as Timestamp? ?? 
                               data['date'] as Timestamp? ?? 
                               data['createdAt'] as Timestamp?;
               
                if (ts == null) continue;

                DateTime docDate = ts.toDate();
                bool isWithinMonth = (docDate.year == start.year && docDate.month == start.month);

                if (isPaidExpense && isWithinMonth) {
                   total += double.tryParse(data['amount'].toString()) ?? 0.0;
               }
             }
             return total;
        });
  }

  // O FUNIL DE ANTECIPAÇÃO (Implacável e Inteligente)
  Stream<double> _getAvailableAnticipationStream(String clinicId) {
    return FirebaseFirestore.instance.collection('financial')
        .where('clinicId', isEqualTo: clinicId)
        .snapshots()
        .map((snap) {
             double totalAvailable = 0.0;
             for (var doc in snap.docs) {
               final data = doc.data();
               if (data['type'] != 'income') continue;

               final status = (data['status'] ?? '').toString().toLowerCase().trim();
               final method = (data['paymentMethod'] ?? '').toString().toLowerCase();
               
               bool isCard = method.contains('cart') || method.contains('crédit') || method.contains('credit');
               
               // REGRA 1: Não pode ser cancelado, nem já estar antecipado
               bool isAvailable = isCard && !status.contains('anticipat') && !status.contains('antecipad') && !status.contains('cancel');
               
               // REGRA 2: Só pode antecipar se ainda não venceu (o dinheiro ainda não caiu na conta naturalmente)
               Timestamp? ts = data['dueDate'] as Timestamp? ?? data['date'] as Timestamp?;
               DateTime dueDate = ts?.toDate() ?? DateTime.now();
               DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
               bool isExpired = dueDate.isBefore(today); // Se o vencimento foi ontem ou antes, já expirou a chance de antecipar
               
               if (isAvailable && !isExpired) {
                   totalAvailable += double.tryParse(data['amount'].toString()) ?? 0.0;
               }
             }
             return totalAvailable;
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_clinicId == null) return const Center(child: Text("Erro: Clínica não selecionada."));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Painel DRE Gerencial", style: TextStyle(fontWeight: FontWeight.bold )),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MonthSelector(date: _currentMonth, onPrev: () => _changeMonth(-1), onNext: () => _changeMonth(1)),
            const SizedBox(height: 20),

            AnimatedOpacity(
              opacity: _isChangingMonth ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: StreamBuilder<double>(
                stream: _revenueStream,
                builder: (context, snapRev) {
                  return StreamBuilder<double>(
                    stream: _expensesStream,
                    builder: (context, snapExp) {
                      return StreamBuilder<double>(
                        stream: _availableAnticipationStream,
                        builder: (context, snapAnt) {
                          
                          if (snapRev.connectionState == ConnectionState.waiting && snapExp.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(),
                            ));
                          }

                          final double revenue = snapRev.data ?? 0.0;
                          final double expenses = snapExp.data ?? 0.0;
                          final double availableToAnticipate = snapAnt.data ?? 0.0; 
                          
                          final double netProfit = revenue - expenses;
                          final bool isProfit = netProfit >= 0;
                          double profitMargin = revenue > 0 ? (netProfit / revenue) * 100 : 0.0;

                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isProfit
                                      ? (AppColors.isDark ? const Color(0xFF1B3A24) : Colors.green[50])
                                      : (AppColors.isDark ? const Color(0xFF3A1B1B) : Colors.red[50]),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isProfit ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(isProfit ? Icons.trending_up : Icons.warning, color: isProfit ? Colors.green : Colors.red),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        revenue == 0 && expenses == 0 
                                          ? "Sem dados apurados para o mês exibido." 
                                          : (isProfit ? "Resultado positivo! Margem: ${profitMargin.toStringAsFixed(1)}%." : "Atenção: Operação no prejuízo."),
                                        style: TextStyle(color: isProfit ? (AppColors.isDark ? Colors.green[300] : Colors.green[800]) : (AppColors.isDark ? Colors.red[300] : Colors.red[800]), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _KpiCard(title: "Receita Realizada", value: revenue, color: Colors.green, icon: Icons.arrow_upward)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _ExpandableExpenseCard(totalValue: expenses, currentMonth: _currentMonth)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _AnticipationCard(value: availableToAnticipate, onTap: () => _showAnticipationModal(context))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              _KpiCard(title: "LUCRO LÍQUIDO (Caixa)", value: netProfit, color: isProfit ? Colors.blue : Colors.red, icon: Icons.account_balance_wallet, isHighlight: true),
                              
                              const SizedBox(height: 24),

                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FinancialReportScreen())),
                                      icon: const Icon(Icons.list_alt, size: 18),
                                      label: const Text("LIVRO CAIXA"),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: Colors.blue[800], elevation: 0, side: BorderSide(color: Colors.blue.shade200), padding: const EdgeInsets.symmetric(vertical: 16)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ExpensesScreen())),
                                      icon: const Icon(Icons.money_off, size: 18),
                                      label: const Text("A PAGAR"),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.isDark ? const Color(0xFF3A1B1B) : Colors.red[50], foregroundColor: AppColors.isDark ? Colors.red[300] : Colors.red[800], elevation: 0, side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(vertical: 16)),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              const Text("Previsão para Fechamento", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 8),
                              
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    const Text("Saldo Projetado (Final do Mês):"),
                                    Text("R\$ ${netProfit.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: netProfit >= 0 ? AppColors.textPrimary : Colors.red))
                                ]),
                              )
                            ],
                          );
                        }
                      );
                    }
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnticipationModal(BuildContext context) {
    final amountCtrl = TextEditingController();
    final clinicId = SessionManager().currentClinicId;
    double availableTotal = 0.0;

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on, color: Colors.amber, size: 40),
                const SizedBox(height: 10),
                const Text("Simular Antecipação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Converta recebimentos de Cartão pendentes em dinheiro hoje.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('financial')
                      .where('clinicId', isEqualTo: clinicId)
                      .where('type', isEqualTo: 'income')
                      .get(),
                  builder: (c, snap) {
                    if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    if (snap.hasError) return Text("Erro: ${snap.error}", style: const TextStyle(color: Colors.red));
                    
                    if (snap.hasData) {
                      availableTotal = snap.data!.docs.fold(0.0, (sum, doc) {
                        final data = doc.data() as Map<String, dynamic>; 
                        final status = (data['status'] ?? '').toString().toLowerCase().trim();
                        final method = (data['paymentMethod'] ?? '').toString().toLowerCase();
                        
                        bool isCard = method.contains('cart') || method.contains('crédit') || method.contains('credit');
                        bool isAvailable = isCard && !status.contains('anticipat') && !status.contains('antecipad') && !status.contains('cancel');
                        
                        Timestamp? ts = data['dueDate'] as Timestamp? ?? data['date'] as Timestamp?;
                        DateTime dueDate = ts?.toDate() ?? DateTime.now();
                        DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                        bool isExpired = dueDate.isBefore(today);
                        
                        if (isAvailable && !isExpired) {
                           return sum + (double.tryParse(data['amount'].toString()) ?? 0.0);
                        }
                        return sum;
                      });
                    }
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.isDark ? const Color(0xFF3A2E12) : Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("Disponível:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                          Text("R\$ ${availableTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    );
                  }
                ),
                
                const SizedBox(height: 15),
                TextField(
                  controller: amountCtrl, 
                  keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                  decoration: const InputDecoration(labelText: "Valor para Antecipar", prefixText: "R\$ ", border: OutlineInputBorder())
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _processAnticipation(context, amountCtrl.text, availableTotal),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.white),
                    child: const Text("VER PARCELAS E CONFIRMAR"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      }
    );
  }

  void _processAnticipation(BuildContext context, String valueStr, double maxAvailable) async {
    double targetVal = double.tryParse(valueStr.replaceAll(',', '.')) ?? 0.0;
    
    if (targetVal <= 0 || targetVal > (maxAvailable + 0.05)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Valor inválido ou superior ao disponível."), backgroundColor: Colors.red));
       return;
    }

    final clinicId = SessionManager().currentClinicId;
    
    final snapshot = await FirebaseFirestore.instance.collection('financial')
        .where('clinicId', isEqualTo: clinicId)
        .where('type', isEqualTo: 'income')
        .get();

    List<DocumentSnapshot> validDocs = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase().trim();
      final method = (data['paymentMethod'] ?? '').toString().toLowerCase();
      
      bool isCard = method.contains('cart') || method.contains('crédit') || method.contains('credit');
      bool isAvailable = isCard && !status.contains('anticipat') && !status.contains('antecipad') && !status.contains('cancel');
      
      Timestamp? ts = data['dueDate'] as Timestamp? ?? data['date'] as Timestamp?;
      DateTime dueDate = ts?.toDate() ?? DateTime.now();
      DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      bool isExpired = dueDate.isBefore(today);
      
      if (isAvailable && !isExpired) validDocs.add(doc);
    }

    validDocs.sort((a, b) {
       Timestamp? tsA = (a.data() as Map)['dueDate'] as Timestamp? ?? (a.data() as Map)['date'] as Timestamp?;
       Timestamp? tsB = (b.data() as Map)['dueDate'] as Timestamp? ?? (b.data() as Map)['date'] as Timestamp?;
       if (tsA == null || tsB == null) return 0;
       return tsA.compareTo(tsB);
    });

    double remainingToAnticipate = targetVal;
    double totalFees = 0;
    double totalRealized = 0;
    List<_AnticipationParcel> parcelsToAnticipate = [];
    double monthlyRate = 2.29; 

    try {
       final settings = await FirebaseFirestore.instance.collection('clinics').doc(clinicId).collection('settings').doc('fees').get();
       if (settings.exists) monthlyRate = (double.tryParse(settings.data()?['anticipation_rate'].toString() ?? '') ?? 2.29);
    } catch(e){}

    for (var doc in validDocs) {
      if (remainingToAnticipate <= 0.01) break; 
      
      final data = doc.data() as Map<String, dynamic>;
      double docAmount = double.tryParse(data['amount'].toString()) ?? 0.0;
      if (docAmount <= 0) continue;
      
      Timestamp? ts = data['dueDate'] as Timestamp? ?? data['date'] as Timestamp?;
      DateTime dueDate = ts?.toDate() ?? DateTime.now();
      
      int days = dueDate.difference(DateTime.now()).inDays;
      int months = (days / 30).ceil(); 
      if (months < 1) months = 1; 
      
      double takenAmount = 0.0;
      bool isPartial = false;

      if (docAmount <= remainingToAnticipate) {
          takenAmount = docAmount;
      } else {
          takenAmount = remainingToAnticipate;
          isPartial = true;
      }

      double fee = takenAmount * (monthlyRate / 100) * months;
      
      parcelsToAnticipate.add(_AnticipationParcel(
        doc: doc, 
        dueDate: dueDate,
        originalAmount: docAmount, 
        takenAmount: takenAmount, 
        fee: fee, 
        isPartial: isPartial
      ));

      remainingToAnticipate -= takenAmount;
      totalRealized += takenAmount;
      totalFees += fee;
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => AlertDialog(
        title: const Text("Detalhes da Antecipação", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text("Você está a solicitar R\$ ${targetVal.toStringAsFixed(2)}. Veja abaixo as parcelas que serão utilizadas:", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              
              Flexible(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: parcelsToAnticipate.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = parcelsToAnticipate[index];
                      final dateStr = DateFormat('dd/MM/yy').format(p.dueDate);
                      
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Venc: $dateStr", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text("R\$ ${p.takenAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.isPartial) 
                              Text("Utilizando parte da parcela de R\$ ${p.originalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.orange, fontSize: 10)),
                            Text("Taxa est.: R\$ ${p.fee.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontSize: 10)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              const Divider(thickness: 2),
              
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Total Bruto:", style: TextStyle(fontSize: 12)),
                Text("R\$ ${totalRealized.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Taxas da Antecipação:", style: TextStyle(fontSize: 12)),
                Text("- R\$ ${totalFees.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontSize: 14)),
              ]),
              const SizedBox(height: 5),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("LÍQUIDO A RECEBER:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("R\$ ${(totalRealized - totalFees).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
              ]),
            ]
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              try {
                showDialog(
                  context: ctx, 
                  barrierDismissible: false, 
                  builder: (loadingCtx) => const Center(child: CircularProgressIndicator(color: Colors.white))
                );

                WriteBatch batch = FirebaseFirestore.instance.batch();

                if (totalFees > 0) {
                  DocumentReference expenseRef = FirebaseFirestore.instance.collection('expenses').doc();
                  batch.set(expenseRef, {
                    'clinicId': clinicId,
                    'amount': totalFees,
                    'title': 'Taxa de Antecipação de Recebíveis',
                    'category': 'Taxas de Antecipação',
                    'description': 'Taxa gerada automaticamente sobre antecipação de R\$ ${targetVal.toStringAsFixed(2)}',
                    'isPaid': true,
                    'status': 'pago',
                    'date': Timestamp.now(),
                    'paidDate': Timestamp.now(),
                    'paymentDate': Timestamp.now(),
                    'createdAt': Timestamp.now(),
                  });
                }

                for (var p in parcelsToAnticipate) {
                  if (!p.isPartial) {
                     batch.update(p.doc.reference, {
                       'status': 'anticipated', 
                       'paidDate': Timestamp.now(),
                       'anticipatedAmount': p.takenAmount,
                     });
                  } else {
                     batch.update(p.doc.reference, {
                       'amount': p.originalAmount - p.takenAmount,
                     });

                     DocumentReference splitRef = FirebaseFirestore.instance.collection('financial').doc();
                     Map<String, dynamic> splitData = Map<String, dynamic>.from(p.doc.data() as Map<String, dynamic>);
                     
                     splitData['amount'] = p.takenAmount;
                     splitData['status'] = 'anticipated';
                     splitData['paidDate'] = Timestamp.now(); 
                     splitData['anticipatedAmount'] = p.takenAmount;
                     splitData['isPartialAnticipation'] = true; 
                     splitData['originalDocId'] = p.doc.id; 
                     
                     batch.set(splitRef, splitData);
                  }
                }

                await batch.commit();
                
                if (ctx.mounted) Navigator.pop(ctx); 
                if (ctx.mounted) Navigator.pop(ctx); 
                if (context.mounted) Navigator.pop(context); 
                
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Antecipação realizada! O valor bruto foi para as receitas e as taxas para as despesas."), backgroundColor: Colors.green));
              
              } catch(e) {
                Navigator.pop(ctx); 
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Erro ao gravar: $e"), backgroundColor: Colors.red));
              }
            }, 
            child: const Text("CONFIRMAR OPERAÇÃO")
          )
        ],
      )
    );
  }
}

class _AnticipationParcel {
  final DocumentSnapshot doc;
  final DateTime dueDate;
  final double originalAmount;
  final double takenAmount;
  final double fee;
  final bool isPartial;

  _AnticipationParcel({
    required this.doc,
    required this.dueDate,
    required this.originalAmount,
    required this.takenAmount,
    required this.fee,
    required this.isPartial,
  });
}

class _AnticipationCard extends StatelessWidget {
  final VoidCallback onTap;
  final double value;
  const _AnticipationCard({required this.onTap, this.value = 0.0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.isDark ? const Color(0xFF3A2E12) : Colors.amber[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(Icons.flash_on, color: Colors.amber, size: 20), Icon(Icons.chevron_right, color: Colors.amber, size: 16)]),
            const Spacer(),
            Text("Disponível p/ Antecipar", style: TextStyle(fontSize: 11, color: AppColors.isDark ? Colors.amber[200] : Colors.amber[800], fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("R\$ ${value.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.isDark ? Colors.amber[100] : Colors.amber[900])),
        ]),
      ),
    );
  }
}

class _ExpandableExpenseCard extends StatefulWidget {
  final double totalValue;
  final DateTime currentMonth;
  const _ExpandableExpenseCard({required this.totalValue, required this.currentMonth});
  @override
  State<_ExpandableExpenseCard> createState() => _ExpandableExpenseCardState();
}

class _ExpandableExpenseCardState extends State<_ExpandableExpenseCard> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: _isExpanded ? Colors.red : Colors.transparent), 
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        mainAxisSize: MainAxisSize.min, 
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    const Icon(Icons.arrow_downward, color: Colors.red, size: 20), 
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.grey)
                  ]
                ),
                const SizedBox(height: 10),
                Text("Despesas Pagas", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text("R\$ ${widget.totalValue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              ]
            ),
          ),
          
          if (_isExpanded) ...[
            const Divider(),
            const Text("Detalhamento:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 5),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('expenses')
                  .where('clinicId', isEqualTo: SessionManager().currentClinicId)
                  .get(), 
              builder: (context, snap) {
                if (snap.hasError) return Text("Erro: ${snap.error}", style: const TextStyle(fontSize: 8, color: Colors.red));
                if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator(minHeight: 2);
                if (!snap.hasData || snap.data!.docs.isEmpty) return const Text("Nenhuma despesa no período.", style: TextStyle(fontSize: 10, color: Colors.grey));
                
                Map<String, double> groupedExpenses = {};
                
                final start = DateTime(widget.currentMonth.year, widget.currentMonth.month, 1);
                final end = DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 1);

                for (var doc in snap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  final isPaidBool = data['isPaid'] == true;
                  
                  if (!isPaidBool && !['paid', 'pago', 'quitado'].contains(status)) continue;

                  Timestamp? ts = data['paidDate'] as Timestamp? ?? 
                                 data['paymentDate'] as Timestamp? ?? 
                                 data['dueDate'] as Timestamp? ?? 
                                 data['date'] as Timestamp? ?? 
                                 data['createdAt'] as Timestamp?;
                                 
                  if (ts == null) continue;
                  
                  DateTime docDate = ts.toDate();
                  if (docDate.isBefore(start) || (docDate.isAfter(end) && !docDate.isAtSameMomentAs(end))) continue;

                  double val = double.tryParse(data['amount'].toString()) ?? 0.0;
                  String cat = (data['category'] ?? '').toString().trim();
                  String patientName = (data['patientName'] ?? data['patient_name'] ?? '').toString().trim();

                  String profName = (data['dentistName'] ?? 
                                     data['dentist_name'] ?? 
                                     data['professionalName'] ?? 
                                     data['employeeName'] ?? '').toString().trim();
                  
                  if (profName.isEmpty && data['dentist'] is Map) {
                      profName = (data['dentist']['name'] ?? '').toString().trim();
                  }

                  bool isCommission = data['isCommission'] == true || cat.toLowerCase().contains('comiss');
                  
                  if (isCommission && profName.isEmpty && data['supplierName'] != null) {
                      profName = data['supplierName'].toString().trim();
                  }

                  if (profName.isNotEmpty && profName.toLowerCase() != patientName.toLowerCase()) {
                      isCommission = true;
                  }
                  
                  String groupName = "Outras Despesas";
                  
                  if (isCommission) {
                      if (profName.isEmpty) {
                         String title = (data['title'] ?? data['description'] ?? '').toString().trim();
                         
                         if (patientName.isNotEmpty && title.toLowerCase().contains(patientName.toLowerCase())) {
                            title = title.replaceAll(RegExp(patientName, caseSensitive: false), '').replaceAll('-', '').trim();
                         }
                         title = title.replaceAll(RegExp(r'Comiss[ãa]o\s*', caseSensitive: false), '').replaceAll('-', '').trim();
                         
                         profName = title.isNotEmpty ? title : "Não Informado";
                      }
                      groupName = "Comissão: $profName";
                  } 
                  else if (data['supplierName'] != null && data['supplierName'].toString().trim().isNotEmpty) {
                      groupName = "Fornec: ${data['supplierName']}";
                  } 
                  else if (cat.isNotEmpty) {
                      groupName = cat;
                  }

                  groupedExpenses[groupName] = (groupedExpenses[groupName] ?? 0.0) + val;
                }

                if (groupedExpenses.isEmpty) {
                   return const Text("Nenhum detalhe encontrado.", style: TextStyle(fontSize: 10, color: Colors.grey));
                }

                var sortedEntries = groupedExpenses.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return Column(
                  children: sortedEntries.map((e) => _miniRow(e.key, e.value)).toList(),
                );
              }
            )
          ]
        ]
      ),
    );
  }
  
  Widget _miniRow(String label, double val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Expanded(
            child: Text(
              label, 
              style: const TextStyle(fontSize: 10 ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          ), 
          const SizedBox(width: 8),
          Text("R\$ ${val.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red))
        ]
      )
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title; final double value; final Color color; final IconData icon; final bool isHighlight;
  const _KpiCard({required this.title, required this.value, required this.color, required this.icon, this.isHighlight = false});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: isHighlight ? Border.all(color: color, width: 2) : null, boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 20), if (isHighlight) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: const Text("RESULTADO", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))]), const SizedBox(height: 10), Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text("R\$ ${value.toStringAsFixed(2)}", style: TextStyle(fontSize: isHighlight ? 24 : 16, fontWeight: FontWeight.bold, color: color))]));
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime date; final VoidCallback onPrev; final VoidCallback onNext;
  const _MonthSelector({required this.date, required this.onPrev, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(30)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev), Text(DateFormat('MMMM yyyy', 'pt_BR').format(date).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext)]));
  }
}