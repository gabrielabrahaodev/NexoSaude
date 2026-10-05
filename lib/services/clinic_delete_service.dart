import 'package:cloud_firestore/cloud_firestore.dart';

/// Uma etapa da exclusão de clínica em cascata.
///
/// INVARIANTE (testada): toda etapa toca SOMENTE a clínica alvo —
/// `query` sempre com `clinicId == id`, `doc` com path da clínica ou de
/// paciente comprovado dela, `users` só via `arrayRemove` (nunca apaga
/// usuário — login de staff de outras clínicas segue intacto).
class ClinicDeleteStep {
  static const kQuery = 'query';
  static const kDoc = 'doc';
  static const kSubcollection = 'subcollection';
  static const kArrayRemove = 'arrayRemove';

  /// Espelhos `portal/{token}`: resolvidos via pacientes (a regra do
  /// `portal/` permite get/delete, mas NÃO list — listar vazaria tokens).
  static const kPortalTokens = 'portalTokens';

  final String kind;

  /// Coleção (`query`/`arrayRemove`) ou path completo (`doc`/`subcollection`).
  final String collection;
  final String? field;
  final String? value;

  const ClinicDeleteStep.query(this.collection, String clinicId)
      : kind = ClinicDeleteStep.kQuery,
        field = 'clinicId',
        value = clinicId;

  const ClinicDeleteStep.doc(this.collection)
      : kind = ClinicDeleteStep.kDoc,
        field = null,
        value = null;

  const ClinicDeleteStep.subcollection(this.collection)
      : kind = ClinicDeleteStep.kSubcollection,
        field = null,
        value = null;

  const ClinicDeleteStep.arrayRemove(this.collection, this.field, this.value)
      : kind = ClinicDeleteStep.kArrayRemove;

  const ClinicDeleteStep.portalTokens(String clinicId)
      : kind = ClinicDeleteStep.kPortalTokens,
        collection = 'portal',
        field = 'clinicId',
        value = clinicId;

  String get path => collection;

  String describe() => '$kind:$collection${field == null ? '' : '.$field=$value'}';

  /// `true` quando a etapa não pode tocar dado de outra clínica.
  /// `patientIds`: pacientes comprovados da clínica (via query por clinicId).
  bool scopedTo(String clinicId, Set<String> patientIds) {
    if (clinicId.isEmpty) return false;
    switch (kind) {
      case ClinicDeleteStep.kQuery:
        return field == 'clinicId' && value == clinicId;
      case ClinicDeleteStep.kPortalTokens:
        // Tokens resolvidos só dos pacientes comprovados da clínica.
        return collection == 'portal' &&
            field == 'clinicId' &&
            value == clinicId;
      case ClinicDeleteStep.kArrayRemove:
        return collection == 'users' &&
            field == 'allowedClinics' &&
            value == clinicId;
      case ClinicDeleteStep.kDoc:
      case ClinicDeleteStep.kSubcollection:
        final p = collection;
        if (p == 'clinics/$clinicId' || p == 'portal_slots/$clinicId') {
          return true;
        }
        if (p.startsWith('clinics/$clinicId/settings/')) return true;
        // Pacientes e derivados: só ids comprovados da clínica.
        final m = RegExp(r'^(?:patients|anamnesis)/([^/]+)').firstMatch(p);
        if (m != null) return patientIds.contains(m.group(1));
        return false;
    }
    return false;
  }
}

