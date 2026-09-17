import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_model.dart';
import '../models/budget_model.dart'; 
import '../models/expense_model.dart'; // Importante: Agora lidamos com Despesas
import 'session_manager.dart';

class TreatmentService {
  final CollectionReference<Map<String, dynamic>> _plans = 
      FirebaseFirestore.instance.collection('treatment_plans');
  
  final CollectionReference<Map<String, dynamic>> _financial = 
      FirebaseFirestore.instance.collection('financial');

  final CollectionReference<Map<String, dynamic>> _expenses = 
      FirebaseFirestore.instance.collection('expenses');

  final CollectionReference<Map<String, dynamic>> _budgets = 
      FirebaseFirestore.instance.collection('budgets');

  // --- LEITURA (filtrada pela clínica da sessão) ---
  Stream<QuerySnapshot> getPlansStream(String patientId) {
    return SessionManager()
        .applyFilter(_plans.where('patientId', isEqualTo: patientId))
        .snapshots();
  }

  Future<void> closePlan(String planId) async {
    await _plans.doc(planId).update({'status': 'completed'});
  }

  // --- O "CÉREBRO" DA APROVAÇÃO (ATUALIZADO FASE 2) ---
  
  // ... (início da classe igual)

  Future<void> approveBudgetWithFinancials({
    required BudgetModel budget,
    required List<FinancialModel> receivables, // Lista completa vinda do Wizard
    required List<ExpenseModel> payables,
  }) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // --- CORREÇÃO PONTO 2: CÁLCULO DO VALOR REAL DO CONTRATO ---
    // Soma a entrada + todas as mensalidades geradas
    double realContractValue = receivables.fold(0, (sum, item) => sum + item.amount);

    // 1. Cria o Plano de Tratamento
    DocumentReference planRef = _plans.doc();
    
    List<Map<String, dynamic>> planItems = budget.items.map((item) {
      return {
        'procedureId': item['id'],
        'name': item['name'],
        'price': item['price'],
        'status': 'pendente',
        'date': Timestamp.now(),
      };
    }).toList();

    batch.set(planRef, {
      'clinicId': budget.clinicId,
      'patientId': budget.patientId,
      'patientName': budget.patientName,
      'totalValue': realContractValue, // <--- USAMOS O VALOR CALCULADO, NÃO O DO ORÇAMENTO
      'startDate': Timestamp.now(),
      'status': 'active',
      'items': planItems,
      'budgetId': budget.id,
      'type': SessionManager().clinicType,
    });

    // 2. Atualiza Orçamento
    batch.update(_budgets.doc(budget.id), {
      'status': 'Aprovado',
      'relatedPlanId': planRef.id
    });

    // 3. Receitas (Contas a Receber)
    for (var fin in receivables) {
      DocumentReference finRef = _financial.doc();
      Map<String, dynamic> data = fin.toMap();
      data['planId'] = planRef.id; // Vincula ao plano
      batch.set(finRef, data);
    }

    // 4. Despesas (Contas a Pagar) - CORRIGIDO
    for (var exp in payables) {
      DocumentReference expRef = _expenses.doc();
      Map<String, dynamic> data = exp.toMap();
      
      // VINCULAÇÃO CRUCIAL
      data['relatedPatientId'] = budget.patientId;
      data['relatedPlanId'] = planRef.id; // <--- Agora sabemos de qual plano é esse custo
      
      batch.set(expRef, data);
    }

    await batch.commit();
  }

  // Adicione este método à sua classe existente
  Future<String> createFromBudget(BudgetModel budget) async {
    final clinicId = SessionManager().currentClinicId;
    
    DocumentReference ref = await _plans.add({
      'clinicId': clinicId,
      'patientId': budget.patientId,
      'patientName': budget.patientName,
      'originBudgetId': budget.id,
      'status': 'active', // Em andamento
      'startDate': FieldValue.serverTimestamp(),
      'totalValue': budget.total,
      'items': budget.items, // Lista de procedimentos
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }
}