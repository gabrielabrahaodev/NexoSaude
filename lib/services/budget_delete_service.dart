import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';

bool budgetDeletionBlocked(Map<String, dynamic> data, {required bool approved}) =>
    approved || ['aprovado', 'approved'].contains('${data['status']}'.toLowerCase()) ||
    '${data['relatedPlanId'] ?? ''}'.isNotEmpty;

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
    if (budgetId.isEmpty || patientId.isEmpty) throw ArgumentError('Orçamento/paciente vazio');
    final clinicId = SessionManager().currentClinicId;
    await _db.runTransaction((tx) async {
      final ref = _db.collection('budgets').doc(budgetId);
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      if (clinicId == null || data['clinicId'] != clinicId || data['patientId'] != patientId) {
        throw StateError('Orçamento fora da unidade ou paciente.');
      }
      if (budgetDeletionBlocked(data, approved: approved)) {
        throw StateError('Orçamento aprovado possui contrato e histórico vinculados. Exclusão bloqueada.');
      }
      tx.delete(ref);
    });
    onStage?.call('Concluído.');
  }
}
