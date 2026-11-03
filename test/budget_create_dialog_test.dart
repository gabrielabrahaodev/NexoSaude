import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/procedure_model.dart';
import 'package:odonto_controle/screens/patients/budget_create_dialog.dart';
import 'package:odonto_controle/ui/app_theme.dart';

void main() {
  for (final dark in [true, false]) {
    for (final width in [390.0, 1100.0]) {
      testWidgets(
        'create budget $width dark=$dark validates and preserves focus',
        (tester) async {
          AppColors.isDark = dark;
          addTearDown(() => AppColors.isDark = false);
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int saves = 0;
          List<Map<String, dynamic>>? saved;
          final done = Completer<void>();
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(dark: dark),
              home: Scaffold(
                body: BudgetCreateDialog(
                  patientName: 'Paciente',
                  clinicName: 'Yervant',
                  procedures: Stream.value([
                    ProcedureModel(
                      id: 'p',
                      clinicId: 'c',
                      name: 'Restauração',
                      category: 'Geral',
                      price: 300,
                    ),
                  ]),
                  onSave: (items, total, metadata) {
                    saves++;
                    saved = items;
                    return done.future;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('budget-save')));
          await tester.pumpAndSettle();
          expect(saves, 0);
          await tester.tap(find.text('Adicionar'));
          await tester.pumpAndSettle();
          final desc = find.byType(TextFormField).first;
          await tester.ensureVisible(desc);
          await tester.enterText(desc, 'Restauração completa');
          await tester.pumpAndSettle();
          expect(find.text('Restauração completa'), findsOneWidget);
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: desc,
                    matching: find.byType(EditableText),
                  ),
                )
                .focusNode
                .hasFocus,
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('budget-save')));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('budget-save')));
          expect(saves, 1);
          expect(saved!.single['price'], 300);
          done.completeError(StateError('offline'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Não foi possível salvar'),
            findsOneWidget,
          );
          expect(find.text('Restauração completa'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
