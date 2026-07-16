import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';

class ClinicalRecordService {
  // CORREÇÃO: Tipagem explícita <Map<String, dynamic>> resolve o conflito com applyFilter
  final CollectionReference<Map<String, dynamic>> _collection = 
      FirebaseFirestore.instance.collection('clinical_records');

  Stream<QuerySnapshot> getByPatient(String patientId) {
    // Agora 'query' já nasce como Query<Map<String, dynamic>>
    Query<Map<String, dynamic>> query = _collection.where('patientId', isEqualTo: patientId);
    
    // O SessionManager aceita porque os tipos batem
    query = SessionManager().applyFilter(query);
    
    return query.orderBy('date', descending: true).snapshots();
  }

  Future<void> add(Map<String, dynamic> data) async {
    await _collection.add(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _collection.doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}