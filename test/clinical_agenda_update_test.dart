import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('updated toolbar search preserves occupancy and month picker dark=$dark', (tester) async {
      AppColors.isDark = dark;
      addTearDown(() => AppColors.isDark = false);
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final monday = DateTime(2026, 11, 2);
      await tester.pumpWidget(MaterialApp(theme: ClinicalAgendaStyle.theme, home: Scaffold(body: ClinicalAgendaView(
        weekStart: monday, appointments: [AppointmentModel(id: 'a', clinicId: 'c', patientId: 'p', patientName: 'Ana', procedure: 'Consulta', date: monday.add(const Duration(hours: 9)), durationMinutes: 60, status: 'Confirmado')],
        professionalSelector: const Text('Profissional real'), onChangeWeek: (_) {}, onToday: () {}, onEmptySlot: (_, _) {}, onAppointment: (_) {},
      ))));
      expect(find.text('SÁB'), findsOneWidget);
      expect(find.text('DOM'), findsNothing);
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pump();
      expect(find.text('Ana'), findsNothing);
      await tester.tap(find.text('SEG'));
      await tester.pump();
      expect(find.text('+ Disponível'), findsNothing);
      await tester.tap(find.text('Mês'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Sunday appointments remain visible dark=$dark', (tester) async {
      AppColors.isDark = dark;
      addTearDown(() => AppColors.isDark = false);
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final monday = DateTime(2026, 11, 2);
      await tester.pumpWidget(MaterialApp(theme: ClinicalAgendaStyle.theme, home: Scaffold(body: ClinicalAgendaView(
        weekStart: monday, appointments: [AppointmentModel(id: 'a', clinicId: 'c', patientId: 'p', patientName: 'Domingo', procedure: 'Consulta', date: monday.add(const Duration(days: 6, hours: 9)), durationMinutes: 30, status: 'Confirmado')],
        professionalSelector: const Text('Profissional'), onChangeWeek: (_) {}, onToday: () {}, onEmptySlot: (_, _) {}, onAppointment: (_) {},
      ))));
      expect(find.text('DOM'), findsOneWidget);
      expect(find.text('Domingo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