/// Plano de exclusão: coleções operacionais com `clinicId`, espelhos,
/// anamnese/subcoleções/docs dos pacientes da clínica, settings, slots,
/// doc da clínica e desvínculo do staff. Executor resolve `patientIds`
/// por query (`patients` com `clinicId`) antes de montar.
List<ClinicDeleteStep> clinicDeletePlan(
    String clinicId, List<String> patientIds) {
  if (clinicId.isEmpty) throw ArgumentError('clinicId vazio');
  return [
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
    ])
      ClinicDeleteStep.query(c, clinicId),
    // Portal por token (nunca por list — ver kPortalTokens).
    ClinicDeleteStep.portalTokens(clinicId),
    for (final pid in patientIds)
      ClinicDeleteStep.doc('anamnesis/$pid'),
    for (final pid in patientIds)
      ClinicDeleteStep.subcollection('patients/$pid/clinical_data'),
    for (final pid in patientIds)
      ClinicDeleteStep.subcollection('patients/$pid/docs'),
    for (final pid in patientIds) ClinicDeleteStep.doc('patients/$pid'),
    ClinicDeleteStep.subcollection(
        'clinics/$clinicId/settings/fees/profiles'),
    ClinicDeleteStep.doc('clinics/$clinicId/settings/fees'),
    ClinicDeleteStep.doc('clinics/$clinicId/settings/integrations'),
    ClinicDeleteStep.doc('portal_slots/$clinicId'),
    ClinicDeleteStep.doc('clinics/$clinicId'),
    // Staff: remove o vínculo; o doc do usuário (e o login) é mantido.
    ClinicDeleteStep.arrayRemove('users', 'allowedClinics', clinicId),
  ];
}

/// Executor (owner; regras exigem `isOwner()` nos deletes operacionais).
class ClinicDeleteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Apaga tudo da clínica em blocos de 450 (limite do batch).
  /// `onStage` recebe o rótulo da etapa p/ barra de progresso.
  Future<void> deleteClinic(
    String clinicId, {
    void Function(String stage)? onStage,
  }) async {
    if (clinicId.isEmpty) throw ArgumentError('clinicId vazio');

    // 1. Pacientes comprovados da clínica (base do resto do plano).
    onStage?.call('Localizando pacientes...');
    final pats = await _db
        .collection('patients')
        .where('clinicId', isEqualTo: clinicId)
        .get();
    final patientIds = [for (final d in pats.docs) d.id];
    // Tokens dos espelhos (delete direto por id; list é negado pela regra).
    final portalTokens = <String>{};
    for (final d in pats.docs) {
      final token = '${(d.data())['portalToken'] ?? ''}';
      if (token.isNotEmpty) portalTokens.add(token);
    }
    final plan = clinicDeletePlan(clinicId, patientIds);
    assert(
        plan.every((s) => s.scopedTo(clinicId, patientIds.toSet())),
        'etapa fora do escopo da clínica');

    // 2. Coleta referências (queries + docs + subs + vínculos).
    onStage?.call('Mapeando dados...');
    final toDelete = <DocumentReference>[];
    final arrayTargets = <DocumentReference>[];
    for (final step in plan) {
      switch (step.kind) {
        case ClinicDeleteStep.kQuery:
          final snap = await _db
              .collection(step.collection)
              .where(step.field!, isEqualTo: step.value)
              .get();
          toDelete.addAll(snap.docs.map((d) => d.reference));
          break;
        case ClinicDeleteStep.kDoc:
          toDelete.add(_db.doc(step.path));
          break;
        case ClinicDeleteStep.kSubcollection:
          final snap = await _db.collection(step.path).get();
          toDelete.addAll(snap.docs.map((d) => d.reference));
          break;
        case ClinicDeleteStep.kArrayRemove:
          final snap = await _db
              .collection(step.collection)
              .where(step.field!, arrayContains: step.value)
              .get();
          arrayTargets.addAll(snap.docs.map((d) => d.reference));
          break;
        case ClinicDeleteStep.kPortalTokens:
          for (final token in portalTokens) {
            toDelete.add(_db.collection('portal').doc(token));
          }
          break;
      }
    }

    // 3. Deletes em blocos de 450.
    var done = 0;
    while (done < toDelete.length) {
      onStage?.call(
          'Apagando ${done + 1}–${(done + 450).clamp(1, toDelete.length)} de ${toDelete.length}...');
      final batch = _db.batch();
      for (final ref
          in toDelete.skip(done).take(450)) {
        batch.delete(ref);
      }
      await batch.commit();
      done += 450;
    }

    // 4. Desvínculo do staff (mantém usuários e logins).
    var undone = 0;
    while (undone < arrayTargets.length) {
      onStage?.call('Desvinculando equipe...');
      final batch = _db.batch();
      for (final ref
          in arrayTargets.skip(undone).take(450)) {
        batch.update(ref, {
          'allowedClinics': FieldValue.arrayRemove([clinicId])
        });
      }
      await batch.commit();
      undone += 450;
    }
    onStage?.call('Concluído.');
  }
}
