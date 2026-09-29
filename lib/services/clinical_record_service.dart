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

  /// Registro puro de cobrança via WhatsApp p/ o prontuário (testado).
  /// Grava o texto exato enviado + quem enviou + quando.
  static Map<String, dynamic> whatsappChargeRecord({
    required String clinicId,
    required String patientId,
    required String patientName,
    required String message,
    required String operatorName,
    required DateTime at,
  }) {
    final when =
        "${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}";
    return {
      'clinicId': clinicId,
      'treatmentId': null,
      'patientId': patientId,
      'patientName': patientName,
      'procedureName': 'Cobrança via WhatsApp',
      'description': 'Enviado em $when por $operatorName: $message',
      'dentistName': operatorName,
      'date': Timestamp.fromDate(at),
    };
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}