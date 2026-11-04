import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_model.dart';
import '../models/budget_model.dart'; 
import '../models/expense_model.dart'; // Importante: Agora lidamos com Despesas
import 'session_manager.dart';
import 'procedure_tags.dart';

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
    final db = FirebaseFirestore.instance;
    if (budget.clinicId != SessionManager().currentClinicId) throw StateError('Unidade alterada.');
    if (budget.items.length + receivables.length + payables.length + 2 > 450) throw StateError('Orçamento excede o limite de uma aprovação.');
    final catalog = await db.collection('procedures').where('clinicId', isEqualTo: budget.clinicId).get();
    final definitions = {for (final p in catalog.docs) p.id: procedureTagDefinition(p.data(), p.id)};
    await db.runTransaction((batch) async {
      final current = await batch.get(_budgets.doc(budget.id));
      if (current.data()?['clinicId'] != budget.clinicId || current.data()?['patientId'] != budget.patientId) throw StateError('Orçamento fora do contexto.');
      if (['aprovado', 'approved'].contains('${current.data()?['status']}'.toLowerCase())) return;
      if (['cancelado','cancelled','recusado','rejected','expirado'].contains('${current.data()?['status']}'.toLowerCase())) throw StateError('Orçamento indisponível para aprovação.');
      // Reject stale item/total snapshots before generating receivables.
      if (BudgetModel.fromMap(budget.id, current.data()!).total != budget.total || tagSnapshotKey(current.data()?['items']) != tagSnapshotKey(budget.items)) throw StateError('Orçamento alterado. Reabra a aprovação.');
      final patient = await batch.get(db.collection('patients').doc(budget.patientId));
      if (patient.data()?['clinicId'] != budget.clinicId) throw StateError('Paciente de outra unidade.');

    // --- CORREÇÃO PONTO 2: CÁLCULO DO VALOR REAL DO CONTRATO ---
    // Soma a entrada + todas as mensalidades geradas
    double realContractValue = receivables.fold(0, (sum, item) => sum + item.amount);

    // 1. Cria o Plano de Tratamento
    DocumentReference planRef = _plans.doc('budget_${budget.id}');
    
    List<Map<String, dynamic>> planItems = budget.items.map((item) {
      return {
        for (final key in [
          'region', 'teeth', 'tooth', 'toothNumber', 'quantity',
          'unitPrice', 'discountAmount', 'discountPercent',
        ])
          if (item.containsKey(key)) key: item[key],
        'procedureId': item['id'],
        'name': item['name'],
        'price': item['price'],
        'status': 'pendente',
        'date': Timestamp.now(),
      };
    }).toList();

    for (var i = 0; i < budget.items.length; i++) {
      final line = Map<String, dynamic>.from(budget.items[i]);
      final tagId = patientTagId(budget.id, i);
      planItems[i]['procedureTagId'] = tagId;
      batch.set(db.collection('patients').doc(budget.patientId).collection('procedure_tags').doc(tagId), {
        ...patientProcedureTag(clinicId: budget.clinicId, patientId: budget.patientId, patientName: budget.patientName, budgetId: budget.id, planId: planRef.id, index: i, line: line, definition: definitions['${line['id']}'] ?? {}),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
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

    });
  }

  // Adicione este método à sua classe existente
  @Deprecated('Use approveBudgetWithFinancials para gerar plano e Tags atomicamente')
  Future<String> createFromBudget(BudgetModel budget) async {
    throw UnsupportedError('Use a aprovação de orçamento para gerar plano e Tags.');
  }
}
