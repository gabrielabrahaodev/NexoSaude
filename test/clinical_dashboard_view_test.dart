import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:odonto_controle/screens/dashboard/clinical_dashboard_view.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  for (final dark in [true, false]) {
    for (final width in [320.0, 390.0, 768.0, 1040.0, 1440.0]) {
      testWidgets('dashboard $width dark=$dark actions and layout', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final navigation = <int>[];
        var created = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          home: Scaffold(body: ClinicalDashboardView(
            monthLabel: 'Novembro 2026', toReceive: 520, overdue: 670,
            overdueCount: 4, todayCount: 2, oldOverdueCount: 4,
            unconfirmedCount: 1, debtorsTodayCount: 1,
            upcoming: [{'name': 'Paciente de teste com nome completo extenso', 'title': 'Procedimento registrado', 'due': DateTime(2026, 10, 5), 'amount': 160}],
            birthdays: const [], now: DateTime(2026, 11, 2),
            onNavigate: navigation.add, onNewAppointment: () => created++,
          )),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Novo agendamento'));
        expect(created, 1);
        await tester.ensureVisible(find.text('Detalhes'));
        await tester.tap(find.text('Detalhes'));
        expect(navigation.last, 5);
        await tester.ensureVisible(find.text('Ver em Cobranças  ›'));
        await tester.tap(find.text('Ver em Cobranças  ›'));
        expect(navigation.last, 7);
        await tester.ensureVisible(find.text('Consultar agenda'));
        await tester.tap(find.text('Consultar agenda'));
        expect(navigation.last, 1);
        expect(find.text('Ocupação não disponível'), findsOneWidget);
        await tester.ensureVisible(find.text('Ver em Pacientes'));
        await tester.tap(find.text('Ver em Pacientes'));
        expect(navigation.last, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
