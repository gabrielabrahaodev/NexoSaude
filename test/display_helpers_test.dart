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

  group('format datas', () {
    final d = DateTime(2026, 9, 5, 9, 5);
    test('padrões pt-BR', () {
      expect(formatDateShort(d), '05/09');
      expect(formatDateTimeShort(d), '05/09 09:05');
      expect(formatDateFull(d), '05/09/2026');
      expect(formatDateShortYear(d), '05/09/26');
      expect(formatDateTimeFull(d), '05/09/2026 09:05');
      expect(formatDateDash(d), '05/09/2026 - 09:05');
      expect(formatDateDot(d), '05/09 • 09:05');
      // Quirk herdado: `s` de "às" vira "segundos" no intl (igual ao original).
      expect(formatDateAs(d), '05/09 à0 09:05');
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

  group('birthMonthOf', () {
    test('dd/MM/yyyy vira MM', () {
      expect(birthMonthOf('22/09/1990'), '09');
      expect(birthMonthOf('5/3/2000'), '03');
      expect(birthMonthOf(DateTime(2000, 1, 15)), '01');
    });

    test('nulo e inválido dão null', () {
      expect(birthMonthOf(null), isNull);
      expect(birthMonthOf(''), isNull);
      expect(birthMonthOf('abc'), isNull);
      expect(birthMonthOf('13/13/2000'), isNull);
      expect(birthMonthOf(123), isNull);
    });
  });

  group('normalizeWhatsApp', () {
    test('formatos BR viram E.164', () {
      expect(normalizeWhatsApp('(11) 98765-4321'), '5511987654321');
      expect(normalizeWhatsApp('11987654321'), '5511987654321');
      expect(normalizeWhatsApp('+5511987654321'), '5511987654321');
      expect(normalizeWhatsApp('551134567890'), '551134567890');
      expect(normalizeWhatsApp('(11) 3456-7890'), '551134567890');
    });

    test('inválido dá null', () {
      expect(normalizeWhatsApp(null), isNull);
      expect(normalizeWhatsApp(''), isNull);
      expect(normalizeWhatsApp('12345'), isNull);
      expect(normalizeWhatsApp('abc'), isNull);
    });
  });
}
