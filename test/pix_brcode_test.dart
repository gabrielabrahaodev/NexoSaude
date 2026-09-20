import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/pix_brcode.dart';

void main() {
  group('crc16', () {
    test('vetor padrão CRC16-CCITT-FALSE', () {
      expect(crc16('123456789'), 0x29B1);
    });
  });

  group('pixBrCode', () {
    test('monta payload BR Code com chave, valor e txid', () {
      final code = pixBrCode(
        chave: '11999999999',
        amount: 300,
        nome: 'Clínica Nexo',
        cidade: 'São Paulo',
      );
      expect(code.startsWith('000201'), isTrue);
      expect(code.contains('br.gov.bcb.pix'), isTrue);
      expect(code.contains('11999999999'), isTrue);
      expect(code.contains('300.00'), isTrue);
      expect(code.contains('CLINICA NEXO'), isTrue);
      expect(RegExp(r'6304[0-9A-F]{4}$').hasMatch(code), isTrue);
    });

    test('sem valor = sem campo 54', () {
      final code = pixBrCode(chave: 'a@b.com', nome: 'X', cidade: 'Y');
      expect(code.contains('54'), isFalse);
    });
  });
}
