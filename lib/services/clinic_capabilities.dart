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

  /// Normaliza papéis antigos em inglês e português para evitar que
  /// usuários legados desapareçam dos seletores de profissionais.
  static String normalizeRole(String role) {
    final value = role.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (value) {
      case 'dentist':
      case 'dental_professional':
        return 'dentista';
      case 'psychologist':
      case 'psychologist_therapist':
      case 'psychoterapist':
        return 'psicologo';
      case 'receptionist':
      case 'reception':
        return 'recepcionista';
      default:
        return value;
    }
  }

  bool matchesProfessionalRole(String role) {
    final normalized = normalizeRole(role);
    if (normalized == 'owner') return true;
    return normalized == professionalRole;
  }

  /// Contagem exata das abas renderizadas em `patient_details_screen.dart`:
  /// dental = 9; psychology = 6 (sem ORÇAMENTOS/ODONTOGRAMA/LABORATÓRIO);
  /// desconhecido cai em dental = 9. DEVE bater com o TabBar/TabBarView —
  /// divergência quebra o DefaultTabController em runtime.
  int get patientTabCount => switch (clinicType) {
        'dental' => 9,
        'psychology' => 6,
        _ => 9,
      };
}
