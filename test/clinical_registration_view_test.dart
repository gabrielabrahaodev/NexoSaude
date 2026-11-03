import 'package:odonto_controle/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/patient_registration.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_view.dart';
import 'package:odonto_controle/screens/patients/clinical_registration_view.dart';

void main() {
  for (final dark in [false, true]) {
    group(dark ? 'modo escuro' : 'modo claro', () {
      setUp(() => AppColors.isDark = dark);
      tearDown(() => AppColors.isDark = false);
      for (final width in [320.0, 390.0, 600.0, 1000.0, 1440.0]) {
        testWidgets(
          'cadastro $width: blocos, edição e persistência dos campos de formulário',
          (tester) async {
            tester.view.physicalSize = Size(width, 1800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final draft = PatientRegistrationDraft.fromMap({
              'name': 'Gabriel Teste',
              'cpf': '52998224725',
              'address': 'Rua Teste',
              'socialName': 'Gabriel',
            });
            final ctrls = {
              for (final e in draft.values.entries)
                e.key: TextEditingController(text: e.value),
            };
            addTearDown(() {
              for (final c in ctrls.values) {
                c.dispose();
              }
            });
            var editing = false, saves = 0;
            final key = GlobalKey<FormState>();
            await tester.pumpWidget(
              MaterialApp(
                theme: PatientVisualStyle.theme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: StatefulBuilder(
                      builder: (context, setState) => ClinicalRegistrationView(
                        controllers: ctrls,
                        formKey: key,
                        editing: editing,
                        saving: false,
                        lookingUpCep: false,
                        channels: draft.reminderChannels,
                        onEdit: () => setState(() => editing = !editing),
                        onSave: () {
                          if (key.currentState!.validate()) saves++;
                        },
                        onLookupCep: () {},
                        onWhatsApp: () {},
                        onChanged: () => setState(() {}),
                        onChannel: (c) => setState(() {
                          if (!draft.reminderChannels.add(c))
                            draft.reminderChannels.remove(c);
                        }),
                        portal: const Text('Ações reais do portal'),
                        consentSummary: 'Sem aceite registrado',
                      ),
                    ),
                  ),
                ),
              ),
            );
            expect(find.text('Dados Pessoais'), findsOneWidget);
            expect(find.text('Documentação & Conformidade'), findsOneWidget);
            expect(find.text('Localização & Endereço'), findsOneWidget);
            expect(find.text('Contato de Emergência'), findsOneWidget);
            expect(
              tester
                  .widget<EditableText>(
                    find.descendant(
                      of: find.byKey(const ValueKey('registration-name')),
                      matching: find.byType(EditableText),
                    ),
                  )
                  .readOnly,
              isTrue,
            );
            await tester.tap(find.text('Editar Dados'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const ValueKey('registration-profession')),
            );
            await tester.enterText(
              find.byKey(const ValueKey('registration-profession')),
              'Analista de Sistemas',
            );
            expect(ctrls['profession']!.text, 'Analista de Sistemas');
            await tester.ensureVisible(find.text('Salvar Alterações'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Salvar Alterações'));
            expect(saves, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    });
  }
}
