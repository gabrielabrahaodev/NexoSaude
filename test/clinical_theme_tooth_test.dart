import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/tooth_model.dart';
import 'package:odonto_controle/screens/agenda/clinical_agenda_view.dart';
import 'package:odonto_controle/screens/care/clinical_care_view.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  tearDown(() => AppColors.isDark = false);
  testWidgets('alternar tema atualiza a ficha de atendimento já montada', (
    tester,
  ) async {
    final child = ClinicalCareDayView(
      date: DateTime(2026, 10, 31),
      clinicName: 'Clínica',
      psychology: false,
      appointments: const [],
      professionals: const {},
      paidToday: const {},
      selected: <String>{},
      confirming: false,
      onSelect: (_, _) {},
      onOpen: (_) {},
      onConfirm: () {},
      onFilters: () {},
      onNew: () {},
      panel: const Text('Ficha'),
    );
    for (final dark in [false, true, false]) {
      AppColors.isDark = dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(dark: dark),
          home: Scaffold(body: child),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Ordem cronológica'))).brightness,
        dark ? Brightness.dark : Brightness.light,
      );
      expect(tester.takeException(), isNull);
    }
  });
  for (final dark in [false, true]) {
    test('temas clínicos $dark: contraste de texto, campos e ações', () {
      AppColors.isDark = dark;
      for (final theme in [
        ClinicalAgendaStyle.theme,
        ClinicalCareStyle.theme,
        PatientVisualStyle.theme,
      ]) {
        expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
        expect(theme.scaffoldBackgroundColor, ClinicalAgendaStyle.background);
      }
      for (final bg in [
        ClinicalAgendaStyle.background,
        ClinicalAgendaStyle.surface,
        ClinicalAgendaStyle.elevated,
      ]) {
        expect(
          contrast(ClinicalAgendaStyle.text, bg),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(ClinicalAgendaStyle.muted, bg),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(ClinicalAgendaStyle.onAccent, ClinicalAgendaStyle.teal),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(ClinicalAgendaStyle.onBlue, ClinicalAgendaStyle.blue),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'dentes $dark: preenchimento, número e contorno acompanham o registro',
      (tester) async {
        AppColors.isDark = dark;
        final teeth = [
          ToothModel(id: 16, facesStatus: {'occlusal': 'planned'}),
          ToothModel(id: 22, facesStatus: {'occlusal': 'restored'}),
          ToothModel(id: 36, facesStatus: {'root': 'endo_planned'}),
          ToothModel(id: 18),
        ];
        await tester.pumpWidget(
          MaterialApp(
            theme: PatientVisualStyle.theme,
            home: Scaffold(
              body: Row(
                children: [
                  for (final tooth in teeth)
                    ClinicalTooth(tooth: tooth, onFaceTap: (_, _) {}),
                ],
              ),
            ),
          ),
        );
        for (final tooth in teeth) {
          final marker = ClinicalToothStyle.marker(tooth);
          final number = tester.widget<Text>(
            find.byKey(ValueKey('tooth-number-${tooth.id}')),
          );
          expect(
            number.style!.color,
            ClinicalToothStyle.numberColor(marker) ??
                PatientVisualStyle.textPrimary,
          );
          final container = tester.widget<Container>(
            find.byKey(ValueKey('tooth-marker-${tooth.id}')),
          );
          final border =
              (container.decoration! as BoxDecoration).border! as Border;
          expect(
            border.top.color,
            [22, 36].contains(tooth.id)
                ? ClinicalToothStyle.color(marker)
                : Colors.transparent,
          );
        }
        // Verify the actual painter output, including a healthy face beside the restoration.
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(ClinicalTooth).at(1),
            matching: find.byType(CustomPaint),
          ),
        );
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          paint.painter!.paint(Canvas(recorder), const Size.square(34));
          final picture = recorder.endRecording();
          final image = await picture.toImage(34, 34);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          Color pixel(int x, int y) {
            final i = (y * 34 + x) * 4;
            return Color.fromARGB(
              bytes.getUint8(i + 3),
              bytes.getUint8(i),
              bytes.getUint8(i + 1),
              bytes.getUint8(i + 2),
            );
          }

          expect(pixel(17, 17), ClinicalToothStyle.color('restored'));
          expect(pixel(17, 4), dark ? const Color(0xFF181C22) : Colors.white);
          image.dispose();
          picture.dispose();
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
