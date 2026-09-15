import 'session_manager.dart';

/// Centraliza todas as decisões de comportamento por tipo de clínica.
///
/// Regra: telas e serviços devem perguntar para cá em vez de comparar
/// `clinicType == 'psychology'` espalhado pelo código.
///
/// Tipos conhecidos: 'dental' | 'psychology'. Desconhecido cai em dental.
class ClinicCapabilities {
  final String clinicType;

  const ClinicCapabilities(this.clinicType);

  factory ClinicCapabilities.current() =>
      ClinicCapabilities(SessionManager().clinicType);

  factory ClinicCapabilities.ofType(String? type) =>
      ClinicCapabilities(type ?? 'dental');

  bool get isPsychology => clinicType == 'psychology';
  bool get isDental => !isPsychology;

  // --- Visibilidade de módulos ---
  bool get canShowBudgets => !isPsychology;
  bool get canShowOdontogram => isDental;
  bool get canShowLab => isDental;
  bool get canUseMonthlyPackages => isPsychology;
  bool get canShowTherapeuticFlow => isPsychology;

  // --- Vocabulário por tipo ---
  String get professionalRole => isPsychology ? 'psicologo' : 'dentista';
  String get professionalLabel => isPsychology ? 'Psicólogo' : 'Dentista';

  bool matchesProfessionalRole(String role) {
    if (role == 'owner') return true;
    return role == professionalRole;
  }

  int get patientTabCount => switch (clinicType) {
        'dental' => 9,
        'psychology' => 7,
        _ => 8,
      };
}
