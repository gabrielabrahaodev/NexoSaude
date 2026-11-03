import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/lab_order.dart';
import 'package:odonto_controle/models/supplier_model.dart';
import 'package:odonto_controle/screens/lab/lab_order_dialog.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

Future<void> open(
  WidgetTester tester,
  Future<void> Function(LabOrderModel) save,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PatientVisualStyle.theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => LabOrderDialog(
                orderId: 'stable-id',
                clinicId: 'c',
                initialPatientId: 'p',
                patients: const [LabOption('p', 'Gabriel')],
                plans: const [],
                dentists: const [],
                suppliers: [
                  SupplierModel(
                    id: 'l',
                    clinicId: 'c',
                    name: 'Lab real',
                    category: 'Laboratório',
                  ),
                ],
                onCreate: save,
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lab real').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('lab-description')),
    'Coroa real',
  );
}

Future<void> click(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 1000.0]) {
      testWidgets(
        'pedido $width escuro $dark: custo explícito, validação e trava de reenvio',
        (tester) async {
          AppColors.isDark = dark;
          addTearDown(() => AppColors.isDark = false);
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          LabOrderModel? submitted;
          var calls = 0;
          final done = Completer<void>();
          await open(tester, (o) {
            submitted = o;
            calls++;
            return done.future;
          });
          await click(tester, 'Criar pedido');
          expect(calls, 0);
          expect(find.text('Informe se houve custo.'), findsOneWidget);
          await click(tester, 'Sim, gerar conta a pagar');
          await click(tester, 'Criar pedido');
          expect(calls, 0);
          await tester.enterText(
            find.byKey(const ValueKey('lab-cost')),
            '1.234,56',
          );
          await click(tester, 'Criar pedido');
          expect(calls, 1);
          expect(submitted!.price, 1234.56);
          expect(submitted!.costDueDate, isNotNull);
          expect(submitted!.relatedFinancialId, isNull);
          expect(submitted!.id, 'stable-id');
          await click(tester, 'Criando…');
          expect(calls, 1);
          done.complete();
          await tester.pumpAndSettle();
          expect(find.byType(LabOrderDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'sem custo não envia valor oculto; falha mantém rascunho e ID para retry',
    (tester) async {
      var calls = 0;
      LabOrderModel? saved;
      await open(tester, (o) async {
        calls++;
        saved = o;
        if (calls == 1) throw StateError('offline');
      });
      await click(tester, 'Sim, gerar conta a pagar');
      await tester.enterText(find.byKey(const ValueKey('lab-cost')), '99');
      await click(tester, 'Não houve custo');
      await click(tester, 'Criar pedido');
      await tester.pumpAndSettle();
      expect(find.byType(LabOrderDialog), findsOneWidget);
      expect(saved!.price, 0);
      expect(saved!.costDueDate, isNull);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('lab-description')),
            )
            .controller!
            .text,
        'Coroa real',
      );
      await click(tester, 'Criar pedido');
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(saved!.id, 'stable-id');
      expect(find.byType(LabOrderDialog), findsNothing);
    },
  );
}
