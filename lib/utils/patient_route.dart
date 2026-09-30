import 'package:flutter/material.dart';
import '../screens/patients/patient_details_screen.dart';

/// Deep-link p/ a ficha do paciente (Cobrança/Meu dia/Agenda sem menu).
/// Carrega ids nos argumentos (testado) p/ verificação futura.
Route openPatient(String patientId, String patientName) {
  return MaterialPageRoute(
    settings: RouteSettings(
      name: '/paciente',
      arguments: {'patientId': patientId, 'patientName': patientName},
    ),
    builder: (_) => PatientDetailsScreen(
      patientId: patientId,
      patientName: patientName,
    ),
  );
}
