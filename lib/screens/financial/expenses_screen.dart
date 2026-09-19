import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:odonto_controle/services/session_manager.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../ui/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odonto_controle/utils/display.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _expenseService = ExpenseService();

  DateTime _currentMonth = DateTime.now();
  String _filterStatus = 'Todos'; 

  void _changeMonth(int months) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + months, 1);
    });
  }

  // --- DIALOG DE NOVA DESPESA ---
  void _showAddExpenseDialog() {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedCategory = 'Custos Fixos';
    
    final List<String> categories = ['Custos Fixos', 'Manutenção', 'Impostos', 'Marketing', 'Outros'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: const Text("Nova Despesa"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Descrição")),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: "Valor (R\$)"), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setStateModal(() => selectedCategory = v!),
                  decoration: const InputDecoration(labelText: "Categoria"),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Vencimento: "),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context, 
                          initialDate: selectedDate, 
                          firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                          lastDate: DateTime.now().add(const Duration(days: 365))
                        );
                        if (picked != null) setStateModal(() => selectedDate = picked);
                      },
                      child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                    )
                  ],
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                  
                  final double val = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                  
                  // (2) CORREÇÃO AQUI: Apenas um par de parênteses
                  final clinicId = SessionManager().currentClinicId; 

                  final newExpense = ExpenseModel(
                    id: '',
                    clinicId: clinicId!,
                    title: descCtrl.text,
                    description: descCtrl.text,
                    amount: val,
                    date: DateTime.now(), // Data de competência
                    dueDate: selectedDate, // Data de vencimento
                    status: 'pendente',
                    category: selectedCategory,
                    isCommission: false,
                  );

                  // O erro do Firebase sumirá com o import lá em cima
                  await FirebaseFirestore.instance.collection('expenses').add(newExpense.toMap());
                  if(mounted) Navigator.pop(ctx);
                },
                child: const Text("Salvar"),
              )
            ],
          );
        }
      )
    );
  }

  // --- AÇÃO DE PAGAR ---
  void _confirmPayment(ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Baixar Pagamento"),
        content: Text("Confirma o pagamento de ${formatBRL(expense.amount)} para ${expense.supplierName ?? 'Fornecedor'}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              await _expenseService.markAsPaid(expense.id, DateTime.now());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("CONFIRMAR PAGAMENTO"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Contas a Pagar", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list ),
            onPressed: () {
              setState(() {
                if (_filterStatus == 'Todos') _filterStatus = 'Pendente';
                else if (_filterStatus == 'Pendente') _filterStatus = 'Pago';
                else _filterStatus = 'Todos';
              });
              toast(context, "Filtrando por: $_filterStatus", duration: const Duration(seconds: 1));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(),
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add),
        label: const Text("NOVA DESPESA"),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                Column(
                  children: [
                    Text("COMPETÊNCIA", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text(DateFormat('MMMM yyyy', 'pt_BR').format(_currentMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<ExpenseModel>>(
              stream: _expenseService.getByMonth(_currentMonth),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final allExpenses = snapshot.data!;
                
                final filtered = allExpenses.where((e) {
                  if (_filterStatus == 'Todos') return true;
                  if (_filterStatus == 'Pendente') return e.status != 'pago';
                  if (_filterStatus == 'Pago') return e.status == 'pago';
                  return true;
                }).toList();

                filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.thumb_up_alt_outlined, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("Nenhuma conta encontrada."),
                        Text("Filtro: $_filterStatus", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildExpenseCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(ExpenseModel item) {
    bool isPaid = item.status == 'pago';
    
    Color statusColor = Colors.grey;
    String statusText = "PAGO";
    
    if (!isPaid) {
      final daysDiff = item.dueDate.difference(DateTime.now()).inDays;
      if (daysDiff < 0) {
        statusColor = Colors.red;
        statusText = "VENCIDO";
      } else if (daysDiff <= 2) {
        statusColor = Colors.orange;
        statusText = "VENCE EM BREVE";
      } else {
        statusColor = Colors.blue;
        statusText = "EM ABERTO";
      }
    } else {
      statusColor = Colors.green;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: statusColor.withValues(alpha: 0.3))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(isPaid ? Icons.check_circle : Icons.attach_money, color: statusColor),
        ),
          title: Text(item.description, style: TextStyle(fontWeight: FontWeight.bold, decoration: isPaid ? TextDecoration.lineThrough : null, color: isPaid ? Colors.grey : AppColors.textPrimary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.supplierName ?? 'Fornecedor', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text("Venc: ${DateFormat('dd/MM').format(item.dueDate)}", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("${formatBRL(item.amount)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPaid ? Colors.grey : Colors.red[800])),
            if (!isPaid)
              InkWell(
                onTap: () => _confirmPayment(item),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("PAGAR", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              )
          ],
        ),
      ),
    );
  }
}