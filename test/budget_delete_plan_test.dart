import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/budget_delete_service.dart';

void main() {
  group('budgetChildQueries', () {
    const budgetId = 'B1';
    const planId = 'P1';
    const fins = ['F1', 'F2'];

    test('amarra tudo no plano/orcamento (nunca solto)', () {
      final qs = budgetChildQueries(
          budgetId: budgetId, planId: planId, financialIds: fins);
      expect(qs, isNotEmpty);
      for (final q in qs) {
        final pinsPlan =
            (q.value == planId || q.value == budgetId);
        final pinsFins = q.values
            .every((v) => v == 'F1' || v == 'F2');
        expect(pinsPlan || pinsFins, isTrue,
            reason: '${q.collection}.${q.field}');
      }
    });

    test('cobre planos, financeiros, custos e filhas', () {
      final qs = budgetChildQueries(
          budgetId: budgetId, planId: planId, financialIds: fins);
      final keys = {
        for (final q in qs) '${q.collection}.${q.field}'
      };
      expect(keys, contains('treatment_plans.budgetId'));
      expect(keys, contains('financial.planId'));
      expect(keys, contains('expenses.relatedPlanId'));
      expect(keys, contains('financial.parentId'));
      expect(keys, contains('expenses.relatedFinancialId'));
    });

    test('sem financeiros nao gera chunks orfaos', () {
      final qs = budgetChildQueries(
          budgetId: budgetId, planId: planId, financialIds: []);
      final keys = {
        for (final q in qs) '${q.collection}.${q.field}'
      };
      expect(keys, isNot(contains('financial.parentId')));
      expect(keys, isNot(contains('expenses.relatedFinancialId')));
    });

    test('chunking em blocos de 10 (limite do whereIn)', () {
      final many = [for (var i = 0; i < 25; i++) 'F$i'];
      final qs = budgetChildQueries(
          budgetId: budgetId, planId: planId, financialIds: many);
      final chunks = [
        for (final q in qs)
          if (q.field == 'parentId') q.values.length
      ];
      expect(chunks, [10, 10, 5]);
    });
  });
}
