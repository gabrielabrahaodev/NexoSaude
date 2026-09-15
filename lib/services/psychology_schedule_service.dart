import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odonto_controle/services/session_manager.dart';
import '../models/psychology_schedule_model.dart';

class PsychologyScheduleService {
  final CollectionReference<Map<String, dynamic>> _schedules = 
      FirebaseFirestore.instance.collection('psychology_schedules');

  Stream<QuerySnapshot> getSchedulesStream() {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return const Stream.empty();
    return _schedules
        .where('clinicId', isEqualTo: clinicId)
        .where('status', isEqualTo: 'active')
        .orderBy('startDate')
        .snapshots();
  }

  Future<void> add(PsychologyScheduleModel schedule) async {
    await _schedules.add(schedule.toMap());
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _schedules.doc(id).update(data);
  }

  Future<void> delete(String id) async {
    await _schedules.doc(id).update({'status': 'cancelled'});
  }

  Future<PsychologyScheduleModel?> getById(String id) async {
    final doc = await _schedules.doc(id).get();
    if (!doc.exists) return null;
    return PsychologyScheduleModel.fromMap(doc.id, doc.data()!);
  }
}