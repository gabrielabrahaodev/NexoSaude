import 'package:cloud_firestore/cloud_firestore.dart';
import 'clinic_trial_policy.dart';
import 'document_service.dart';

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
        if (p == 'clinics/$clinicId' ||
            p == 'portal_slots/$clinicId' ||
            p == 'public_clinics/$clinicId') {
          return true;
        }
        if (p.startsWith('clinics/$clinicId/settings/') ||
            p == 'clinics/$clinicId/members' ||
            p == 'clinics/$clinicId/members_private' ||
            p == 'public_clinics/$clinicId/leads') return true;
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
    // Leads e projeção da avaliação pública não devem sobreviver à cascata.
    ClinicDeleteStep.subcollection('public_clinics/$clinicId/leads'),
    ClinicDeleteStep.doc('public_clinics/$clinicId'),
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
    // Segredo Cloudinary legado fica em subcoleção do documento
    // integrations; o DELETE do pai não remove os descendentes no Firestore.
    ClinicDeleteStep.subcollection(
        'clinics/$clinicId/settings/integrations/cloudinary'),
    ClinicDeleteStep.doc('clinics/$clinicId/settings/integrations'),
    ClinicDeleteStep.doc('portal_slots/$clinicId'),
    // Ambos os diretórios são removidos antes do documento da clínica.
    ClinicDeleteStep.subcollection('clinics/$clinicId/members'),
    ClinicDeleteStep.subcollection('clinics/$clinicId/members_private'),
    ClinicDeleteStep.doc('clinics/$clinicId'),
    // Staff: remove o vínculo; o doc do usuário (e o login) é mantido.
    ClinicDeleteStep.arrayRemove('users', 'allowedClinics', clinicId),
  ];
}

/// Executor (owner; regras exigem `isOwner()` nos deletes operacionais).
/// Retorna o motivo de bloqueio da cascata pelo navegador, sem executar
/// operações remotas. Trial ausente é aceito por compatibilidade com clínicas
/// legadas/de teste; formatos inválidos, bloqueio administrativo e expiração
/// são fail-closed.
String? clinicDeleteBlockReason(
  Map<String, dynamic> clinicData, {
  String clinicId = '',
  DateTime? now,
}) {
  final trialInvalidOrExpired = clinicTrialExpiredOrInvalid(
    clinicId,
    clinicData['trialEndsAt'],
    now: now,
  );
  if (clinicData['blockedByAdmin'] == true || trialInvalidOrExpired) {
    return 'A clínica está bloqueada, expirada ou sem uma data de trial válida. A cascata pelo navegador foi interrompida antes das exclusões. Use migrate/delete-clinic.js em DRY-RUN, revise o relatório e só então confirme a operação administrativa.';
  }
  return null;
}

class ClinicDeleteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Apaga tudo da clínica em blocos de 450 (limite do batch).
  /// `onStage` recebe o rótulo da etapa p/ barra de progresso.
  /// Erros saem rotulados com a etapa (`[ler X]`, `[apagar lote]`) para
  /// diagnóstico — o toast da UI exibe onde negou.
  Future<void> deleteClinic(
    String clinicId, {
    void Function(String stage)? onStage,
  }) async {
    if (clinicId.isEmpty) throw ArgumentError('clinicId vazio');
    var stage = 'início';
    try {
      // Não comece a cascata em clínica bloqueada/expirada: as Rules vão
      // negar as consultas operacionais e uma cascata em lotes pode ficar parcial.
      stage = 'verificar estado da clínica';
      final clinicSnap = await _db.collection('clinics').doc(clinicId).get();
      final clinicData = clinicSnap.data();
      if (clinicData == null) {
        throw StateError('Clínica não encontrada.');
      }
      final deleteBlockReason = clinicDeleteBlockReason(
        clinicData,
        clinicId: clinicId,
      );
      if (deleteBlockReason != null) throw StateError(deleteBlockReason);

      // 1. Pacientes comprovados da clínica (base do resto do plano).
      stage = 'localizar pacientes';
      onStage?.call('Localizando pacientes...');
    final pats = await _db
        .collection('patients')
        .where('clinicId', isEqualTo: clinicId)
        .get();
    final patientIds = [for (final d in pats.docs) d.id];

    // Protege binários legados: não apagar a metadata que identifica o arquivo
    // remoto. A verificação é somente leitura e antecede qualquer batch.
    stage = 'verificar documentos remotos legados';
    final remoteDocPaths = <String>[];
    for (final patient in pats.docs) {
      final docSnap = await patient.reference.collection('docs').get();
      for (final fileDoc in docSnap.docs) {
        if (requiresRemoteCloudinaryCleanup(fileDoc.data())) {
          remoteDocPaths.add('patients/${patient.id}/docs/${fileDoc.id}');
        }
      }
    }
    if (remoteDocPaths.isNotEmpty) {
      throw StateError(
        'Exclusão cancelada antes de qualquer escrita: existem '
        '${remoteDocPaths.length} arquivo(s) do Cloudinary. Remova os binários '
        'legados pelo processo administrativo e repita a exclusão.',
      );
    }

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
    stage = 'mapear dados';
    onStage?.call('Mapeando dados...');
    final toDelete = <DocumentReference>[];
    final arrayTargets = <DocumentReference>[];
    // Vínculos conhecidos por tenant; nunca enumere users globalmente.
    final linkedUserIds = <String>{};
    for (final step in plan) {
      switch (step.kind) {
        case ClinicDeleteStep.kQuery:
          stage =
              'ler ${step.collection} (${step.field}=${step.value})';
          final snap = await _db
              .collection(step.collection)
              .where(step.field!, isEqualTo: step.value)
              .get();
          toDelete.addAll(snap.docs.map((d) => d.reference));
          break;
        case ClinicDeleteStep.kArrayRemove:
          // As Rules negam listagem global de users. Descobre-se a equipe
          // exclusivamente pelas projeções privadas/públicas da própria clínica.
          stage = 'localizar equipe em clinics/${clinicId}/members';
          final publicMembers = await _db
              .collection('clinics')
              .doc(clinicId)
              .collection('members')
              .get();
          final privateMembers = await _db
              .collection('clinics')
              .doc(clinicId)
              .collection('members_private')
              .get();
          linkedUserIds
            ..addAll(publicMembers.docs.map((d) => d.id))
            ..addAll(privateMembers.docs.map((d) => d.id));
          for (final uid in linkedUserIds) {
            stage = 'verificar vínculo users/$uid';
            final userRef = _db.collection('users').doc(uid);
            final userSnap = await userRef.get();
            if (!userSnap.exists) continue;
            final allowed = (userSnap.data()?['allowedClinics'] as List? ?? [])
                .map((value) => '$value')
                .toSet();
            if (allowed.contains(clinicId)) arrayTargets.add(userRef);
          }
          break;
        case ClinicDeleteStep.kDoc:
          toDelete.add(_db.doc(step.path));
          break;
        case ClinicDeleteStep.kSubcollection:
          stage = 'ler ${step.path}';
          final snap = await _db.collection(step.path).get();
          toDelete.addAll(snap.docs.map((d) => d.reference));
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
      stage =
          'apagar lote ${done + 1}–${(done + 450).clamp(1, toDelete.length)} de ${toDelete.length}';
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
      stage = 'desvincular equipe';
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
    } catch (e) {
      throw Exception('cascata [$stage]: $e');
    }
  }
}
