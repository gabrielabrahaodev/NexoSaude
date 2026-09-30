import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/utils/patient_route.dart';

void main() {
  group('openPatient', () {
    test('leva patientId e patientName nos argumentos', () {
      final route = openPatient('p1', 'Gabriel');
      expect(route, isA<MaterialPageRoute>());
      final args =
          (route.settings.arguments as Map?) ?? const {};
      expect(args['patientId'], 'p1');
      expect(args['patientName'], 'Gabriel');
    });
  });
}
