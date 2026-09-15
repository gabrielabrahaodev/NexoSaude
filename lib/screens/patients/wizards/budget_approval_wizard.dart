import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/budget_model.dart';
import '../../../models/financial_model.dart';
import '../../../models/expense_model.dart'; 
import '../../../services/treatment_service.dart';
import '../../../services/user_service.dart'; 
import '../../../services/session_manager.dart';
import '../../../ui/app_theme.dart';

class BudgetApprovalWizard extends StatefulWidget {
  final BudgetModel budget;
  const BudgetApprovalWizard({super.key, required this.budget});

  @override
  State<BudgetApprovalWizard> createState() => _BudgetApprovalWizardState();
}

class _BudgetApprovalWizardState extends State<BudgetApprovalWizard> {
  final TreatmentService _treatmentService = TreatmentService();
  final UserService _userService = UserService(); 

  int _currentStep = 0;
  bool _isLoading = true;
  
  // Controle de Fluxo
  bool _hasMonthlyFee = false;
  
  // Controle de Custo Automático
  double _automaticCostValue = 0.0;
  String _costDescription = "";

  // --- DADOS PARA O CONTAS A RECEBER (MENSALIDADES) ---
  final _monthlyValueCtrl = TextEditingController();
  final _installmentsCtrl = TextEditingController(text: '12');
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _analyzeBudget();
  }

  Future<void> _analyzeBudget() async {
    bool foundMonthly = false;
    double foundCost = 0.0;
    String procName = "";

    for (var item in widget.budget.items) {
      final doc = await FirebaseFirestore.instance.collection('procedures').doc(item['id']).get();
      if (doc.exists) {
        final data = doc.data()!;
        
        if (data['generatesMonthlyFee'] == true) {
          foundMonthly = true;
          procName = item['name'];
          
          if (data['hasCost'] == true) {
             foundCost = (data['cost'] ?? data['operationalCost'] ?? 0.0).toDouble();
          }
        }
      }
    }

    setState(() {
      _hasMonthlyFee = foundMonthly;
      _automaticCostValue = foundCost;
      _costDescription = procName;
      _isLoading = false;
      
      if (_hasMonthlyFee) _monthlyValueCtrl.text = "0,00"; 
    });
  }

  // --- GERADOR DE RECEBÍVEIS (CORRIGIDO) ---
  List<FinancialModel> _generateReceivables() {
    List<FinancialModel> list = [];
    
    // 1. MENSALIDADES (Se houver configuração de Ortodontia)
    if (_hasMonthlyFee) {
      int qtd = int.tryParse(_installmentsCtrl.text) ?? 0;
      double valor = double.tryParse(_monthlyValueCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (qtd > 0 && valor > 0) {
        DateTime date = _firstDueDate;
        for (int i = 1; i <= qtd; i++) {
          list.add(FinancialModel(
            id: '', 
            clinicId: widget.budget.clinicId,
            title: "Manutenção ${widget.budget.patientName} ($i/$qtd)",
            description: "Parcela Mensal de Ortodontia", 
            amount: valor,
            date: date, 
            dueDate: date, 
            status: 'pendente',
            type: 'income', // <--- CORREÇÃO: Tipo Receita
            patientId: widget.budget.patientId,
            patientName: widget.budget.patientName,
            installmentNumber: '$i/$qtd',
            planId: '',
          ));
          date = date.add(const Duration(days: 30));
        }
      }
    } 
    
    // 2. PROCEDIMENTOS DO ORÇAMENTO
    for (var item in widget.budget.items) {
      double price = (item['price'] ?? 0.0).toDouble();
      
      if (price > 0) {
        list.add(FinancialModel(
          id: '',
          clinicId: widget.budget.clinicId,
          title: item['name'] ?? 'Procedimento', 
          description: "Ref. Orçamento Aprovado",
          amount: price,
          date: DateTime.now(), 
          dueDate: DateTime.now(), 
          status: 'pendente',
          type: 'income', // <--- CORREÇÃO: Tipo Receita
          patientId: widget.budget.patientId,
          patientName: widget.budget.patientName,
          installmentNumber: '1/1',
          planId: '',
        ));
      }
    }
    
    return list;
  }

  // --- GERADOR DE CUSTO ---
  List<ExpenseModel> _generateAutomaticCost() {
    List<ExpenseModel> list = [];
    
    if (_hasMonthlyFee && _automaticCostValue > 0) {
      list.add(ExpenseModel(
        id: '',
        clinicId: widget.budget.clinicId,
        title: "Custo Inicial - $_costDescription", 
        description: "Custo Operacional Automático (Início Tratamento)",
        amount: _automaticCostValue,
        date: DateTime.now(), 
        dueDate: DateTime.now(), 
        status: 'pendente',
        category: 'Custo Operacional', 
        relatedPatientId: widget.budget.patientId,
        isCommission: false,
      ));
    }
    
    return list;
  }

  Future<void> _finish() async {
    setState(() => _isLoading = true);
    try {
      final receivables = _generateReceivables(); 
      final payables = _generateAutomaticCost();

      await _treatmentService.approveBudgetWithFinancials(
        budget: widget.budget, 
        receivables: receivables, 
        payables: payables 
      );
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aprovado com sucesso!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    }
  }

  // --- STEPS VISUAIS ---

  Widget _buildStepMonthly() {
    return _genericStep(
      icon: Icons.calendar_month, color: AppColors.primary,
      title: "Mensalidades", subtitle: "Defina as parcelas da Ortodontia.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _monthlyValueCtrl, decoration: const InputDecoration(labelText: "Valor Mensal (R\$)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _installmentsCtrl, decoration: const InputDecoration(labelText: "Qtd Parcelas", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: InkWell(onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _firstDueDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
              if (d != null) setState(() => _firstDueDate = d);
            }, child: InputDecorator(decoration: const InputDecoration(labelText: "1º Vencimento", border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(_firstDueDate))))),
          ]),
          
          if (_automaticCostValue > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Um custo operacional de R\$ ${_automaticCostValue.toStringAsFixed(2)} será lançado automaticamente no Contas a Pagar.",
                      style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      )
    );
  }

  Widget _buildConfirmationStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text("Tudo Pronto!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          if (_hasMonthlyFee)
            Text("• ${_installmentsCtrl.text} mensalidades de manutenção", style: const TextStyle(fontWeight: FontWeight.bold)),
          
          if (widget.budget.items.isNotEmpty)
            Text("• ${widget.budget.items.length} procedimento(s) a receber (Instalação/Venda)", style: const TextStyle(fontWeight: FontWeight.bold)),

          if (_automaticCostValue > 0 && _hasMonthlyFee)
             Padding(
               padding: const EdgeInsets.only(top: 10),
               child: Text(
                 "+ 1 Custo Operacional de R\$ ${_automaticCostValue.toStringAsFixed(2)}",
                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
               ),
             ),

          const SizedBox(height: 20),
          const Text(
            "Nota: O financeiro será gerado com todos os itens acima.",
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _genericStep({required IconData icon, required Color color, required String title, required String subtitle, required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])
      ]),
      const Divider(),
      Expanded(child: SingleChildScrollView(child: child)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Dialog(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));

    List<Widget> activeSteps = [];
    if (_hasMonthlyFee) activeSteps.add(_buildStepMonthly());
    
    activeSteps.add(_buildConfirmationStep());

    Widget currentWidget = activeSteps[_currentStep];
    bool isLastStep = _currentStep == activeSteps.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Aprovar Orçamento", style: TextStyle(fontSize: 16, color: Colors.grey)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
            ]),
            Expanded(child: currentWidget),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (isLastStep) {
                    _finish();
                  } else {
                    setState(() => _currentStep++);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text(isLastStep ? "FINALIZAR APROVAÇÃO" : "CONTINUAR"),
              ),
            )
          ],
        ),
      ),
    );
  }
}