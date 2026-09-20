import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import '../../../ui/app_theme.dart';
import '../../../utils/display.dart';
import '../../../widgets/status_chip.dart';
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

  // Filtros e ordenação da timeline
  final TextEditingController _minValueCtrl = TextEditingController();
  final TextEditingController _maxValueCtrl = TextEditingController();
  String? _procedureFilter;
  String _sortMode = 'dueAsc'; // 'record' | 'dueAsc' | 'dueDesc'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _minValueCtrl.dispose();
    _maxValueCtrl.dispose();
    super.dispose();
  }

  double? _parseFilterValue(String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return value;
  }

  String _itemProcedure(dynamic item) {
    if (item is FinancialModel) return item.title;
    return (item as ExpenseModel).category;
  }

  double _itemAmount(dynamic item) {
    if (item is FinancialModel) return item.amount;
    return (item as ExpenseModel).amount;
  }

  DateTime? _itemDueDate(dynamic item) {
    if (item is FinancialModel) return item.dueDate;
    return (item as ExpenseModel).dueDate;
  }

  void _clearTimelineFilters() {
    setState(() {
      _minValueCtrl.clear();
      _maxValueCtrl.clear();
      _procedureFilter = null;
      _sortMode = 'dueAsc';
    });
  }

  int get _activeFilterCount {
    var count = 0;
    if (_parseFilterValue(_minValueCtrl.text) != null) count++;
    if (_parseFilterValue(_maxValueCtrl.text) != null) count++;
    if (_procedureFilter != null) count++;
    return count;
  }

  void _toggleDueSort() {
    setState(() {
      _sortMode = _sortMode == 'dueAsc' ? 'dueDesc' : 'dueAsc';
    });
  }

  void _openFilterSheet(List<String> procedures) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void update(void Function() change) {
              setSheetState(change);
              setState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text("Filtros",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minValueCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText: "Valor mín",
                              prefixText: "R\$ ",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => update(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxValueCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText: "Valor máx",
                              prefixText: "R\$ ",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => update(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _procedureFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Procedimento",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("Todos"),
                        ),
                        ...procedures.map((p) => DropdownMenuItem<String>(
                              value: p,
                              child: Text(p,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) =>
                          update(() => _procedureFilter = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _sortMode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Ordenar por",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'record',
                          child: Text("Registro (atual)"),
                        ),
                        DropdownMenuItem(
                          value: 'dueAsc',
                          child: Text("Vencimento (próximos)"),
                        ),
                        DropdownMenuItem(
                          value: 'dueDesc',
                          child: Text("Vencimento (distantes)"),
                        ),
                      ],
                      onChanged: (val) =>
                          update(() => _sortMode = val ?? 'record'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _clearTimelineFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text("Limpar filtros"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadData() async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId != null) {
      try {
        var dentistsList = await _userService.getDentistsForClinic(clinicId);
        List<SupplierModel> suppliersList = [];
        try {
           var stream = _supplierService.getAllStream();
           suppliersList = await stream.first; 
        } catch (e) { debugPrint("Info: Sem fornecedores ou erro: $e"); }

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
        } catch (e) { debugPrint("Erro perfis: $e"); }

        if (mounted) {
          setState(() {
            _dentists = dentistsList;
            _suppliers = suppliersList;
            _machineProfiles = profiles;
          });
        }
      } catch (e) {
        debugPrint("Erro loadData: $e");
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
        if (mounted) toast(context, "Telefone não cadastrado.");
        return;
      }
      
      phone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (!phone.startsWith('55')) phone = '55$phone';
      
      String msg = "Olá, lembrete da parcela de ${formatBRL(item.amount)} vencendo em ${formatDateShort(item.dueDate ?? DateTime.now())}.";
      final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(msg)}");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) { debugPrint("$e"); }
  }

  // --- HELPERS DE UI (snackbar + linha de vencimento dos dialogs) ---
  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  /// Linha "Vence: dd/MM/yyyy [ALTERAR]" com date picker. `onPick` recebe
  /// a nova data (o chamador dá `setDlg`/`setState`).
  Widget _dueDateRow(
    BuildContext ctx,
    DateTime due,
    void Function(DateTime) onPick,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text("Vence: ${formatDateFull(due)}"),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: due,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) onPick(picked);
          },
          child: const Text("ALTERAR"),
        ),
      ],
    );
  }

  // --- LÓGICA DE ESTORNO ---
  /// Vinculados (despesas + lab) de um lançamento. Centraliza as 2 queries
  /// repetidas nos dialogs de estorno/cancelamento.
  Future<({List<QueryDocumentSnapshot> expenses, List<QueryDocumentSnapshot> labOrders})>
      relatedDocs(String financialId) async {
    final expenses = await SessionManager()
        .applyFilter(FirebaseFirestore.instance
            .collection('expenses')
            .where('relatedFinancialId', isEqualTo: financialId))
        .get();
    final labOrders = await SessionManager()
        .applyFilter(FirebaseFirestore.instance
            .collection('lab_orders')
            .where('relatedFinancialId', isEqualTo: financialId))
        .get();
    return (expenses: expenses.docs, labOrders: labOrders.docs);
  }
  // Recebe o model (não só o id) para permitir "corrigir e relançar"
  // pré-preenchido após o estorno.
  void _confirmReversal(FinancialModel item) async {
    final id = item.id;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // Verifica Despesas e Pedidos de Lab vinculados
    final related = await relatedDocs(id);
    final relatedExpenses = related.expenses;
    final relatedLabOrders = related.labOrders;

    if (!mounted) return;
    Navigator.pop(context); // Fecha loading

    bool hasLinkedData = relatedExpenses.isNotEmpty || relatedLabOrders.isNotEmpty;

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
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5))
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
                    if (relatedExpenses.isNotEmpty)
                      Text("• ${relatedExpenses.length} Despesa(s) (Comissão/Custo)", style: const TextStyle(fontSize: 11)),
                    if (relatedLabOrders.isNotEmpty)
                      Text("• ${relatedLabOrders.length} Pedido(s) de Laboratório", style: const TextStyle(fontSize: 11)),
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
              for (var doc in relatedExpenses) { await doc.reference.delete(); }
              // Exclui pedidos de lab
              for (var doc in relatedLabOrders) { await doc.reference.delete(); }

              // Executa o estorno
              await _finService.voidPayment(id);

              _toast("Estorno realizado com sucesso!");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("CONFIRMAR ESTORNO"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Mesmo zeramento do estorno...
              for (var doc in relatedExpenses) { await doc.reference.delete(); }
              for (var doc in relatedLabOrders) { await doc.reference.delete(); }
              await _finService.voidPayment(id);

              // ...mas já reabre o recebimento pré-preenchido para corrigir
              if (mounted) {
                _showReceiveDialog(context, item, preFilledData: {
                  'method': item.paymentMethod,
                  'amount': item.amount,
                });
              }
            },
            child: const Text("CORRIGIR E RELANÇAR"),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE CANCELAMENTO (soft-delete com trilha) ---
  // Para cobrança pendente errada ou recebimento duplicado. Some dos
  // relatórios/cobrança/risco sem apagar o histórico (fiscal).
  // Se faz parte de parcelamento, oferece a família toda (parentId).
  void _confirmCancelCharge(FinancialModel item) async {
    final id = item.id;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final related = await relatedDocs(id);
    final relatedExpenses = related.expenses;
    final relatedLabOrders = related.labOrders;

    // Família de parcelamento: irmãs (mesmo parentId) + original pai.
    final parentKey = item.parentId;
    final familyIds = <String>[id];
    if (parentKey != null && parentKey.isNotEmpty) {
      final sibs = await SessionManager()
          .applyFilter(FirebaseFirestore.instance
              .collection('financial')
              .where('parentId', isEqualTo: parentKey))
          .get();
      for (final d in sibs.docs) {
        if (d.id != id && !familyIds.contains(d.id)) familyIds.add(d.id);
      }
      final parentDoc = await FirebaseFirestore.instance
          .collection('financial')
          .doc(parentKey)
          .get();
      if (parentDoc.exists && !familyIds.contains(parentDoc.id)) {
        familyIds.add(parentDoc.id);
      }
    } else {
      final kids = await SessionManager()
          .applyFilter(FirebaseFirestore.instance
              .collection('financial')
              .where('parentId', isEqualTo: id))
          .get();
      for (final d in kids.docs) {
        if (!familyIds.contains(d.id)) familyIds.add(d.id);
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

    final isPaidDoc =
        item.isPaid || (item.paidAmount >= item.amount && item.amount > 0);
    final hasFamily = familyIds.length > 1;

    Future<void> cancelIds(List<String> ids, String okMsg) async {
      // Vinculados de todos (whereIn em blocos de 10)
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(
            i, i + 10 > ids.length ? ids.length : i + 10);
        final exps = await FirebaseFirestore.instance
            .collection('expenses')
            .where('relatedFinancialId', whereIn: chunk)
            .get();
        final labs = await FirebaseFirestore.instance
            .collection('lab_orders')
            .where('relatedFinancialId', whereIn: chunk)
            .get();
        for (var doc in [...exps.docs, ...labs.docs]) {
          await doc.reference.delete();
        }
      }
      for (final fid in ids) {
        await _finService.cancelCharge(fid);
      }
      _toast(okMsg);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancelar Lançamento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "${item.title} — ${formatBRL(item.amount)} (${isPaidDoc ? 'pago' : 'pendente'})"),
            if (hasFamily)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    "Faz parte de um parcelamento com ${familyIds.length} lançamento(s).",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 8),
            const Text(
                "O lançamento sai das cobranças e relatórios, mas o histórico é mantido (status 'cancelado'). Para corrigir valor, use Estornar + Corrigir e relançar."),
            if (relatedExpenses.isNotEmpty ||
                relatedLabOrders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  "Vinculados que serão EXCLUÍDOS: ${relatedExpenses.length} despesa(s), ${relatedLabOrders.length} pedido(s) de lab.",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Voltar"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (var doc in relatedExpenses) {
                await doc.reference.delete();
              }
              for (var doc in relatedLabOrders) {
                await doc.reference.delete();
              }
              await _finService.cancelCharge(id);
              _toast("Lançamento cancelado.");
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(hasFamily ? "SÓ ESTE" : "CANCELAR LANÇAMENTO"),
          ),
          if (hasFamily)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await cancelIds(
                    familyIds, "Família cancelada (${familyIds.length}).");
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white),
              child: Text("FAMÍLIA TODA (${familyIds.length})"),
            ),
        ],
      ),
    );
  }

  // --- FORM RECRIAR COBRANÇA (valores editáveis) ---
  // Pré-preenche com os originais; confirma cria a pendente nova.
  // Vínculos (plano, parcela, mensalidade) vão travados como informação.
  void _confirmRecreateCharge(FinancialModel item) {
    final amountCtrl =
        TextEditingController(text: item.amount.toStringAsFixed(2));
    DateTime due = item.dueDate ?? DateTime.now();

    String linkInfo() {
      final parts = <String>[];
      if ((item.installmentNumber ?? '').isNotEmpty) {
        parts.add('Parcela ${item.installmentNumber}');
      }
      if ((item.monthlyPeriod ?? '').isNotEmpty) {
        parts.add('Mensalidade ${item.monthlyPeriod}');
      }
      if ((item.planId ?? '').isNotEmpty) parts.add('com vínculo de plano');
      return parts.isEmpty ? 'lançamento avulso' : parts.join(' • ');
    }

    double parseAmount(String text) => parseBRL(text);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text("Recriar Cobrança"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(linkInfo(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Valor (R\$)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _dueDateRow(ctx, due, (d) => setDlg(() => due = d)),
              if ((item.installmentNumber ?? '').contains('/'))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      "Atenção: as parcelas irmãs mantêm os valores antigos.",
                      style: TextStyle(fontSize: 11, color: Colors.orange)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Voltar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = parseAmount(amountCtrl.text);
                if (val <= 0) {
                  _toast("Informe um valor maior que zero.", error: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _finService.recreateCharge(item.id,
                      amount: val, dueDate: due);
                  _toast("Cobrança recriada como pendente.");
                } catch (e) {
                  _toast("Falha ao recriar: $e", error: true);
                }
              },
              child: const Text("RECRIAR"),
            ),
          ],
        ),
      ),
    );
  }

  // --- EDITAR PENDENTE (valor/vencimento, sem mexer em quitação) ---
  void _showEditPendingCharge(FinancialModel item) {
    final amountCtrl =
        TextEditingController(text: item.amount.toStringAsFixed(2));
    DateTime due = item.dueDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text("Editar Cobrança"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Valor (R\$)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _dueDateRow(ctx, due, (d) => setDlg(() => due = d)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Voltar"),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = parseBRL(amountCtrl.text);
                if (val <= 0) {
                  _toast("Informe um valor maior que zero.", error: true);
                  return;
                }
                Navigator.pop(ctx);
                await _finService.editPendingCharge(item.id,
                    amount: val, dueDate: due);
                _toast("Cobrança atualizada.");
              },
              child: const Text("SALVAR"),
            ),
          ],
        ),
      ),
    );
  }

  // --- MENU DE OPÇÕES (1 toque, por estado; sem long-press) ---
  void _showItemOptions(FinancialModel item) {
    final cancelled = item.status.toLowerCase() == 'cancelado';
    final paid = !cancelled &&
        (item.isPaid || (item.paidAmount >= item.amount && item.amount > 0));

    ListTile opt(IconData icon, String label, VoidCallback action,
        {Color? color}) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color)),
        onTap: () {
          Navigator.pop(context);
          action();
        },
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text("${item.title} — ${formatBRL(item.amount)}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (cancelled) ...[
              opt(Icons.refresh, "Recriar cobrança",
                  () => _confirmRecreateCharge(item)),
            ] else if (paid) ...[
              // O dialog de estorno já oferece "Corrigir e relançar"
              opt(Icons.undo, "Estornar / Corrigir",
                  () => _confirmReversal(item)),
              opt(Icons.cancel_outlined, "Cancelar lançamento",
                  () => _confirmCancelCharge(item),
                  color: Colors.red),
            ] else ...[
              opt(Icons.payments_outlined, "Receber",
                  () => _showReceiveDialog(context, item)),
              opt(Icons.edit_outlined, "Editar valor/vencimento",
                  () => _showEditPendingCharge(item)),
              opt(Icons.cancel_outlined, "Cancelar cobrança",
                  () => _confirmCancelCharge(item),
                  color: Colors.red),
            ],
            const SizedBox(height: 8),
          ],
        ),
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
    bool isCancelled = false;

    if (isIncome) {
      final fin = item as FinancialModel;

      // Cancelada (soft-delete): fora de cobrança/relatórios, mostra cinza
      isCancelled = fin.status.toLowerCase() == 'cancelado';

      // --- MÁGICA DA ARQUITETURA (VISÃO PACIENTE VS TESOURARIA) ---
      // Se for Cartão de Crédito/Débito, a dívida do paciente está quitada.
      // Mantemos o status real intacto (pending) para a Antecipação funcionar nos bastidores.
      bool isCard = (fin.paymentMethod ?? '').toLowerCase().contains('cart');

      isPaid = !isCancelled &&
          (FinancialModel.isPaidOf(
                  status: fin.status,
                  paidAmount: fin.paidAmount,
                  amount: fin.amount) ||
              (isCard &&
                  (fin.status == 'pending' || fin.status == 'pendente')));

      if (isCancelled) {
        status = "Cancelada";
      } else if (isPaid) {
        status = "Pago";
      } else {
        status = "Pendente";
      }
    } else {
      final exp = item as ExpenseModel;
      status = exp.status;
      isPaid = status.toLowerCase() == 'paid' || status.toLowerCase() == 'pago';
    }

    bool isPending = !isPaid && !isCancelled;

    Color bgColor;
    if (isCancelled) {
      bgColor = Colors.grey[200]!;
    } else if (!isIncome) {
      bgColor = Colors.orange[50]!;
    } else if (isPending) {
      bgColor = AppColors.surface;
    } else {
      bgColor = Colors.green[50]!;
    }
    Color borderColor;
    if (isCancelled) {
      borderColor = Colors.grey.withValues(alpha: 0.5);
    } else if (!isIncome) {
      borderColor = Colors.orange.withValues(alpha: 0.2);
    } else if (isPending) {
      borderColor = Colors.red.withValues(alpha: 0.5);
    } else {
      borderColor = Colors.green.withValues(alpha: 0.2);
    }

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
        if (isIncome) _showItemOptions(item as FinancialModel);
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
              Text(formatDateShort(date), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: isIncome ? TextAlign.right : TextAlign.left),
              
              if (isIncome)
                Text((item as FinancialModel).description, 
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary), 
                  textAlign: TextAlign.right
                ),

              const SizedBox(height: 4),
              Text("${formatBRL(amount)}", 
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
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Taxa (${feePercentage.toStringAsFixed(2)}%): - ${formatBRL(taxVal)}", style: TextStyle(fontSize: 10, color: Colors.red[800])),
                      const SizedBox(height: 2),
                      Text("Líquido: ${formatBRL(valorLiquido)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800])),
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
                  StatusChip(
                    label: status,
                    color: chargeBadgeColor(
                        isPaid: isPaid, isPending: isPending),
                    horizontal: 6,
                    vertical: 2,
                    radius: 4,
                    bold: false,
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
    bool isProcessingPayment = false; // trava anti-duplo-submit
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
    // Parse tolerante BR/US centralizado em `parseBRL` (testado).
    // Parse tolerante: parseBRL direto (testado).

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
          double defCost = parseBRL(procedureData['cost'] ?? procedureData['operationalCost']);
          costCtrl.text = defCost.toStringAsFixed(2);
        }
        
        // Cobre variações comuns de colunas de banco
        double commVal = parseBRL(procedureData['commissionValue'] ?? procedureData['commission'] ?? procedureData['repasse']);
        
        if (commissionType == 'percent') {
          defaultPercent = commVal;
        } else {
          defaultFixed = commVal;
        }
      }
    } catch (e) { 
      debugPrint("War Room Debug - Erro Crítico silencioso evitado: $e"); 
    }

    if (item.dentistId != null && _dentists.any((d) => d.id == item.dentistId)) selectedProfessionalId = item.dentistId;

    // Usa o safeParse para garantir que 1.000,00 não vire 0.0
    double initialPay = parseBRL(amountCtrl.text);
    
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
              double total = parseBRL(amountCtrl.text);
              int parc = int.tryParse(installmentsCtrl.text) ?? 1;
              if (parc < 1) parc = 1;
              
              currentFeeRate = 0.0;

              if (feeProfile != null && (selectedMethod == "Débito" || selectedMethod == "Cartão de Crédito")) {
                if (selectedMethod == "Débito") {
                  currentFeeRate = parseBRL(feeProfile?['debit']);
                } else {
                  if (parc == 1) {
                    currentFeeRate = parseBRL(feeProfile?['credit_1x']);
                  } else {
                    final rules = List<Map<String, dynamic>>.from(feeProfile?['installment_rules'] ?? []);
                    final matchingRule = rules.firstWhere(
                      (r) => parc >= (r['from'] ?? 0) && parc <= (r['to'] ?? 0),
                      orElse: () => {},
                    );
                    if (matchingRule.isNotEmpty) {
                      currentFeeRate = parseBRL(matchingRule['rate']);
                    }
                  }
                  if (feeProfile?['anticipation_enabled'] == true) {
                    double antRate = parseBRL(feeProfile?['anticipation_rate']);
                    currentFeeRate += (antRate * parc); 
                  }
                }
              }
              
              totalFeeValue = double.parse((total * (currentFeeRate / 100)).toStringAsFixed(2));
              totalNetValue = total - totalFeeValue;
            }
            
            calculateFees(); 

            void recalculateFromPercent() {
              double pay = parseBRL(amountCtrl.text);
              double pct = parseBRL(commPercentCtrl.text);
              double cost = parseBRL(costCtrl.text);
              double base = pay;
              if (deductCostFromBase) { base = pay - cost; if (base < 0) base = 0; }
              commValueCtrl.text = (base * (pct / 100)).toStringAsFixed(2);
              calculateFees();
            }

            void recalculateFromValue() {
              double pay = parseBRL(amountCtrl.text);
              double valRepasse = parseBRL(commValueCtrl.text);
              double base = pay;
              if (deductCostFromBase) {
                  double cost = parseBRL(costCtrl.text);
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
                      decoration: InputDecoration(labelText: "Valor Pago Agora", prefixText: "R\$ ", border: InputBorder.none),
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
                                  toast(context, "Atenção: Configure as taxas (Perfil Padrão).", color: Colors.orange);
                               }
                               setStateModal(() {
                                 selectedMethod = m;
                                 if(m != "Cartão de Crédito") installmentsCtrl.text = "1";
                                 calculateFees();
                               });
                             }
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                        );
                      }).toList(),
                    ),
                    
                    if (selectedMethod == "Débito" || selectedMethod == "Cartão de Crédito") ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedProfileId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: "Selecione a Máquina", border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.settings_remote)),
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
                        decoration: InputDecoration(labelText: "Número de Parcelas", border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) => setStateModal(() => calculateFees()),
                      ),
                    ],

                    if (selectedMethod == "Débito" || selectedMethod == "Cartão de Crédito") 
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
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
                                Text("- ${formatBRL(totalFeeValue)}", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Valor Líquido Total:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text("${formatBRL(totalNetValue)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // --- ÁREA DE REPASSE E DESPESAS ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
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
                              decoration: InputDecoration(isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true),
                          ),
                          
                          if (selectedProfessionalId != null) ...[
                            const SizedBox(height: 15),
                            if (hasCost) ...[
                               Container(
                                 padding: const EdgeInsets.all(8),
                                 margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.brown.shade200)),
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
                                        decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10), border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true),
                                     ),
                                     const SizedBox(height: 8),
                                     Row(
                                       children: [
                                         Expanded(
                                           child: TextField(
                                              controller: costCtrl,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(labelText: "Valor Custo", prefixText: "R\$ ", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true),
                                              onChanged: (v) => recalculateFromPercent(),
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         Expanded(
                                           child: InkWell(
                                             onTap: () => pickGenericDate((d) => costDueDate = d, costDueDate),
                                             child: InputDecorator(
                                               decoration: InputDecoration(labelText: "Vencimento", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                               child: Text(formatDateShort(costDueDate), style: const TextStyle(fontSize: 13)),
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
                                  child: TextField(controller: commPercentCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "%", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true), onChanged: (v) => recalculateFromPercent()),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(controller: commValueCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Valor Repasse", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true, prefixText: "R\$ "), onChanged: (v) => recalculateFromValue()),
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
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3))
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
                                decoration: InputDecoration(isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: labCostCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: "Custo Estimado", prefixText: "R\$ ", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickGenericDate((d) => labDeliveryDate = d, labDeliveryDate),
                                    child: InputDecorator(
                                      decoration: InputDecoration(labelText: "Previsão Entrega", isDense: true, border: OutlineInputBorder(), fillColor: AppColors.surface, filled: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                      child: Text(formatDateFull(labDeliveryDate), style: const TextStyle(fontSize: 13)),
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
                        onPressed: isProcessingPayment
                            ? null
                            : () async {
                                final val = parseBRL(amountCtrl.text);
                                final inst =
                                    int.tryParse(installmentsCtrl.text) ?? 1;
                                final finalCommission =
                                    parseBRL(commValueCtrl.text);
                                final finalCost = parseBRL(costCtrl.text);

                                if (val <= 0) return;

                                if (generateLabOrder && selectedLabId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Selecione o laboratório."),
                                          backgroundColor: Colors.orange));
                                  return;
                                }

                                // Trava anti-duplo-submit (reentrância gera
                                // parcelas duplicadas)
                                setStateModal(
                                    () => isProcessingPayment = true);
                                bool popped = false;

                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                Navigator.pop(context);
                                popped = true;

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
                            final recording = FinancialService.recordingFor(selectedMethod);
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
                              status: recording.status,
                              isPaid: recording.isPaid,
                              paymentDate: DateTime.now(),
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
                                 'description': "Ref. ${item.title} (${formatDateShort(DateTime.now())})",
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
                               
                               double labCost = parseBRL(labCostCtrl.text);

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
                            // Erro antes do pop: destrava p/ tentar de novo.
                            // (Após o pop o dialog foi descartado: sem reset.)
                            if (!popped && mounted) {
                              setStateModal(
                                  () => isProcessingPayment = false);
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text("Erro ao registrar recebimento: $e"),
                                backgroundColor: Colors.red,
                              )
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: isProcessingPayment
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("CONFIRMAR RECEBIMENTO", style: TextStyle(fontWeight: FontWeight.bold)),
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
              stream: SessionManager()
                  .applyFilter(FirebaseFirestore.instance
                      .collection('expenses')
                      .where('relatedPatientId', isEqualTo: widget.patientId))
                  .snapshots(),
              builder: (context, snapshotExp) {
                
                if (snapshotFin.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                List<dynamic> timeline = [];

                if (snapshotFin.hasData) {
                  for (var item in snapshotFin.data!) {
                    timeline.add(item);
                  }
                }

                if (snapshotExp.hasData) {
                  for (var doc in snapshotExp.data!.docs) {
                    final exp = ExpenseModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                    timeline.add(exp);
                  }
                }

                timeline.sort((a, b) {
                  DateTime dateA = (a is FinancialModel) ? a.date : (a as ExpenseModel).dueDate;
                  DateTime dateB = (b is FinancialModel) ? b.date : (b as ExpenseModel).dueDate;
                  return dateB.compareTo(dateA);
                });

                // Procedimentos distintos para o filtro (títulos + categorias)
                final procedures = timeline
                    .map(_itemProcedure)
                    .where((p) => p.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                // Aplica filtros de valor e procedimento (totais acima usam a lista cheia)
                final minValue = _parseFilterValue(_minValueCtrl.text);
                final maxValue = _parseFilterValue(_maxValueCtrl.text);
                final visible = timeline.where((item) {
                  final amount = _itemAmount(item);
                  if (minValue != null && amount < minValue) return false;
                  if (maxValue != null && amount > maxValue) return false;
                  if (_procedureFilter != null &&
                      _itemProcedure(item) != _procedureFilter) {
                    return false;
                  }
                  return true;
                }).toList();

                // Ordenação da lista visível
                if (_sortMode != 'record') {
                  final ascending = _sortMode == 'dueAsc';
                  visible.sort((a, b) {
                    final dueA = _itemDueDate(a);
                    final dueB = _itemDueDate(b);
                    if (dueA == null && dueB == null) return 0;
                    if (dueA == null) return 1;
                    if (dueB == null) return -1;
                    return ascending
                        ? dueA.compareTo(dueB)
                        : dueB.compareTo(dueA);
                  });
                }

                final bool isFiltered = minValue != null ||
                    maxValue != null ||
                    _procedureFilter != null;

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _openFilterSheet(procedures),
                            icon: const Icon(Icons.filter_list, size: 18),
                            label: Text(
                              _activeFilterCount > 0
                                  ? "Filtros ($_activeFilterCount)"
                                  : "Filtros",
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _toggleDueSort,
                            icon: Icon(
                              _sortMode == 'dueDesc'
                                  ? Icons.arrow_downward
                                  : _sortMode == 'dueAsc'
                                      ? Icons.arrow_upward
                                      : Icons.swap_vert,
                              size: 18,
                            ),
                            label: Text(
                              _sortMode == 'dueDesc'
                                  ? "Distantes"
                                  : _sortMode == 'dueAsc'
                                      ? "Próximos"
                                      : "Ordenar",
                            ),
                          ),
                          const Spacer(),
                          if (isFiltered)
                            Text(
                              "${visible.length} de ${timeline.length}",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    Expanded(
                      child: timeline.isEmpty
                        ? const Center(child: Text("Nenhuma movimentação financeira.", style: TextStyle(color: Colors.grey)))
                        : visible.isEmpty
                          ? const Center(child: Text("Nenhum item corresponde aos filtros.", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final item = visible[index];
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
