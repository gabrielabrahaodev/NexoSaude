import 'package:odonto_controle/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_view.dart';
import 'package:odonto_controle/screens/care/clinical_care_view.dart';
import 'package:odonto_controle/services/care_day.dart';

void main() {
  for (final dark in [false, true]) {
    group(dark ? 'modo escuro' : 'modo claro', () {
      setUp(() => AppColors.isDark = dark);
      tearDown(() => AppColors.isDark = false);
      final date = DateTime(2026, 10, 30);
      AppointmentModel a(
        String id, {
        String status = 'Aguardando Confirmação',
      }) => AppointmentModel(
        id: id,
        patientId: id,
        patientName: 'Paciente $id',
        clinicId: 'c',
        procedure: 'Procedimento / sessão',
        date: date.add(const Duration(hours: 13, minutes: 30)),
        status: status,
        scheduleId: 's',
        durationMinutes: 60,
      );
      for (final psychology in [false, true]) {
        for (final width in [
          320.0,
          360.0,
          390.0,
          430.0,
          768.0,
          1024.0,
          1440.0,
        ]) {
          testWidgets(
            'Meu dia ${psychology ? 'psico' : 'odonto'} $width: seleção, filtros e confirmação',
            (tester) async {
              tester.view.physicalSize = Size(width, 1000);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              String? opened;
              final selected = <String>{};
              var confirmations = 0, filters = 0;
              await tester.pumpWidget(
                MaterialApp(
                  theme: ClinicalAgendaStyle.theme,
                  home: Scaffold(
                    body: StatefulBuilder(
                      builder: (context, setState) => ClinicalCareDayView(
                        date: date,
                        clinicName: 'Clínica de teste',
                        psychology: psychology,
                        appointments: [
                          a('A'),
                          a('B', status: 'Em Atendimento'),
                        ],
                        professionals: const {},
                        paidToday: const {},
                        selected: selected,
                        confirming: false,
                        contractKinds: const {'s': 'package'},
                        onSelect: (id, value) => setState(() {
                          if (value) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                        onOpen: (value) => opened = value.id,
                        onConfirm: () => confirmations++,
                        onFilters: () => filters++,
                        onNew: () {},
                        panel: const Text('Ficha selecionada'),
                      ),
                    ),
                  ),
                ),
              );
              expect(find.text('1 em andamento'), findsOneWidget);
              await tester.tap(find.text('Filtros'));
              expect(filters, 1);
              await tester.tap(find.byType(Checkbox).first);
              await tester.pump();
              await tester.tap(find.text('Confirmar presença (1)'));
              expect(confirmations, 1);
              await tester.tap(find.text('Paciente A'));
              expect(opened, 'A');
              expect(tester.takeException(), isNull);
            },
          );
          testWidgets(
            'Ficha ${psychology ? 'psico' : 'odonto'} $width: salvar difere de finalizar',
            (tester) async {
              tester.view.physicalSize = Size(width, 1000);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final controller = TextEditingController();
              addTearDown(controller.dispose);
              var saves = 0, finishes = 0, drafts = 0, starts = 0;
              await tester.pumpWidget(
                MaterialApp(
                  theme: ClinicalAgendaStyle.theme,
                  home: Scaffold(
                    body: ClinicalCareVisitView(
                      appointment: a('A'),
                      psychology: psychology,
                      detailsController: controller,
                      markers: const {},
                      templates: attendanceTemplates(
                        psychology ? 'psychology' : 'dental',
                      ),
                      onMarker: (_) {},
                      onSaveDraft: () => drafts++,
                      onSaveEvolution: () => saves++,
                      onFinalize: () => finishes++,
                      onStartPause: () => starts++,
                      onOpenRecord: () {},
                      billing: const Text('Financeiro real'),
                      scheduling: const Text('Grade real'),
                      draftStatus: 'Alterações pendentes',
                      saving: false,
                      evolutionSaved: false,
                    ),
                  ),
                ),
              );
              await tester.enterText(
                find.byKey(const ValueKey('care-evolution')),
                'Texto informado pelo profissional',
              );
              final saveLabel = psychology
                  ? 'Salvar evolução psicológica'
                  : 'Salvar evolução';
              await tester.scrollUntilVisible(
                find.text(saveLabel),
                300,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text(saveLabel));
              await tester.pumpAndSettle();
              await tester.tap(find.text(saveLabel));
              expect(saves, 1);
              expect(finishes, 0);
              if (psychology) {
                await tester.tap(find.text('Salvar como rascunho'));
                expect(drafts, 1);
              }
              final start = psychology
                  ? 'Iniciar sessão'
                  : 'Iniciar atendimento';
              await tester.scrollUntilVisible(
                find.text(start),
                300,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text(start));
              await tester.pumpAndSettle();
              await tester.tap(find.text(start));
              expect(starts, 1);
              await tester.ensureVisible(
                find.text(
                  psychology
                      ? 'Finalizar sessão terapêutica'
                      : 'Finalizar atendimento',
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.text(
                  psychology
                      ? 'Finalizar sessão terapêutica'
                      : 'Finalizar atendimento',
                ),
              );
              expect(finishes, 1);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
      testWidgets(
        'ficha finalizada desabilita alterações e não anuncia criptografia inexistente',
        (tester) async {
          final controller = TextEditingController(text: 'Registro concluído');
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: ClinicalAgendaStyle.theme,
              home: Scaffold(
                body: ClinicalCareVisitView(
                  appointment: a('A', status: 'Finalizado'),
                  psychology: true,
                  detailsController: controller,
                  markers: const {},
                  templates: const [],
                  onMarker: (_) {},
                  onSaveDraft: () {},
                  onSaveEvolution: () {},
                  onFinalize: () {},
                  onStartPause: () {},
                  onOpenRecord: () {},
                  billing: const Text('Financeiro'),
                  scheduling: const Text('Agenda'),
                  draftStatus: 'Finalizado',
                  saving: false,
                  evolutionSaved: true,
                ),
              ),
            ),
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('care-evolution')))
                .readOnly,
            isTrue,
          );
          expect(find.textContaining('ponta a ponta'), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Atendimento finalizado'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          final button = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Atendimento finalizado'),
          );
          expect(button.onPressed, isNull);
        },
      );
    });
  }
}
