import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/user_model.dart';
import 'package:odonto_controle/screens/agenda/agenda_cell_factory.dart';
import 'package:odonto_controle/screens/agenda/agenda_form_screen.dart';
import 'package:odonto_controle/screens/agenda/agenda_professional_selector.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_brand.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_view.dart';
import 'package:odonto_controle/screens/psychology/psychology_schedule_form_screen.dart';
import 'package:odonto_controle/services/clinic_capabilities.dart';

void main() {
  final users = [
    UserModel(id: 'o', name: 'Ana', email: '', role: 'owner'),
    UserModel(id: 'd', name: 'Bruno', email: '', role: 'dentista'),
    UserModel(id: 'p', name: 'Clara', email: '', role: 'psicologo'),
  ];
  testWidgets('seletor denso comporta nome e contagem em 32px', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: ClinicalAgendaStyle.theme,
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(
        width: 420, height: 32,
        child: AgendaProfessionalSelector(professionals: users, selectedId: 'd',
          onChanged: (_) {}, onRetry: () {}, appointmentCount: 4),
      ))),
    ));
    await tester.pump();
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Dentista • 4 consultas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('seletor funcional e marca sem overflow em $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 'o';
      await tester.pumpWidget(
        MaterialApp(
          theme: ClinicalAgendaStyle.theme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: ClinicalAgendaBrand(),
                  ),
                  AgendaProfessionalSelector(
                    professionals: users,
                    selectedId: selected,
                    onChanged: (id) => setState(() => selected = id!),
                    onRetry: () {},
                    appointmentCount: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('agenda-professional')));
      await tester.pumpAndSettle();
      expect(find.text('Ana — Dono da clínica'), findsOneWidget);
      expect(find.text('Bruno — Dentista'), findsOneWidget);
      await tester.tap(find.text('Clara — Psicólogo'));
      await tester.pumpAndSettle();
      expect(selected, 'p');
      expect(find.text('Psicólogo • 4 consultas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('erro/ausência são explícitos e permitem tentar novamente', (
    tester,
  ) async {
    var retries = 0;
    Widget view({bool loading = false, String? error}) => MaterialApp(
      theme: ClinicalAgendaStyle.theme,
      home: Scaffold(
        body: AgendaProfessionalSelector(
          professionals: [],
          selectedId: null,
          onChanged: (_) {},
          onRetry: () => retries++,
          loading: loading,
          error: error,
        ),
      ),
    );
    await tester.pumpWidget(view(loading: true));
    expect(find.text('Carregando profissionais…'), findsOneWidget);
    await tester.pumpWidget(view(error: 'permission-denied'));
    await tester.tap(find.byTooltip('Tentar novamente'));
    expect(retries, 1);
    await tester.pumpWidget(view());
    expect(
      find.text('Nenhum profissional ativo vinculado à clínica.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agenda-professional')), findsNothing);
  });
  test('horário dental preserva data, hora e UID selecionados', () {
    final form =
        AgendaCellFactory.formForSlot(
              capabilities: const ClinicCapabilities('dental'),
              date: DateTime(2026, 10, 30),
              time: '13:30',
              selectedDentistId: 'dentista',
              fullWeekdayName: (_) => 'Sexta',
            )
            as AgendaFormScreen;
    expect(form.initialData!['dentistId'], 'dentista');
    expect(
      (form.initialData!['date'] as Timestamp).toDate(),
      DateTime(2026, 10, 30, 13, 30),
    );
  });
  test(
    'horário de psicologia preserva profissional, data e dia inclusive domingo',
    () {
      final form =
          AgendaCellFactory.formForSlot(
                capabilities: const ClinicCapabilities('psychology'),
                date: DateTime(2026, 11, 1),
                time: '09:30',
                selectedDentistId: 'psicologo',
                fullWeekdayName: (_) => 'Domingo',
              )
              as PsychologyScheduleFormScreen;
      expect(form.preSelectedProfessionalId, 'psicologo');
      expect(form.preSelectedDayOfWeek, 'Domingo');
      expect(form.preSelectedDate, DateTime(2026, 11, 1));
      expect(form.preSelectedTime, '09:30');
    },
  );
}
