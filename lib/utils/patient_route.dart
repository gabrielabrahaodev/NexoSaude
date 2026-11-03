import 'package:flutter/material.dart';
import '../screens/patients/patient_details_screen.dart';
import '../services/clinic_capabilities.dart';

/// Deep-link p/ a ficha do paciente (Cobrança/Meu dia/Agenda sem menu).
/// Carrega ids nos argumentos (testado) p/ verificação futura.
enum PatientSection { registration, record, payments, documents }

int patientSectionIndex(PatientSection section, {required bool psychology}) =>
    switch (section) {
      PatientSection.registration => 0,
      PatientSection.record => psychology ? 3 : 4,
      PatientSection.payments => psychology ? 5 : 8,
      PatientSection.documents => psychology ? 4 : 7,
    };

Route openPatient(
  String patientId,
  String patientName, {
  PatientSection section = PatientSection.registration,
}) {
  return MaterialPageRoute(
    settings: RouteSettings(
      name: '/paciente',
      arguments: {'patientId': patientId, 'patientName': patientName},
    ),
    builder: (_) => PatientDetailsScreen(
      patientId: patientId,
      patientName: patientName,
      initialTab: patientSectionIndex(
        section,
        psychology: ClinicCapabilities.current().isPsychology,
      ),
    ),
  );
}
