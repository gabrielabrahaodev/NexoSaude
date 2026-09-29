import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import 'portal_mirror.dart';

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
  // Com dentistId, considera só os slots DESSE profissional.
  Future<List<String>> getBusySlots(String clinicId, DateTime date,
      {String? excludeId, String? dentistId}) async {
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
      if (dentistId != null &&
          dentistId.isNotEmpty &&
          '${doc['dentistId'] ?? ''}' != dentistId) continue;

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
    final ref = _collection.doc();
    await ref.set(map);
    // Espelho (delta, sem scan): a sessão entra com os dados em mãos.
    await PortalMirrorSync.upsertSession(
      patientId: appointment.patientId,
      session: {
        'id': ref.id,
        'date': appointment.date,
        'professional': '',
        'dentistId': appointment.dentistId ?? '',
        'status': appointment.status,
      },
    );
    await PortalMirrorSync.occupySlot(
      clinicId: appointment.clinicId,
      dentistId: appointment.dentistId ?? '',
      date: appointment.date,
    );
  }

  Future<void> update(AppointmentModel appointment) async {
    var map = appointment.toMap();
    final old = (await _collection.doc(appointment.id).get()).data()
        as Map<String, dynamic>?;
    // Em update, removemos campos que não queremos sobrescrever acidentalmente, ou enviamos tudo
    await _collection.doc(appointment.id).update(map);
    // Troca de data/dentista: libera o slot antigo, ocupa o novo.
    final oldDate = (old?['date'] as Timestamp?)?.toDate();
    final oldDentist = '${old?['dentistId'] ?? ''}';
    if (oldDate != null &&
        (oldDate != appointment.date ||
            oldDentist != (appointment.dentistId ?? ''))) {
      await PortalMirrorSync.releaseSlot(
        clinicId: appointment.clinicId,
        dentistId: oldDentist,
        date: oldDate,
      );
    }
    await PortalMirrorSync.occupySlot(
      clinicId: appointment.clinicId,
      dentistId: appointment.dentistId ?? '',
      date: appointment.date,
    );
    await PortalMirrorSync.upsertSession(
      patientId: appointment.patientId,
      session: {
        'id': appointment.id,
        'date': appointment.date,
        'professional': '',
        'dentistId': appointment.dentistId ?? '',
        'status': appointment.status,
      },
    );
  }
  
  Future<void> cancel(String id) async {
    final old =
        (await _collection.doc(id).get()).data() as Map<String, dynamic>?;
    await _collection.doc(id).update({'status': 'Cancelado'});
    final oldDate = (old?['date'] as Timestamp?)?.toDate();
    if (oldDate != null) {
      await PortalMirrorSync.releaseSlot(
        clinicId: '${old?['clinicId'] ?? ''}',
        dentistId: '${old?['dentistId'] ?? ''}',
        date: oldDate,
      );
    }
    final pid = '${old?['patientId'] ?? ''}';
    if (pid.isNotEmpty) {
      await PortalMirrorSync.removeSession(patientId: pid, sessionId: id);
    }
  }
}