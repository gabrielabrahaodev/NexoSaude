import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/lab_order.dart';
import 'package:odonto_controle/screens/lab/clinical_lab_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';
import 'package:odonto_controle/utils/lab_export.dart';

List<LabOrderModel> fixtures() => [
  LabOrderModel(
    id: 'pedido-089',
    clinicId: 'c',
    patientId: 'p',
    patientName: 'Amaro Lino da Silva',
    description: 'Prótese parcial removível',
    procedureName: 'PPR Dupla',
    price: 640,
    supplierId: 'lab1',
    supplierName: 'Lab Dental Precision',
    dentistId: 'd1',
    dentistName: 'Dra. Laucieli Costa',
    createdAt: DateTime(2026, 10, 31),
    deliveryDate: DateTime(2020, 10, 31),
    workType: 'Prótese',
  ),
  LabOrderModel(
    id: 'pedido-075',
    clinicId: 'c',
    patientId: 'p2',
    patientName: 'Gabriel Teste',
    description: 'Coroa Cerâmica Zircônia #16',
    procedureName: 'Coroa Cerâmica Zircônia #16',
    price: 280,
    supplierId: 'lab2',
    supplierName: 'Estética Oral 3D',
    dentistId: 'd2',
    dentistName: 'Dra. Camila',
    createdAt: DateTime(2026),
    status: 'sent',
    workType: 'Prótese',
  ),
  LabOrderModel(
    id: 'pedido-061',
    clinicId: 'c',
    patientId: 'p3',
    patientName: 'Carlos Henrique Soares',
    description: 'Facetas',
    procedureName: 'Facetas em Resina / E-Max (6 unid)',
    price: 1620,
    createdAt: DateTime(2026),
    status: 'pending_return',
  ),
];
void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0, 768.0, 1200.0, 1440.0]) {
      for (final individual in [false, true]) {
        testWidgets(
          'kanban $width / escuro $dark / individual $individual: layout e ações',
          (tester) async {
            AppColors.isDark = dark;
            addTearDown(() => AppColors.isDark = false);
            tester.view.physicalSize = Size(width, 1100);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var created = 0, interactions = 0;
            List<LabOrderModel>? exported;
            String? moved;
            await tester.pumpWidget(
              MaterialApp(
                theme: buildAppTheme(dark: dark),
                home: Scaffold(
                  body: ClinicalLabView(
                    orders: fixtures(),
                    individual: individual,
                    onNew: () => created++,
                    onExport: (list) => exported = list,
                    onMove: (o, s) => moved = s,
                    onAction: (o, a) {
                      if (a == 'interaction') interactions++;
                    },
                  ),
                ),
              ),
            );
            expect(find.text('3 ordens ativas'), findsOneWidget);
            expect(find.text('Aguardando Envio'), findsOneWidget);
            expect(find.text('Enviado (No Lab)'), findsOneWidget);
            await tester.tap(find.text('+ Novo Pedido de Laboratório'));
            expect(created, 1);
            final card = find.byKey(const ValueKey('lab-card-pedido-089'));
            await tester.ensureVisible(card);
            await tester.pumpAndSettle();
            final interaction = find.descendant(
              of: card,
              matching: find.byTooltip('Adicionar interação'),
            );
            await tester.ensureVisible(interaction);
            await tester.pumpAndSettle();
            await tester.tap(interaction);
            expect(interactions, 1);
            final menu = find.descendant(
              of: card,
              matching: find.byTooltip('Ações do pedido'),
            );
            await tester.ensureVisible(menu);
            await tester.pumpAndSettle();
            await tester.tap(menu);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Mover: Enviado (No Lab)'));
            await tester.pumpAndSettle();
            expect(moved, 'sent');
            await tester.ensureVisible(
              find.byKey(const ValueKey('lab-search')),
            );
            await tester.enterText(
              find.byKey(const ValueKey('lab-search')),
              'pedido-089',
            );
            await tester.pumpAndSettle();
            expect(find.text('1 ordem ativa'), findsOneWidget);
            await tester.ensureVisible(find.text('Exportar'));
            await tester.tap(find.text('Exportar'));
            expect(exported!.map((o) => o.id), ['pedido-089']);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'kanban vazio mantém quatro etapas; erro de leitura impede exportar dados antigos',
    (tester) async {
      Widget app({String? error}) => MaterialApp(
        home: Scaffold(
          body: ClinicalLabView(
            orders: const [],
            onNew: () {},
            onExport: (_) {},
            onMove: (_, _) {},
            onAction: (_, _) {},
            error: error,
          ),
        ),
      );
      await tester.pumpWidget(app());
      expect(find.text('0 ordens ativas'), findsOneWidget);
      expect(find.text('Nenhum pedido finalizado'), findsOneWidget);
      await tester.pumpWidget(app(error: 'Falha ao ler pedidos'));
      expect(find.text('Falha ao ler pedidos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('exportação usa os campos reais, escapando CSV e fórmulas', () {
    final csv = buildLabCsv([
      LabOrderModel(
        id: 'x',
        clinicId: 'c',
        patientId: 'p',
        patientName: '=SUM(A1)',
        description: 'Trabalho "A"; teste',
        createdAt: DateTime(2026),
        price: 120,
      ),
    ]);
    expect(csv, contains("'=SUM(A1)"));
    expect(csv, contains('"Trabalho ""A""; teste"'));
    expect(csv, contains('120,00'));
    expect(formatLabMoney(1234.56).replaceAll('\u00a0', ' '), 'R\$ 1.234,56');
    expect(labStage('Solicitado'), 'pending_send');
    expect(labStage('Enviado'), 'sent');
    expect(labStage('Entregue'), 'delivered');
  });
}
