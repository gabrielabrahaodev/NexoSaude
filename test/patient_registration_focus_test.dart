import 'dart:async';
import 'package:odonto_controle/ui/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_view.dart';
import 'package:odonto_controle/screens/patients/tabs/patient_details_tab.dart';

// Snapshot fake is confined to this regression test, without a production subtype.
// ignore: subtype_of_sealed_class
class _PatientSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _PatientSnapshot(this.values);
  final Map<String, dynamic> values;
  @override
  String get id => 'patient-a';
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => values;
}

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'digitação mantém foco, seleção e assinatura de dados em $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var listens = 0;
        final source =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
              onListen: () => listens++,
            );
        AppColors.isDark = false;
        addTearDown(() => AppColors.isDark = false);
        Widget app() => MaterialApp(
          theme: PatientVisualStyle.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PatientDetailsTab(
                patientId: 'patient-a',
                patientName: 'Gabriel',
                embedded: true,
                patientStream: source.stream,
              ),
            ),
          ),
        );
        await tester.pumpWidget(app());
        source.add(
          _PatientSnapshot({
            'clinicId': 'clinic-a',
            'name': 'Gabriel',
            'profession': '',
            'lgpdPortalConsent': {'accepted': false},
          }),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar Dados'));
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('registration-profession'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pump();
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final state = tester.state<EditableTextState>(editable);
        var typed = '';
        for (final character in 'Analista de Sistemas'.split('')) {
          typed += character;
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: typed,
              selection: TextSelection.collapsed(offset: typed.length),
            ),
          );
          await tester.pumpAndSettle();
          expect(state.mounted, isTrue);
          expect(
            identical(tester.state<EditableTextState>(editable), state),
            isTrue,
          );
          expect(state.widget.focusNode.hasFocus, isTrue);
          expect(state.widget.controller.text, typed);
          expect(state.widget.controller.selection.baseOffset, typed.length);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(listens, 1);
        }
        // Switching theme must preserve the actual editor, focus, draft and stream.
        for (final dark in [true, false]) {
          AppColors.isDark = dark;
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(
            identical(tester.state<EditableTextState>(editable), state),
            isTrue,
          );
          expect(state.widget.focusNode.hasFocus, isTrue);
          expect(state.widget.controller.text, typed);
          expect(state.widget.controller.selection.baseOffset, typed.length);
          expect(
            Theme.of(tester.element(field)).brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          expect(listens, 1);
        }
        // A new snapshot while editing must not replace the user's draft.
        source.add(
          _PatientSnapshot({
            'clinicId': 'clinic-a',
            'name': 'Gabriel atualizado',
            'profession': 'Valor remoto',
            'lgpdPortalConsent': {'accepted': false},
          }),
        );
        await tester.pumpAndSettle();
        expect(state.widget.focusNode.hasFocus, isTrue);
        expect(state.widget.controller.text, 'Analista de Sistemas');
        await tester.ensureVisible(find.text('Cancelar edição'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar edição'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(field).controller!.text,
          'Valor remoto',
        );
        expect(listens, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await source.close();
      },
    );
  }
}
