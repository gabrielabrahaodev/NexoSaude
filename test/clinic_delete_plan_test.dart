import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      expect(
          ClinicDeleteStep.doc('public_clinics/OUTRA')
              .scopedTo(clinic, patients.toSet()),
          isFalse);
      expect(
          ClinicDeleteStep.subcollection('public_clinics/OUTRA/leads')
              .scopedTo(clinic, patients.toSet()),
          isFalse);
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

    test('inclui projection e leads publicos da clinica', () {
      final plan = clinicDeletePlan(clinic, patients);
      final docs = [
        for (final s in plan)
          if (s.kind == ClinicDeleteStep.kDoc) s.path
      ];
      final subcollections = [
        for (final s in plan)
          if (s.kind == ClinicDeleteStep.kSubcollection) s.path
      ];
      expect(docs, contains('public_clinics/$clinic'));
      expect(subcollections, contains('public_clinics/$clinic/leads'));
      expect(
          plan.firstWhere((s) => s.path == 'public_clinics/$clinic/leads')
              .scopedTo(clinic, patients.toSet()),
          isTrue);
      expect(docs, contains('clinics/$clinic'));
      expect(docs, contains('portal_slots/$clinic'));
      expect(subcollections, contains('clinics/$clinic/members'));
      expect(subcollections, contains('clinics/$clinic/members_private'));
      expect(
        subcollections,
        contains('clinics/$clinic/settings/integrations/cloudinary'),
      );
    });

    test('clinica vazia nao gera plano', () {
      expect(() => clinicDeletePlan('', patients), throwsArgumentError);
    });
  });

  group('clinicDeleteBlockReason', () {
    final now = DateTime(2026, 10, 17, 12);

    test('permite clínica ativa com trial futuro', () {
      expect(
        clinicDeleteBlockReason({
          'blockedByAdmin': false,
          'trialEndsAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
        }, now: now),
        isNull,
      );
    });

    test('bloqueia clínica bloqueada administrativamente', () {
      expect(
        clinicDeleteBlockReason({
          'blockedByAdmin': true,
          'trialEndsAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
        }, now: now),
        contains('bloqueada'),
      );
    });

    test('bloqueia trial expirado ou igual ao instante atual', () {
      for (final date in [now.subtract(const Duration(seconds: 1)), now]) {
        expect(
          clinicDeleteBlockReason({
            'blockedByAdmin': false,
            'trialEndsAt': Timestamp.fromDate(date),
          }, now: now),
          contains('expirada'),
        );
      }
    });

    test('bloqueia formato inválido, sem fazer operações remotas', () {
      expect(
        clinicDeleteBlockReason({
          'blockedByAdmin': false,
          'trialEndsAt': 'ontem',
        }, now: now),
        isNotNull,
      );
    });

    test('bloqueia trial ausente para clínica não explicitamente de teste', () {
      expect(
        clinicDeleteBlockReason(
          {'blockedByAdmin': false},
          clinicId: 'CLINICA_NAO_REGULARIZADA',
          now: now,
        ),
        isNotNull,
      );
    });

    test('mantém somente as duas clínicas de teste conhecidas sem trial', () {
      for (final clinicId in [
        'MxftREXD5vjKtE7SyJIH',
        'VlFVjTlNX8yqijeHyczt',
      ]) {
        expect(
          clinicDeleteBlockReason(
            {'blockedByAdmin': false},
            clinicId: clinicId,
            now: now,
          ),
          isNull,
        );
      }
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
