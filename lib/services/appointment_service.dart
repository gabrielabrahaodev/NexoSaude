import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('appointments');

  // NOVO: Busca por intervalo de datas (Para a Agenda Semanal)
  Stream<List<AppointmentModel>> getByDateRange(String clinicId, DateTime start, DateTime end) {
    return _collection
        .where('clinicId', isEqualTo: clinicId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // NOVO: Verifica disponibilidade (Para o Formulário)
  Future<List<String>> getBusySlots(String clinicId, DateTime date, {String? excludeId}) async {
    DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59);

    var snapshot = await _collection
        .where('clinicId', isEqualTo: clinicId)
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThan: endOfDay)
        .get();

    List<String> busy = [];
    for (var doc in snapshot.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      if ('${doc['status']}'.toLowerCase() == 'cancelado') continue;

      DateTime d = (doc['date'] as Timestamp).toDate();
      int duration = doc['durationMinutes'] ?? 30;
      int slotsOccupied = (duration / 30).ceil();

      for (int i = 0; i < slotsOccupied; i++) {
        DateTime slotTime = d.add(Duration(minutes: 30 * i));
        busy.add("${slotTime.hour.toString().padLeft(2,'0')}:${slotTime.minute.toString().padLeft(2,'0')}");
      }
    }
    return busy;
  }

  Future<void> add(AppointmentModel appointment) async {
    // Convertemos o model para mapa, removendo o ID que será gerado
    var map = appointment.toMap(); 
    await _collection.add(map);
  }

  Future<void> update(AppointmentModel appointment) async {
    var map = appointment.toMap();
    // Em update, removemos campos que não queremos sobrescrever acidentalmente, ou enviamos tudo
    await _collection.doc(appointment.id).update(map);
  }
  
  Future<void> cancel(String id) async {
    await _collection.doc(id).update({'status': 'Cancelado'});
  }
}