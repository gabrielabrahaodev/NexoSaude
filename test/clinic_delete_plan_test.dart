import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/clinic_delete_service.dart';
import 'package:odonto_controle/services/menu_access.dart';

void main() {
  const clinic = 'CLINICA_X';
  const patients = ['P1', 'P2'];

  group('clinicDeletePlan', () {
    test('toda etapa toca SOMENTE a clinica (ou pacientes dela)', () {
      final plan = clinicDeletePlan(clinic, patients);
      expect(plan, isNotEmpty);
      for (final s in plan) {
        expect(s.scopedTo(clinic, patients.toSet()), isTrue,
            reason: s.describe());
      }
    });

    test('cobre as colecoes operacionais com clinicId', () {
      final plan = clinicDeletePlan(clinic, patients);
      final cols = {
        for (final s in plan)
          if (s.kind == ClinicDeleteStep.kQuery) s.collection
      };
      for (final c in [
        'appointments',
        'budgets',
        'treatments',
        'treatment_plans',
        'financial',
        'clinical_records',
        'lab_orders',
        'psychology_schedules',
        'expenses',
        'procedures',
        'suppliers',
        'inventory',
      ]) {
        expect(cols, contains(c), reason: c);
      }
      // Portal: SEMPRE por token (regra não permite list; vazar tokens).
      expect(cols, isNot(contains('portal')));
      expect(
          plan.any((s) =>
              s.kind == ClinicDeleteStep.kPortalTokens &&
              s.value == clinic),
          isTrue);
      // Pacientes: nunca em lote (subcoleções primeiro, um a um).
      expect(cols, isNot(contains('patients')));
      final patientDocs = [
        for (final s in plan)
          if (s.kind == ClinicDeleteStep.kDoc) s.path
      ];
      expect(patientDocs, contains('patients/P1'));
      expect(patientDocs, contains('patients/P2'));
    });

    test('anamnesis somente dos pacientes listados', () {
      final plan = clinicDeletePlan(clinic, patients);
      final docs = [
        for (final s in plan)
          if (s.kind == ClinicDeleteStep.kDoc) s.path
      ];
      expect(docs, contains('anamnesis/P1'));
      expect(docs, contains('anamnesis/P2'));
      // Nunca um paciente fora da lista.
      expect(docs.any((d) => d.startsWith('anamnesis/P3')), isFalse);
    });

    test('usuarios: remove vinculo, NUNCA apaga o doc', () {
      final plan = clinicDeletePlan(clinic, patients);
      final users = plan.where((s) => s.collection == 'users');
      expect(users, isNotEmpty);
      for (final s in users) {
        expect(s.kind, ClinicDeleteStep.kArrayRemove);
      }
      expect(
          plan.any((s) =>
              s.kind == ClinicDeleteStep.kDoc &&
              s.path.startsWith('users/')),
          isFalse);
    });

    test('inclui settings, slots e o doc da clinica', () {
      final plan = clinicDeletePlan(clinic, patients);
      final docs = [
        for (final s in plan)
          if (s.kind == ClinicDeleteStep.kDoc) s.path
      ];
      expect(docs, contains('clinics/$clinic'));
      expect(docs, contains('portal_slots/$clinic'));
    });

    test('clinica vazia nao gera plano', () {
      expect(() => clinicDeletePlan('', patients), throwsArgumentError);
    });
  });

  group('MenuAccess.needsClinicSetup', () {
    test('sem clinicas e nao superadmin pede setup', () {
      expect(
          MenuAccess.needsClinicSetup(role: 'owner', allowedClinics: []),
          isTrue);
      expect(
          MenuAccess.needsClinicSetup(
              role: 'recepcionista', allowedClinics: []),
          isTrue);
    });

    test('superadmin nunca pede setup', () {
      expect(
          MenuAccess.needsClinicSetup(
              role: 'superadmin', allowedClinics: []),
          isFalse);
    });

    test('com clinica nao pede setup', () {
      expect(
          MenuAccess.needsClinicSetup(
              role: 'owner', allowedClinics: ['C1']),
          isFalse);
    });
  });
}
