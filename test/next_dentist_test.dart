import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/user_model.dart';
import 'package:odonto_controle/services/user_service.dart';

UserModel _u(String id) => UserModel(
      id: id,
      name: 'Dr $id',
      email: '$id@clinica.com',
      role: 'dentista',
    );

void main() {
  group('resolveNextDentist', () {
    test('mantém o atual quando atende', () {
      expect(resolveNextDentist('d2', [_u('d1'), _u('d2')]), 'd2');
    });

    test('cai no primeiro quando o atual saiu', () {
      expect(resolveNextDentist('fora', [_u('d1'), _u('d2')]), 'd1');
    });

    test('sem lista mantém o atual', () {
      expect(resolveNextDentist('d1', []), 'd1');
    });
  });
}
