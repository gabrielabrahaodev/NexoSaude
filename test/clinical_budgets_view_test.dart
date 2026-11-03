import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/budget_model.dart';
import 'package:odonto_controle/screens/patients/clinical_budgets_view.dart';
import 'package:odonto_controle/ui/app_theme.dart';

List<BudgetModel> budgets() => [
  BudgetModel(
    id: 'pending',
    clinicId: 'c',
    patientId: 'p',
    patientName: 'Teste',
    total: 1500,
    status: 'Pendente',
    date: DateTime(2026, 10, 30),
    items: [
      {
        'name': 'Aparelho Autoligado Metálico Superior & Inferior',
        'price': 1200,
        'unitPrice': 1300,
        'quantity': 1,
        'discountAmount': 100,
        'region': 'Arcada Completa',
      },
      {
        'name': 'Profilaxia Pré-Ortodôntica',
        'price': 300,
        'region': 'Geral / Profilaxia',
      },
    ],
    details: {
      'number': 'ORC-2026-055',
      'validUntil': DateTime(2070, 11, 14),
      'responsibleName': 'Dra. Teste',
      'suggestedInstallments': 12,
      'paymentConditions': 'Entrada de 30% + saldo no cartão em 6x sem juros.',
      'shareUrl': 'https://example.org/proposta/token',
    },
  ),
  BudgetModel(
    id: 'approved',
    clinicId: 'c',
    patientId: 'p',
    patientName: 'Teste',
    total: 300,
    status: 'Aprovado',
    date: DateTime(2026, 10, 26),
    items: [
      {'name': 'Raspagem Subgengival & Profilaxia', 'price': 300},
    ],
    details: {'relatedPlanId': 'plan'},
  ),
  BudgetModel(
    id: 'declined',
    clinicId: 'c',
    patientId: 'p',
    patientName: 'Teste',
    total: 50,
    status: 'Recusado',
    date: DateTime(2026, 10, 10),
    items: [
      {'name': 'Recusado Teste', 'price': 50},
    ],
  ),
];
void main() {
  for (final dark in [true, false]) {
    for (final width in [390.0, 768.0, 1200.0]) {
      testWidgets('budget cards/filter/actions $width dark=$dark', (
        tester,
      ) async {
        AppColors.isDark = dark;
        addTearDown(() => AppColors.isDark = false);
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <String>[];
        List<BudgetModel>? printed;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(dark: dark),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ClinicalBudgetsView(
                  budgets: budgets(),
                  plans: const {
                    'plan': {
                      'id': 'plan',
                      'budgetId': 'approved',
                      'status': 'active',
                    },
                  },
                  onNew: () => actions.add('new'),
                  onApprove: (_) => actions.add('approve'),
                  onDelete: (_) => actions.add('delete'),
                  onPrint: (_) => actions.add('print'),
                  onPrintAll: (b) => printed = b,
                  onShare: (_) => actions.add('share'),
                  onTreatment: (_) => actions.add('treatment'),
                  onReceipt: (_) => actions.add('receipt'),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('budget-new')));
        expect(actions, ['new']);
        final approve = find.byKey(const ValueKey('budget-approve-pending'));
        await tester.ensureVisible(approve);
        await tester.tap(approve);
        expect(actions, contains('approve'));
        for (final text in [
          'Imprimir Proposta',
          'Compartilhar Link',
          'Ver Tratamento',
        ]) {
          final f = find.text(text).first;
          await tester.ensureVisible(f);
          await tester.tap(f);
        }
        expect(actions, containsAll(['print', 'share', 'treatment']));
        final filter = find.byKey(const ValueKey('budget-filter-approved'));
        await tester.ensureVisible(filter);
        await tester.tap(filter);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('budget-card-pending')), findsNothing);
        expect(
          find.byKey(const ValueKey('budget-card-approved')),
          findsOneWidget,
        );
        final print = find.byTooltip('Imprimir orçamentos filtrados');
        await tester.ensureVisible(print);
        await tester.tap(print);
        expect(printed!.map((b) => b.id), ['approved']);
        final search = find.byKey(const ValueKey('budget-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, 'inexistente');
        await tester.pumpAndSettle();
        expect(find.text('Nenhum orçamento encontrado.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'missing public link and treatment do not create fictitious actions',
    (tester) async {
      final b = budgets();
      b[0] = BudgetModel(
        id: 'pending',
        clinicId: 'c',
        patientId: 'p',
        patientName: 'Teste',
        total: 10,
        status: 'Pendente',
        date: DateTime(2026),
        items: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClinicalBudgetsView(
                budgets: b,
                onNew: () {},
                onApprove: (_) {},
                onDelete: (_) {},
                onPrint: (_) {},
                onPrintAll: (_) {},
                onShare: (_) {},
                onTreatment: (_) {},
                onReceipt: (_) {},
              ),
            ),
          ),
        ),
      );
      final share = tester.widget<OutlinedButton>(
        find
            .ancestor(
              of: find.text('Compartilhar Link').first,
              matching: find.byType(OutlinedButton),
            )
            .first,
      );
      expect(share.onPressed, isNull);
      final treatment = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Ver Tratamento'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(treatment.onPressed, isNull);
    },
  );
}
