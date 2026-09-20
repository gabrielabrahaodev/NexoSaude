import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/subscription.dart';

void main() {
  group('subscriptionAmount', () {
    test('40 o primeiro, +15 por extra', () {
      expect(subscriptionAmount(0), 0.0);
      expect(subscriptionAmount(1), 40.0);
      expect(subscriptionAmount(2), 55.0);
      expect(subscriptionAmount(5), 100.0);
    });

    test('preço customizável (config)', () {
      expect(subscriptionAmount(3, base: 50, extra: 10), 70.0);
    });
  });

  group('trialExpired', () {
    test('expira após o vencimento', () {
      final now = DateTime(2026, 9, 19, 12);
      expect(trialExpired(DateTime(2026, 9, 18), now), isTrue);
      expect(trialExpired(DateTime(2026, 9, 20), now), isFalse);
      expect(trialExpired(null, now), isFalse);
    });
  });

  group('blockEffective', () {
    test('trial expirado OU bloqueio manual', () {
      expect(blockEffective(trialOver: true, manual: false), isTrue);
      expect(blockEffective(trialOver: false, manual: true), isTrue);
      expect(blockEffective(trialOver: false, manual: false), isFalse);
    });
  });
}
