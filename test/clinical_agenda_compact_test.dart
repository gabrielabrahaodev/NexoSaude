import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('compact agenda exposes 15h at screenshot height dark=$dark', (tester) async {
      AppColors.isDark = dark;
      addTearDown(() => AppColors.isDark = false);
      tester.view.physicalSize = const Size(1534, 727);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final monday = DateTime(2026, 11, 2);
      await tester.pumpWidget(MaterialApp(theme: ClinicalAgendaStyle.theme, home: Scaffold(body: Padding(
        padding: const EdgeInsets.only(top: 64, left: 286),
        child: ClinicalAgendaView(weekStart: monday, appointments: [AppointmentModel(id: 'a', clinicId: 'c', patientId: 'p', patientName: 'Paciente', procedure: 'Consulta', date: monday.add(const Duration(hours: 9)), durationMinutes: 30, status: 'Confirmado')],
          professionalSelector: const Text('Profissional'), onChangeWeek: (_) {}, onToday: () {}, onEmptySlot: (_, _) {}, onAppointment: (_) {}),
      ))));
      await tester.pump();
      expect(tester.getRect(find.text('15:00')).bottom, lessThanOrEqualTo(727));
      expect(tester.takeException(), isNull);
    });
  }
}
