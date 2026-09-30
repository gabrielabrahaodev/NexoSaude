import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/widgets/patient_smart_context_card.dart';

void main() {
  group('clinicalAlerts', () {
    test('retorna vazio quando sem anamnese', () {
      expect(clinicalAlerts(null), isEmpty);
      expect(clinicalAlerts({}), isEmpty);
    });

    test('alergia com descricao', () {
      expect(
        clinicalAlerts({
          'hasAllergies': true,
          'allergiesDesc': 'Dipirona',
        }),
        ['Alérgico(a): Dipirona'],
      );
    });

    test('cada condicao vira um alerta', () {
      expect(
        clinicalAlerts({
          'conditions': {
            'Diabetes': true,
            'Hipertensão (Pressão Alta)': true,
            'Problemas Cardíacos': true,
          },
          'pregnant': true,
        }),
        ['Diabético', 'Hipertenso', 'Cardíaco', 'Gestante'],
      );
    });

    test('ignora falsos e chaves desconhecidas', () {
      expect(
        clinicalAlerts({
          'hasAllergies': false,
          'conditions': {'Diabetes': false, 'Asma': true},
        }),
        isEmpty,
      );
    });
  });
}
