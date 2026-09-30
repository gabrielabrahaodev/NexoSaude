import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/screens/agenda/agenda_manager_screen.dart';

void main() {
  group('riskBlockView', () {
    test('esperando ou sem dado = shimmer', () {
      expect(
          riskBlockView(waiting: true, hasData: false, level: null),
          RiskBlockView.shimmer);
      expect(
          riskBlockView(waiting: false, hasData: false, level: null),
          RiskBlockView.shimmer);
    });

    test('erro = escondido (sem shimmer eterno)', () {
      expect(
          riskBlockView(
              waiting: false, hasData: false, level: null, hasError: true),
          RiskBlockView.hidden);
    });

    test('verde = escondido; demais = mostra', () {
      expect(
          riskBlockView(
              waiting: false, hasData: true, level: 'green'),
          RiskBlockView.hidden);
      expect(
          riskBlockView(waiting: false, hasData: true, level: 'red'),
          RiskBlockView.shown);
      expect(
          riskBlockView(
              waiting: false, hasData: true, level: 'orange'),
          RiskBlockView.shown);
    });
  });
}
