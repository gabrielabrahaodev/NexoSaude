import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/utils/display.dart';

void main() {
  group('parseBRL', () {
    test('nulo e vazio zeram', () {
      expect(parseBRL(null), 0.0);
      expect(parseBRL(''), 0.0);
      expect(parseBRL('   '), 0.0);
    });

    test('número passa direto', () {
      expect(parseBRL(10), 10.0);
      expect(parseBRL(10.5), 10.5);
    });

    test('formato US (1500.50)', () {
      expect(parseBRL('1500.50'), 1500.5);
    });

    test('formato BR (1.500,50 e R\$)', () {
      expect(parseBRL('1.500,50'), 1500.5);
      expect(parseBRL('R\$ 1.500,50'), 1500.5);
    });
  });

  group('formatBRL', () {
    test('2 casas com prefixo R\$', () {
      expect(formatBRL(300), 'R\$ 300.00');
      expect(formatBRL(10.5), 'R\$ 10.50');
      expect(formatBRL(0), 'R\$ 0.00');
    });
  });

  group('daysAgoLabel', () {
    test('hoje, ontem e há N dias', () {
      expect(daysAgoLabel(0), 'hoje');
      expect(daysAgoLabel(1), 'ontem');
      expect(daysAgoLabel(5), 'há 5 dias');
    });
  });

  group('slotCardColor', () {
    test('ocupado > selecionado > livre', () {
      expect(
        slotCardColor(isOccupied: true, isSelected: true),
        Colors.grey,
      );
      expect(
        slotCardColor(isOccupied: false, isSelected: true),
        Colors.black,
      );
      expect(
        slotCardColor(isOccupied: false, isSelected: false),
        Colors.black87,
      );
    });
  });

  group('chargeBadgeColor', () {
    test('pago > pendente > demais', () {
      expect(
        chargeBadgeColor(isPaid: true, isPending: true),
        Colors.green,
      );
      expect(
        chargeBadgeColor(isPaid: false, isPending: true),
        Colors.red,
      );
      expect(
        chargeBadgeColor(isPaid: false, isPending: false),
        Colors.orange,
      );
    });
  });
}
