import '../models/appointment_model.dart';

/// A slot is busy whenever any part of its 30-minute interval overlaps a visit.
/// Unassigned legacy appointments conservatively occupy the selected agenda.
Map<String, int> agendaSlotOccupancy(
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
  final busy = <String, int>{};
  for (var minute = 0; minute < 24 * 60; minute += 30) {
    final slotStart = start.add(Duration(minutes: minute));
    final slotEnd = slotStart.add(const Duration(minutes: 30));
    final overlapping = visits.where((a) => a.date.isBefore(slotEnd) &&
        a.date.add(Duration(minutes: a.durationMinutes > 0 ? a.durationMinutes : 30)).isAfter(slotStart)).toList();
    final points = [slotStart, ...overlapping.map((a) => a.date).where((d) => d.isAfter(slotStart))];
    var peak = 0;
    for (final point in points) {
      final count = overlapping.where((a) => !a.date.isAfter(point) &&
          a.date.add(Duration(minutes: a.durationMinutes > 0 ? a.durationMinutes : 30)).isAfter(point)).length;
      if (count > peak) peak = count;
    }
    if (overlapping.any((a) => a.status == 'Bloqueado' || a.patientId == 'BLOCKED_SLOT')) {
      peak = 2;
    }
    if (peak > 0) {
      busy['${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}'] = peak;
    }
  }
  return busy;
}

/// Blocos de meia hora tocados pelo intervalo, inclusive em virada de dia.
List<DateTime> agendaIntervalSlots(DateTime start, int durationMinutes) {
  if (durationMinutes <= 0) {
    throw ArgumentError.value(durationMinutes, 'durationMinutes');
  }
  final end = start.add(Duration(minutes: durationMinutes));
  final first = DateTime(
    start.year,
    start.month,
    start.day,
    start.hour,
    (start.minute ~/ 30) * 30,
  );
  return [
    for (
      var slot = first;
      slot.isBefore(end);
      slot = slot.add(const Duration(minutes: 30))
    )
      slot,
  ];
}

List<String> busyAgendaSlots(Iterable<AppointmentModel> appointments, {
  required String clinicId, required DateTime day, String? dentistId,
  String? excludeId, int capacity = 1,
}) => agendaSlotOccupancy(appointments, clinicId: clinicId, day: day,
    dentistId: dentistId, excludeId: excludeId).entries
    .where((entry) => entry.value >= capacity).map((entry) => entry.key).toList();
