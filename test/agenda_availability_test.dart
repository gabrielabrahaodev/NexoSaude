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

  test('remarcação verifica também o segundo bloco e horários fora da grade', () {
    final requested = agendaIntervalSlots(DateTime(2026, 11, 3, 10), 60);
    expect(requested, [DateTime(2026, 11, 3, 10), DateTime(2026, 11, 3, 10, 30)]);
    final occupied = busy([visit('occupied', 10, 30)]);
    expect(requested.any((s) => occupied.contains('${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}')), isTrue);
    expect(agendaIntervalSlots(DateTime(2026, 11, 3, 10, 15), 30), requested);
  });
  test('intervalo preserva virada de dia e rejeita duração inválida', () {
    expect(agendaIntervalSlots(DateTime(2026, 11, 3, 23, 45), 30),
        [DateTime(2026, 11, 3, 23, 30), DateTime(2026, 11, 4)]);
    expect(() => agendaIntervalSlots(day, 0), throwsArgumentError);
  });

  test('encaixe permite uma ocupação e bloqueia duas, excluindo a própria edição', () {
    final visits = [visit('one',9,0,duration:60),visit('two',9,30)];
    expect(busyAgendaSlots(visits,clinicId:'clinic',day:day,dentistId:'dentist',capacity:2), ['09:30']);
    expect(busyAgendaSlots(visits,clinicId:'clinic',day:day,dentistId:'dentist',capacity:2,excludeId:'one'), isEmpty);
    expect(agendaSlotOccupancy(visits,clinicId:'clinic',day:day,dentistId:'dentist')['09:00'],1);
  });
  test('duas consultas consecutivas dentro da fatia não contam como simultâneas', () {
    expect(busyAgendaSlots([visit('a',9,0,duration:15),visit('b',9,15,duration:15)],
      clinicId:'clinic',day:day,dentistId:'dentist',capacity:2), isEmpty);
    expect(busyAgendaSlots([visit('a',9,15,duration:30),visit('b',9,30)],
      clinicId:'clinic',day:day,dentistId:'dentist',capacity:2), ['09:30']);
  });
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
