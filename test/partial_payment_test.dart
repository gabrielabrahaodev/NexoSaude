import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/financial_service.dart';

void main() {
  group('partialRemainder', () {
    test('200 menos 150 = 50 no pendente', () {
      expect(
        FinancialService.partialRemainder(
            amount: 200, paidAmount: 0, payValue: 150),
        50.0,
      );
    });

    test('desconta parciais anteriores', () {
      expect(
        FinancialService.partialRemainder(
            amount: 200, paidAmount: 150, payValue: 30),
        20.0,
      );
    });
  });

  group('partialSummary', () {
    test('sem filhas retorna null', () {
      expect(
        FinancialService.partialSummary(
            amount: 200, paidAmount: 0, childrenAmounts: []),
        isNull,
      );
    });

    test('novo formato: resto + filha = total original', () {
      final s = FinancialService.partialSummary(
          amount: 50, paidAmount: 0, childrenAmounts: [150])!;
      expect(s.paid, 150.0);
      expect(s.total, 200.0);
    });

    test('legado: amount cheio + paidAmount + filha', () {
      final s = FinancialService.partialSummary(
          amount: 200, paidAmount: 150, childrenAmounts: [150])!;
      expect(s.paid, 150.0);
      expect(s.total, 200.0);
    });
  });
}
