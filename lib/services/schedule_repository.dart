import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../models/psychology_schedule_model.dart';
import 'appointment_service.dart';

/// Visão unificada de leitura para agenda, sem fundir collections.
///
/// Mantém `appointments` (dental) e `psychology_schedules` (psy) separados
/// no Firestore, mas expõe um stream único para dashboards e relatórios.
class ScheduleItem {
  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final DateTime date;
  final String source; // 'dental' | 'psychology'

  const ScheduleItem({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.source,
  });
}

class ScheduleRepository {
  final AppointmentService _dental = AppointmentService();
  final CollectionReference<Map<String, dynamic>> _psy =
      FirebaseFirestore.instance.collection('psychology_schedules');

  Stream<List<ScheduleItem>> watchByClinic(
    String clinicId, {
    DateTime? start,
    DateTime? end,
  }) {
    final s = start ?? DateTime.now().subtract(const Duration(days: 30));
    final e = end ?? DateTime.now().add(const Duration(days: 90));

    final dentalStream = _dental.getByDateRange(clinicId, s, e);
    final psyStream = _psy
        .where('clinicId', isEqualTo: clinicId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                PsychologyScheduleModel.fromMap(d.id, d.data()))
            .toList());

    // Combina sem fundir escrita.
    Stream<List<ScheduleItem>> result = Stream.multi((controller) {
      List<AppointmentModel> dental = [];
      List<PsychologyScheduleModel> psy = [];

      void emit() {
        final all = <ScheduleItem>[
          for (final a in dental)
            ScheduleItem(
              id: a.id,
              clinicId: a.clinicId,
              patientId: a.patientId,
              patientName: a.patientName,
              date: a.date,
              source: 'dental',
            ),
          for (final p in psy)
            ScheduleItem(
              id: p.id,
              clinicId: p.clinicId,
              patientId: p.patientId,
              patientName: p.patientName,
              date: p.startDate,
              source: 'psychology',
            ),
        ]..sort((a, b) => a.date.compareTo(b.date));
        controller.add(all);
      }

      final sub1 = dentalStream.listen((v) {
        dental = v;
        emit();
      }, onError: controller.addError);
      final sub2 = psyStream.listen((v) {
        psy = v;
        emit();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await sub1.cancel();
        await sub2.cancel();
      };
    });

    return result;
  }
}
