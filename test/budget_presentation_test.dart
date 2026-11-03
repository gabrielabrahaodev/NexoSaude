import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odonto_controle/models/budget_model.dart';
import 'package:odonto_controle/models/procedure_model.dart';
import 'package:odonto_controle/screens/patients/budget_create_dialog.dart';
import 'package:odonto_controle/utils/budget_print.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  BudgetModel b({
    String status = 'Pendente',
    Map<String, dynamic> details = const {},
  }) => BudgetModel(
    id: 'x',
    clinicId: 'c',
    patientId: 'p',
    patientName: 'Paciente Teste',
    total: 300,
    status: status,
    date: DateTime(2026, 10, 30),
    items: [
      {'name': 'Procedimento', 'price': 300},
    ],
    details: details,
  );
  test('legacy prices are row totals, not multiplied again', () {
    final i = BudgetItemDisplay({'name': 'Item', 'price': 300, 'quantity': 3});
    expect(i.subtotal, 300);
    expect(i.unitPrice, 100);
    expect(i.region, 'Não informado');
  });
  test('explicit item unit, discount, subtotal and teeth preserved', () {
    final i = BudgetItemDisplay({
      'price': 240,
      'unitPrice': 100,
      'quantity': 3,
      'discountAmount': 60,
      'teeth': [16, 17],
    });
    expect(i.unitPrice, 100);
    expect(i.discount, 60);
    expect(i.subtotal, 240);
    expect(i.region, '16, 17');
  });
  test(
    'metadata and BRL legacy fields parse without fabricating missing date',
    () {
      final result = BudgetModel.fromMap('id', {
        'clinicId': 'c',
        'patientId': 'p',
        'patientName': 'Teste',
        'total': '1.234,56',
        'items': [
          {'price': '300'},
          'invalid',
        ],
        'relatedPlanId': 'plan',
      });
      expect(result.total, 1234.56);
      expect(result.items.length, 1);
      expect(result.dateKnown, false);
      expect(budgetTitle(result), 'Orçamento');
      expect(result.details['relatedPlanId'], 'plan');
      expect(result.toMap()['relatedPlanId'], 'plan');
    },
  );
  test('dates accept Timestamp and strings, not invented sequential IDs', () {
    final result = BudgetModel.fromMap('random-id', {
      'date': Timestamp.fromDate(DateTime(2026, 10, 1)),
    });
    expect(budgetTitle(result), 'Orçamento – 01/10/2026');
    expect(budgetDate('2026-10-01'), DateTime(2026, 10, 1));
  });
  test('filters reflect approval, negotiation, refusal and actual expiry', () {
    final now = DateTime(2026, 10, 31);
    expect(budgetGroup(b(), now), BudgetGroup.pending);
    expect(budgetGroup(b(status: 'approved'), now), BudgetGroup.approved);
    expect(budgetGroup(b(status: 'Recusado'), now), BudgetGroup.declined);
    expect(
      budgetGroup(b(details: {'validUntil': DateTime(2026, 10, 30)}), now),
      BudgetGroup.declined,
    );
    expect(
      budgetGroup(
        b(status: 'Aprovado', details: {'validUntil': DateTime(2020)}),
        now,
      ),
      BudgetGroup.approved,
    );
    expect(budgetGroup(b(status: 'outro'), now), BudgetGroup.other);
  });
  test('validity includes last day', () {
    expect(
      budgetGroup(
        b(details: {'validUntil': DateTime(2026, 10, 31)}),
        DateTime(2026, 10, 31, 23),
      ),
      BudgetGroup.pending,
    );
  });
  test('only stored HTTPS links without credentials can be shared', () {
    expect(budgetLink(null), isNull);
    expect(budgetLink('javascript:alert(1)'), isNull);
    expect(budgetLink('https://user:secret@example.org'), isNull);
    expect(budgetLink('https://example.org/p/1')!.host, 'example.org');
  });
  test(
    'new item stores net row price compatible with existing approval wizard',
    () {
      final i =
          BudgetDraftItem(
              ProcedureModel(
                id: 'p',
                clinicId: 'c',
                name: 'Item',
                category: 'Geral',
                price: 1300,
              ),
            )
            ..quantity = 2
            ..discountPercent = 10;
      expect(i.subtotal, 2340);
      expect(i.toMap()['price'], 2340);
      expect(i.toMap()['discountAmount'], 260);
      expect(i.valid, true);
      i.quantity = 1.5;
      expect(i.valid, false);
      i.quantity = 1;
      i.discountPercent = 101;
      expect(i.valid, false);
    },
  );
  test('PDF uses actual quote values and missing data is supported', () async {
    final bytes = await budgetProposalPdf([b()], 'Clínica Teste');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
