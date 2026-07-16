import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_model.dart';
import '../models/expense_model.dart';
import 'session_manager.dart'; // Import necessário para o filtro

class PatientFinancialOracle {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>> getPatientFinancialHealth(String patientId) {
    // 1. Aplicamos o applyFilter para garantir que a consulta seja "segura"
    // para as regras do Firebase, injetando o clinicId da sessão.
    
    Query<Map<String, dynamic>> receivablesQuery = _db
        .collection('financial')
        .where('patientId', isEqualTo: patientId);
    
    // Injeta automaticamente .where('clinicId', isEqualTo: ...)
    receivablesQuery = SessionManager().applyFilter(receivablesQuery);

    final receivablesStream = receivablesQuery.snapshots();

    return receivablesStream.asyncMap((receivablesSnap) async {
      // 2. Repetimos a lógica para a coleção de despesas (expenses)
      Query<Map<String, dynamic>> payablesQuery = _db
          .collection('expenses')
          .where('relatedPatientId', isEqualTo: patientId);
      
      payablesQuery = SessionManager().applyFilter(payablesQuery);

      final payablesSnap = await payablesQuery.get(); 

      final receivables = receivablesSnap.docs.map((d) => FinancialModel.fromMap(d.id, d.data())).toList();
      final payables = payablesSnap.docs.map((d) => ExpenseModel.fromMap(d.id, d.data())).toList();

      // --- LÓGICA DE CÁLCULO MANTIDA ---
      double totalContracted = receivables.fold(0, (sum, item) => sum + item.amount);
      double totalPaid = receivables.where((i) => i.isPaid).fold(0, (sum, item) => sum + item.amount);
      double totalPending = totalContracted - totalPaid;
      double totalCost = payables.fold(0, (sum, item) => sum + item.amount);
      
      double marginValue = totalContracted - totalCost;
      double marginPercent = totalContracted == 0 ? 0 : (marginValue / totalContracted) * 100;

      List<dynamic> timeline = [];
      timeline.addAll(receivables);
      timeline.addAll(payables);
      
      timeline.sort((a, b) {
        DateTime dateA = a is FinancialModel ? a.date : (a as ExpenseModel).dueDate;
        DateTime dateB = b is FinancialModel ? b.date : (b as ExpenseModel).dueDate;
        return dateA.compareTo(dateB);
      });

      return {
        'totalContracted': totalContracted,
        'totalPaid': totalPaid,
        'totalPending': totalPending,
        'totalCost': totalCost,
        'marginValue': marginValue,
        'marginPercent': marginPercent,
        'timeline': timeline,
      };
    });
  }
}