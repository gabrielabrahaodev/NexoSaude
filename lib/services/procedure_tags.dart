import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';

String patientTagId(String budgetId, int line) => 'budget_${budgetId}_line_$line';
Map<String, dynamic> procedureTagDefinition(Map<String, dynamic> procedure, String id) => {
  'schemaVersion': 1, 'clinicId': procedure['clinicId'], 'procedureId': id,
  'name': procedure['name'] ?? 'Procedimento', 'category': procedure['category'] ?? 'Geral',
  'active': procedure['active'] ?? true, 'procedureSnapshot': procedure,
};
Map<String, dynamic> patientProcedureTag({required String clinicId, required String patientId, required String patientName, required String budgetId, required String planId, required int index, required Map<String, dynamic> line, required Map<String, dynamic> definition, bool completed = false}) => {
  'schemaVersion': 1, 'clinicId': clinicId, 'patientId': patientId, 'patientName': patientName,
  'budgetId': budgetId, 'planId': planId, 'lineIndex': index,
  'procedureId': '${line['id'] ?? line['procedureId'] ?? ''}',
  'name': line['name'] ?? definition['name'] ?? 'Procedimento',
  'category': definition['category'] ?? 'Geral',
  'agreedValue': line['price'] ?? line['subtotal'], 'quantity': line['quantity'] ?? 1, 'region': line['region'],
  'lineSnapshot': line, 'definitionSnapshot': definition,
  'status': completed ? 'completed' : 'pending', 'sessionCount': 0,
};

class ProcedureTags {
  static CollectionReference<Map<String, dynamic>> collection(String patient) => FirebaseFirestore.instance.collection('patients').doc(patient).collection('procedure_tags');
  static Stream<QuerySnapshot<Map<String, dynamic>>> watch(String patient) => collection(patient).where('clinicId', isEqualTo: SessionManager().currentClinicId ?? 'waiting_session_init').snapshots();

  /// All reads precede writes. At most 8 tags/8 plans + patient/appointment,
  /// below the Firestore transaction and security-rule document access limits.
  static Future<List<Map<String, dynamic>>> readForVisit(Transaction tx, FirebaseFirestore db, String patient, String clinic, List<String> ids) async {
    if (ids.toSet().length != ids.length || ids.length > 8) throw StateError('Selecione até 8 Tags distintas por atendimento.');
    final parent = await tx.get(db.collection('patients').doc(patient));
    if (parent.data()?['clinicId'] != clinic) throw StateError('Paciente de outra unidade.');
    final result = <Map<String, dynamic>>[];
    for (final id in ids) {
      final ref = db.collection('patients').doc(patient).collection('procedure_tags').doc(id);
      final s = await tx.get(ref); final d = s.data();
      if (d == null || d['clinicId'] != clinic || d['patientId'] != patient || !['pending','in_progress'].contains(d['status'])) throw StateError('Tag indisponível ou já concluída. Atualize a consulta.');
      result.add({...d, 'id': id});
    }
    final plans = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final tag in result) {
      final planId = '${tag['planId'] ?? ''}';
      if (planId.isEmpty) throw StateError('Tag sem plano.');
      if (!plans.containsKey(planId)) plans[planId] = await tx.get(db.collection('treatment_plans').doc(planId));
      final plan = plans[planId]!.data();
      final index = tag['lineIndex'];
      final items = plan?['items'];
      if (plan == null || plan['clinicId'] != clinic || plan['patientId'] != patient || plan['status'] != 'active' || index is! int || items is! List || index < 0 || index >= items.length || items[index] is! Map) throw StateError('Plano ou etapa da Tag indisponível.');
      final item = items[index] as Map;
      if (tag['id'] != patientTagId('${tag['budgetId']}', index) || (plan['budgetId'] != null && plan['budgetId'] != tag['budgetId']) || item['name'] != tag['name'] || (item['procedureId'] != null && '${item['procedureId']}'.isNotEmpty && '${item['procedureId']}' != '${tag['procedureId']}') || ['completed','concluido','concluído','done'].contains('${item['status']}'.toLowerCase())) throw StateError('A etapa do procedimento mudou ou já foi concluída.');
      if (item['procedureTagId'] != null && item['procedureTagId'] != tag['id']) throw StateError('A etapa mudou de Tag.');
      tag['_planDoc'] = plans[planId];
    }
    return result;
  }
}

// Stable comparison of snapshots regardless of Map insertion order.
String tagSnapshotKey(dynamic v) {
  if (v is Map) { final keys = v.keys.map((k) => k.toString()).toList()..sort(); return keys.map((k) => '$k:${tagSnapshotKey(v[k])}').join('|'); }
  if (v is List) return '[${v.map(tagSnapshotKey).join(';')}]';
  return '${v.runtimeType}:$v';
}
