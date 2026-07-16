import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab_order.dart';

class LabService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createOrder(LabOrderModel order) async {
    await _db.collection('lab_orders').add(order.toMap());
  }

  Future<void> deleteOrder(String id) async {
    await _db.collection('lab_orders').doc(id).delete();
  }

  Stream<List<LabOrderModel>> getByPatient(String patientId) {
    return _db
        .collection('lab_orders')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LabOrderModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<LabOrderModel>> getByClinic(String clinicId) {
    return _db
        .collection('lab_orders')
        .where('clinicId', isEqualTo: clinicId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LabOrderModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> updateStatus(String id, String newStatus, Map<String, dynamic> additionalData) async {
    Map<String, dynamic> data = {'status': newStatus};
    data.addAll(additionalData);
    await _db.collection('lab_orders').doc(id).update(data);
  }

  Future<void> addInteraction(String orderId, LabInteraction interaction) async {
    await _db.collection('lab_orders').doc(orderId).update({
      'interactions': FieldValue.arrayUnion([interaction.toMap()])
    });
  }
}