import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/clinic_capabilities.dart';

void main() {
  group('ClinicCapabilities', () {
    test('psychology libera módulos psico e papel psicologo', () {
      const caps = ClinicCapabilities('psychology');
      expect(caps.isPsychology, isTrue);
      expect(caps.isDental, isFalse);
      expect(caps.canShowBudgets, isFalse);
      expect(caps.canShowOdontogram, isFalse);
      expect(caps.canShowLab, isFalse);
      expect(caps.canUseMonthlyPackages, isTrue);
      expect(caps.canShowTherapeuticFlow, isTrue);
      expect(caps.professionalRole, 'psicologo');
      expect(caps.patientTabCount, 6); // CADASTRO, ANAMNESE, TRATAMENTOS, PRONTUÁRIO, DOCUMENTAÇÃO, PAGAMENTOS
      expect(caps.matchesProfessionalRole('psicologo'), isTrue);
      expect(caps.matchesProfessionalRole('dentista'), isFalse);
      expect(caps.matchesProfessionalRole('owner'), isTrue);
    });

    test('dental libera módulos odonto e papel dentista', () {
      const caps = ClinicCapabilities('dental');
      expect(caps.isPsychology, isFalse);
      expect(caps.isDental, isTrue);
      expect(caps.canShowBudgets, isTrue);
      expect(caps.canShowOdontogram, isTrue);
      expect(caps.canShowLab, isTrue);
      expect(caps.canUseMonthlyPackages, isFalse);
      expect(caps.professionalRole, 'dentista');
      expect(caps.patientTabCount, 9);
      expect(caps.matchesProfessionalRole('dentista'), isTrue);
      expect(caps.matchesProfessionalRole('psicologo'), isFalse);
    });

    test('tipo desconhecido/nulo cai em dental', () {
      expect(ClinicCapabilities.ofType(null).isDental, isTrue);
      expect(ClinicCapabilities.ofType('fisio').patientTabCount, 9); // cai em dental: todas as abas
    });
  });
}
