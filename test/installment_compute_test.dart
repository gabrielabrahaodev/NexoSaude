import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/financial_service.dart';

void main() {
  group('FinancialService.computeInstallments', () {
    test('100 em 3x ajusta centavos na 1a', () {
      final s = FinancialService.computeInstallments(
        payValue: 100,
        installments: 3,
      );
      expect(s.map((e) => e.value).toList(), [33.34, 33.33, 33.33]);
      expect(s.map((e) => e.value).reduce((a, b) => a + b),
          closeTo(100.0, 0.001));
    });

    test('parcela única não ajusta', () {
      final s = FinancialService.computeInstallments(
        payValue: 250.5,
        installments: 1,
      );
      expect(s.length, 1);
      expect(s.first.value, 250.5);
    });

    test('líquido com ajuste vai para a 1a', () {
      final s = FinancialService.computeInstallments(
        payValue: 100,
        installments: 3,
        taxPerInstallment: 1.0,
        netPerInstallment: 33.0,
      );
      expect(s.map((e) => e.tax).toList(), [1.0, 1.0, 1.0]);
      expect(s.map((e) => e.net).toList(), [31.0, 33.0, 33.0]);
    });

    test('sem taxa, líquido acompanha o bruto', () {
      final s = FinancialService.computeInstallments(
        payValue: 100,
        installments: 2,
      );
      expect(s.map((e) => e.net).toList(), [50.0, 50.0]);
    });
  });

  group('FinancialService.addMonths', () {
    test('preserva o dia; clamp em fevereiro', () {
      expect(FinancialService.addMonths(DateTime(2026, 1, 15), 1),
          DateTime(2026, 2, 15));
      expect(FinancialService.addMonths(DateTime(2026, 1, 31), 1),
          DateTime(2026, 2, 28));
      expect(FinancialService.addMonths(DateTime(2026, 12, 10), 2),
          DateTime(2027, 2, 10));
    });
  });
}
