import 'package:cloud_firestore/cloud_firestore.dart';
import 'portal_mirror.dart';

/// Uma query filha da cascata de orçamento.
/// `values` com 1 item = `isEqualTo`; com N = chunk de `whereIn`.
class BudgetDeleteQuery {
  final String collection;
  final String field;
  final List<String> values;

  const BudgetDeleteQuery(this.collection, this.field, this.values);

  /// Valor único (consultas amarradas no plano/orçamento).
  String get value => values.length == 1 ? values.first : '';
}

/// Filhos a partir do plano: tratamentos (`budgetId`), financeiros
/// (`planId`), custos (`relatedPlanId`) + filhas de parcelamento e
/// comissões (`parentId`/`relatedFinancialId`, em chunks de 10).
/// Tudo amarrado no `planId`/`budgetId`/ids coletados — nunca solto.
/// Puro e testado.
List<BudgetDeleteQuery> budgetChildQueries({
  required String budgetId,
  required String planId,
  required List<String> financialIds,
}) {
  if (budgetId.isEmpty || planId.isEmpty) return [];
  final out = [
    BudgetDeleteQuery('treatment_plans', 'budgetId', [budgetId]),
    BudgetDeleteQuery('financial', 'planId', [planId]),
    BudgetDeleteQuery('expenses', 'relatedPlanId', [planId]),
  ];
  for (var i = 0; i < financialIds.length; i += 10) {
    final chunk = financialIds.sublist(
        i, i + 10 > financialIds.length ? financialIds.length : i + 10);
    out.add(BudgetDeleteQuery('financial', 'parentId', chunk));
    out.add(BudgetDeleteQuery('expenses', 'relatedFinancialId', chunk));
  }
  return out;
}

/// Executor: orçamento pendente apaga só o doc; aprovado apaga em cadeia
/// (tratamentos, pagamentos, custos, filhas) + limpa o espelho.
class BudgetDeleteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Contagem p/ o diálogo ("3 tratamentos, 12 lançamentos...").
  Future<Map<String, int>> countChildren(
      String budgetId, String planId) async {
    if (budgetId.isEmpty || planId.isEmpty) return {};
    Future<int> count(BudgetDeleteQuery q) async {
      try {
        final query = q.values.length == 1
            ? _db
                .collection(q.collection)
                .where(q.field, isEqualTo: q.values.first)
            : _db
                .collection(q.collection)
                .where(q.field, whereIn: q.values);
        final c = await query.count().get();
        return c.count ?? 0;
      } catch (_) {
        return 0;
      }
    }

    final fins = await _db
        .collection('financial')
        .where('planId', isEqualTo: planId)
        .get();
    final finIds = [for (final d in fins.docs) d.id];
    final out = <String, int>{};
    for (final q in budgetChildQueries(
        budgetId: budgetId, planId: planId, financialIds: finIds)) {
      out['${q.collection} (${q.field})'] = await count(q);
    }
    return out;
  }

  /// Apaga em blocos de 450. Erros saem rotulados com a etapa.
  Future<void> deleteBudget({
    required String budgetId,
    required String patientId,
    required bool approved,
    void Function(String stage)? onStage,
  }) async {
    if (budgetId.isEmpty) throw ArgumentError('budgetId vazio');
    var stage = 'início';
    try {
      final bdoc =
          await _db.collection('budgets').doc(budgetId).get();
      final planId = '${(bdoc.data() ?? {})['relatedPlanId'] ?? ''}';

      if (!approved || planId.isEmpty) {
        stage = 'apagar orçamento';
        onStage?.call('Apagando orçamento...');
        await _db.collection('budgets').doc(budgetId).delete();
        onStage?.call('Concluído.');
        return;
      }

      stage = 'localizar vinculados';
      onStage?.call('Localizando vinculados...');
      final fins = await _db
          .collection('financial')
          .where('planId', isEqualTo: planId)
          .get();
      final finIds = [for (final d in fins.docs) d.id];
      final queries = budgetChildQueries(
          budgetId: budgetId, planId: planId, financialIds: finIds);

      stage = 'mapear vinculados';
      onStage?.call('Mapeando vinculados...');
      final toDelete = <DocumentReference>[];
      final mirrorIds = <String>{...finIds};
      for (final q in queries) {
        stage = 'ler ${q.collection} (${q.field})';
        final snap = q.values.length == 1
            ? await _db
                .collection(q.collection)
                .where(q.field, isEqualTo: q.values.first)
                .get()
            : await _db
                .collection(q.collection)
                .where(q.field, whereIn: q.values)
                .get();
        toDelete.addAll(snap.docs.map((d) => d.reference));
        if (q.collection == 'financial') {
          mirrorIds.addAll([for (final d in snap.docs) d.id]);
        }
      }

      var done = 0;
      while (done < toDelete.length) {
        stage = 'apagar lote ${done + 1}–'
            '${(done + 450).clamp(1, toDelete.length)}'
            ' de ${toDelete.length}';
        onStage?.call(
            'Apagando ${done + 1}–${(done + 450).clamp(1, toDelete.length)} de ${toDelete.length}...');
        final batch = _db.batch();
        for (final ref in toDelete.skip(done).take(450)) {
          batch.delete(ref);
        }
        await batch.commit();
        done += 450;
      }

      stage = 'apagar orçamento';
      onStage?.call('Apagando orçamento...');
      await _db.collection('budgets').doc(budgetId).delete();

      // Espelho: financeiros apagados saem da lista do portal.
      if (patientId.isNotEmpty) {
        stage = 'limpar espelho';
        for (final fid in mirrorIds) {
          try {
            await PortalMirrorSync.removeDebt(
                patientId: patientId, debtId: fid);
          } catch (_) {}
        }
      }
      onStage?.call('Concluído.');
    } catch (e) {
      throw Exception('orçamento [$stage]: $e');
    }
  }
}
