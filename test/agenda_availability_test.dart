import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/services/agenda_availability.dart';

void main() {
  final day = DateTime(2026, 11, 3);
  AppointmentModel visit(String id, int hour, int minute, {int duration = 30,
      String clinic = 'clinic', String? dentist = 'dentist', String status = 'Confirmado'}) =>
      AppointmentModel(id: id, patientId: 'p', patientName: 'Paciente',
          date: DateTime(day.year, day.month, day.day, hour, minute),
          status: status, procedure: 'Consulta', clinicId: clinic,
          dentistId: dentist, durationMinutes: duration);
  List<String> busy(List<AppointmentModel> visits, {String? exclude}) =>
      busyAgendaSlots(visits, clinicId: 'clinic', day: day,
          dentistId: 'dentist', excludeId: exclude);

  test('whole duration occupies slots, end boundary remains free', () {
    expect(busy([visit('a', 9, 0, duration: 90)]), ['09:00', '09:30', '10:00']);
  });
  test('off-grid appointments block every overlapping half hour', () {
    expect(busy([visit('a', 9, 15, duration: 50)]), ['09:00', '09:30', '10:00']);
  });
  test('clinic and professional scoped; legacy unassigned remains busy', () {
    expect(busy([visit('a', 9, 0, clinic: 'other'), visit('b', 10, 0, dentist: 'other'),
      visit('legacy', 11, 0, dentist: null)]), ['11:00']);
  });
  test('cancelled slot is freed; finalized slot remains occupied', () {
    expect(busy([visit('a', 9, 0, status: ' Cancelado '),
      visit('b', 10, 0, status: 'Finalizado')]), ['10:00']);
  });
  test('editing ignores only itself, keeps another visit at same time', () {
    expect(busy([visit('self', 9, 0)], exclude: 'self'), isEmpty);
    expect(busy([visit('self', 9, 0), visit('other', 9, 0)], exclude: 'self'), ['09:00']);
  });
  test('overnight and malformed zero duration do not leave false free slots', () {
    final overnight = AppointmentModel(id:'night',patientId:'p',patientName:'Paciente',
      date:DateTime(2026,11,2,23,45),status:'Confirmado',procedure:'Consulta',
      clinicId:'clinic',dentistId:'dentist',durationMinutes:60);
    expect(busy([overnight,visit('zero',9,0,duration:0)]), ['00:00','00:30','09:00']);
  });
}
