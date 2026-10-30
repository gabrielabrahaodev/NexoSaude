import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_view.dart';

void main() {
  final monday = DateTime(2026, 10, 26);
  AppointmentModel appt(
    String id,
    int hour,
    int minute, {
    int duration = 30,
    String status = 'Confirmado',
  }) => AppointmentModel(
    id: id,
    patientId: id,
    patientName: 'Paciente $id',
    date: monday.add(Duration(hours: hour, minutes: minute)),
    procedure: 'Consulta inicial',
    clinicId: 'clinic-a',
    durationMinutes: duration,
    status: status,
  );
  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('agenda sem overflow em $width e seleção de dia/consulta', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      DateTime? selectedDay;
      await tester.pumpWidget(
        MaterialApp(
          theme: ClinicalAgendaStyle.theme,
          home: Scaffold(
            body: ClinicalAgendaView(
              weekStart: monday,
              appointments: [appt('A', 11, 0), appt('B', 13, 30, duration: 60)],
              professionalSelector: const Text('Profissional da clínica'),
              onSelectedDay: (day) => selectedDay = day,
              onChangeWeek: (_) {},
              onToday: () {},
              onEmptySlot: (_, time) => selected = time,
              onAppointment: (a) => selected = a.id,
            ),
          ),
        ),
      );
      await tester.tap(find.text('SEG'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('2 agendamentos no dia'), findsOneWidget);
      expect(selectedDay, monday);
      await tester.tap(find.text('+ Disponível').first);
      expect(selected, '08:30');
      await tester.scrollUntilVisible(
        find.text('Paciente A'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Paciente A'));
      expect(selected, 'A');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'grade preserva encaixes, cancelados, bloqueios e horários extras',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ClinicalAgendaStyle.theme,
          home: Scaffold(
            body: ClinicalAgendaView(
              weekStart: monday,
              appointments: [
                appt('A', 7, 0),
                appt('B', 7, 0),
                appt('C', 8, 0, status: 'Cancelado'),
                appt('D', 9, 0, status: 'Bloqueado'),
              ],
              professionalSelector: const Text('Profissional'),
              onChangeWeek: (_) {},
              onToday: () {},
              onEmptySlot: (_, time) {},
              onAppointment: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Paciente A'), findsOneWidget);
      expect(find.text('Paciente B'), findsOneWidget);
      expect(find.text('Paciente C'), findsOneWidget);
      expect(find.text('Bloqueado'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('continuação de consulta não é oferecida como livre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ClinicalAgendaStyle.theme,
        home: Scaffold(
          body: ClinicalAgendaView(
            weekStart: monday,
            appointments: [
              appt('Longa', 8, 30, duration: 90),
              appt('Cancelada', 10, 0, status: 'Cancelado'),
            ],
            professionalSelector: const Text('Profissional'),
            onChangeWeek: (_) {},
            onToday: () {},
            onEmptySlot: (_, time) {},
            onAppointment: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('SEG'));
    await tester.pump();
    expect(find.text('1 agendamentos no dia'), findsOneWidget);
    expect(find.text('Paciente Longa'), findsOneWidget);
    expect(find.text('09:00'), findsNothing);
    expect(find.text('09:30'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
