import '../models/appointment_model.dart';

/// A slot is busy whenever any part of its 30-minute interval overlaps a visit.
/// Unassigned legacy appointments conservatively occupy the selected agenda.
List<String> busyAgendaSlots(
  Iterable<AppointmentModel> appointments, {
  required String clinicId,
  required DateTime day,
  String? dentistId,
  String? excludeId,
}) {
  final start = DateTime(day.year, day.month, day.day);
  final visits = appointments.where((a) =>
      a.clinicId == clinicId &&
      a.id != excludeId &&
      a.status.trim().toLowerCase() != 'cancelado' &&
      (dentistId == null || dentistId.isEmpty ||
          (a.dentistId ?? '').isEmpty || a.dentistId == dentistId));
  final busy = <String>[];
  for (var minute = 0; minute < 24 * 60; minute += 30) {
    final slotStart = start.add(Duration(minutes: minute));
    final slotEnd = slotStart.add(const Duration(minutes: 30));
    if (visits.any((a) => a.date.isBefore(slotEnd) &&
        a.date.add(Duration(minutes: a.durationMinutes > 0 ? a.durationMinutes : 30)).isAfter(slotStart))) {
      busy.add('${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}');
    }
  }
  return busy;
}
