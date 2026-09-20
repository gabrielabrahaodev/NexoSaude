import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/pending_counts.dart';

void main() {
  group('countRemarcar', () {
    test('conta só remarcar (case-insensitive)', () {
      final docs = <Map<String, dynamic>>[
        {'status': 'remarcar'},
        {'status': 'Remarcar'},
        {'status': 'Agendado'},
        {'status': 'Confirmado'},
        {},
      ];
      expect(countRemarcar(docs), 2);
    });
  });

  group('countAvisos', () {
    test('conta só docs com avisoPagamento mapa', () {
      final docs = <Map<String, dynamic>>[
        {'avisoPagamento': {'at': 'x'}},
        {'status': 'pendente'},
        {'avisoPagamento': 'invalido'},
        {},
      ];
      expect(countAvisos(docs), 1);
    });
  });
}
