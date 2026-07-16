import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import 'session_manager.dart'; // NECESSÁRIO PARA PEGAR O ID DA CLÍNICA

class ExpenseService {
  final CollectionReference _expenses = FirebaseFirestore.instance.collection('expenses');

  // Adicionar Despesa Única
  Future<void> addExpense(ExpenseModel expense) async {
    // Garante que o clinicId esteja preenchido
    final clinicId = SessionManager().currentClinicId;
    if (clinicId != null && expense.clinicId.isEmpty) {
      // Cria um novo mapa com o ID correto se estiver faltando
      Map<String, dynamic> data = expense.toMap();
      data['clinicId'] = clinicId;
      await _expenses.add(data);
    } else {
      await _expenses.add(expense.toMap());
    }
  }

  // --- CORREÇÃO AQUI: RECORRÊNCIA COM CLINIC ID ---
  Future<void> addRecurringExpense({
    required ExpenseModel baseExpense, 
    required int months, 
    required bool isDivision
  }) async {
    final String? clinicId = SessionManager().currentClinicId;
    if (clinicId == null) throw Exception("Clínica não selecionada");

    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    // Cálculo do valor
    double monthlyAmount = isDivision 
        ? (baseExpense.amount / months) 
        : baseExpense.amount;

    DateTime currentDueDate = baseExpense.dueDate;
    String recurrenceGroupId = DateTime.now().millisecondsSinceEpoch.toString();

    for (int i = 1; i <= months; i++) {
      DocumentReference docRef = _expenses.doc();
      
      Map<String, dynamic> data = baseExpense.toMap();
      
      // FORÇA OS DADOS CRUCIAIS EM CADA PARCELA
      data['clinicId'] = clinicId; // <--- O PULO DO GATO
      data['amount'] = monthlyAmount;
      data['dueDate'] = Timestamp.fromDate(currentDueDate);
      
      // Ajusta descrição (Ex: Aluguel 1/12)
      String suffix = "($i/$months)";
      data['description'] = "${baseExpense.description} $suffix";
      
      data['installmentNumber'] = "$i/$months";
      data['recurrenceId'] = recurrenceGroupId;
      data['status'] = 'pendente'; // Garante que nasce pendente

      batch.set(docRef, data);

      // Avança 1 mês
      currentDueDate = DateTime(currentDueDate.year, currentDueDate.month + 1, currentDueDate.day);
    }

    await batch.commit();
  }

  // Marcar como Paga
  Future<void> markAsPaid(String id, DateTime paidDate) async {
    await _expenses.doc(id).update({
      'status': 'pago',
      'paidDate': Timestamp.fromDate(paidDate),
    });
  }
  
  // Editar Despesa
  Future<void> updateExpense(String id, ExpenseModel expense) async {
     await _expenses.doc(id).update(expense.toMap());
  }

  // Excluir Despesa
  Future<void> deleteExpense(String id) async {
    await _expenses.doc(id).delete();
  }

  // Listar por Mês (Usado na tela de Contas a Pagar)
  Stream<List<ExpenseModel>> getByMonth(DateTime month) {
    String? clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return const Stream.empty();

    DateTime start = DateTime(month.year, month.month, 1);
    DateTime end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _expenses
        .where('clinicId', isEqualTo: clinicId) // Filtra pela clínica
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }
}