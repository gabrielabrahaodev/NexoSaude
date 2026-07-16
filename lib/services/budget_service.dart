import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_model.dart';
import 'session_manager.dart';

class BudgetService {
  final CollectionReference<Map<String, dynamic>> _collection = 
      FirebaseFirestore.instance.collection('budgets');

  Future<void> add(BudgetModel budget) async {
    await _collection.add(budget.toMap());
  }

  Stream<List<BudgetModel>> getByPatient(String patientId) {
    Query<Map<String, dynamic>> query = _collection.where('patientId', isEqualTo: patientId);
    query = SessionManager().applyFilter(query);
    
    return query.orderBy('date', descending: true).snapshots().map((snapshot) => 
      snapshot.docs.map((doc) => BudgetModel.fromMap(doc.id, doc.data())).toList()
    );
  }
}