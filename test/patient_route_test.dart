import 'package:odonto_controle/screens/patients/patient_details_screen.dart';
import 'package:odonto_controle/screens/patients/clinical_patient_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/utils/patient_route.dart';

void main() {
  test('a ficha abre em Cadastro por padrão, preservando aba explícita', () {
    expect(const PatientDetailsScreen(patientId: 'p').initialTab, 0);
    expect(
      const ClinicalPatientScreen(
        patientId: 'p',
        fallbackName: 'Paciente',
      ).initialTab,
      0,
    );
    expect(
      const PatientDetailsScreen(patientId: 'p', initialTab: 8).initialTab,
      8,
    );
    expect(
      const ClinicalPatientScreen(
        patientId: 'p',
        fallbackName: 'Paciente',
        initialTab: 4,
      ).initialTab,
      4,
    );
    expect(
      patientSectionIndex(PatientSection.registration, psychology: false),
      0,
    );
    expect(
      patientSectionIndex(PatientSection.registration, psychology: true),
      0,
    );
    expect(patientSectionIndex(PatientSection.payments, psychology: false), 8);
    expect(patientSectionIndex(PatientSection.payments, psychology: true), 5);
  });
  group('openPatient', () {
    test('leva patientId e patientName nos argumentos', () {
      final route = openPatient('p1', 'Gabriel');
      expect(route, isA<MaterialPageRoute>());
      final args = (route.settings.arguments as Map?) ?? const {};
      expect(args['patientId'], 'p1');
      expect(args['patientName'], 'Gabriel');
    });
  });
}
