import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/financial_model.dart';
import 'package:odonto_controle/models/tooth_model.dart';
import 'package:odonto_controle/screens/care/clinical_care_view.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_view.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets(
      'ficha $width: identidade, indicadores, tratamento e cobranças sem overflow',
      (tester) async {
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var payments = 0,
            registration = 0,
            closed = 0,
            received = 0,
            linked = 0;
        final f = FinancialModel(
          id: 'f',
          clinicId: 'c',
          patientId: 'p',
          patientName: 'Gabriel',
          title: 'Raspagem e profilaxia supragengival',
          description: 'Parcela',
          amount: 300,
          date: DateTime(2026, 10, 30),
          dueDate: DateTime(2026, 10, 29),
          type: 'income',
          dentistName: 'Dra. Laucieli Costa',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ClinicalCareStyle.theme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    ClinicalPatientHeader(
                      name: 'Gabriel Teste de Sobrenome Longo',
                      id: 'real-patient-id-123456',
                      status: 'Ativo',
                      consent: false,
                      psychology: false,
                      birth: '14/05/1992',
                      cpf: '12345678912',
                      phone: '(12) 98123-4567',
                      onBack: () {},
                      onPayments: () => payments++,
                      onRegistration: () => registration++,
                    ),
                    ClinicalPatientMetrics(
                      items: [
                        for (final label in [
                          'ASSIDUIDADE',
                          'A RECEBER',
                          'RECEBIDO',
                          'CUSTO OPERACIONAL',
                        ])
                          PatientMetric(
                            label: label,
                            value: 'R\$ 1.234,56',
                            detail: 'Informações reais do paciente',
                            icon: Icons.check,
                            color: PatientVisualStyle.accent,
                            progress: .5,
                          ),
                      ],
                    ),
                    ClinicalTreatmentCard(
                      start: '30/10/2026',
                      active: true,
                      items: const [
                        {
                          'name':
                              'Raspagem e profilaxia supragengival com orientação',
                          'price': 300,
                        },
                      ],
                      total: 300,
                      paid: 0,
                      margin: 100,
                      installments: '0/1 pagas',
                      onFinancial: () {},
                      onPayments: () => payments++,
                      onClose: () => closed++,
                      onLinkedTeeth: () => linked++,
                    ),
                    ClinicalPatientLedger(
                      charges: [f],
                      onOpen: (_) => received++,
                      onReceive: (_) => received++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.text('123.***.***-12'), findsOneWidget);
        expect(find.text('LGPD aceito'), findsNothing);
        await tester.tap(find.text('Receber pagamento'));
        expect(payments, 1);
        await tester.tap(find.byTooltip('Editar cadastro'));
        expect(registration, 1);
        await tester.ensureVisible(find.text('ENCERRAR TRATAMENTO'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ENCERRAR TRATAMENTO'));
        expect(closed, 1);
        await tester.ensureVisible(find.text('Ver Dentes Vinculados'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver Dentes Vinculados'));
        expect(linked, 1);
        if (width >= 900) {
          await tester.ensureVisible(find.text('Receber'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Receber'));
        } else {
          await tester.ensureVisible(find.byTooltip('Receber / opções'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Receber / opções'));
        }
        expect(received, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('odontograma: centro, faces laterais, raiz, zoom e salvamento', (
    tester,
  ) async {
    final tooth = ToothModel(id: 22, facesStatus: {'occlusal': 'restored'});
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final faces = <ToothFace>[];
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ClinicalCareStyle.theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClinicalOdontogramView(
              teeth: [tooth],
              controller: controller,
              onFaceTap: (_, f) => faces.add(f),
              onSave: () => saved++,
              saving: false,
            ),
          ),
        ),
      ),
    );
    final paint = find.descendant(
      of: find.byType(ClinicalTooth),
      matching: find.byType(CustomPaint),
    );
    final rect = tester.getRect(paint);
    await tester.tapAt(rect.center);
    expect(faces.last, ToothFace.occlusal);
    await tester.tapAt(rect.topLeft + const Offset(2, 16));
    expect(faces.last, ToothFace.mesial);
    await tester.longPressAt(rect.center);
    expect(faces.last, ToothFace.root);
    await tester.tap(find.byTooltip('Zoom +'));
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    await tester.tap(find.text('Salvar alterações'));
    expect(saved, 1);
    expect(tester.takeException(), isNull);
  });
}
