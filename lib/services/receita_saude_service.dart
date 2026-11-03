import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receita_saude_report.dart';
import 'oracle_report_service.dart';
import 'session_manager.dart';

class ReceitaSaudeData {
  const ReceitaSaudeData(this.rows, this.professionals);
  final List<ReceitaSaudeLine> rows;
  final Map<String, Map<String, dynamic>> professionals;
}

class ReceitaSaudeService {
  Future<ReceitaSaudeData> load(DateTime month, String clinic) async {
    final session = SessionManager();
    final db = FirebaseFirestore.instance;
    void check() {
      if (session.currentClinicId != clinic) {
        throw StateError('Unidade alterada. Reabra o relatório.');
      }
    }

    check();
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final snaps = await Future.wait(
      ['paymentDate', 'paidDate', 'date'].map(
        (field) => session
            .applyFilter(db.collection('financial'))
            .where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where(field, isLessThan: Timestamp.fromDate(end))
            .get(),
      ),
    );
    check();
    final rows = receitaSaudeLines(month, [
      for (final snap in snaps)
        for (final d in snap.docs) ReportDocument(d.id, d.data()),
    ]);
    final patients = <String, Map<String, dynamic>>{};
    await Future.wait(
      rows.map((r) => r.patientId).where((id) => id.isNotEmpty).toSet().map((
        id,
      ) async {
        final result = await session
            .applyFilter(db.collection('patients'))
            .where(FieldPath.documentId, isEqualTo: id)
            .get();
        if (result.docs.isNotEmpty) patients[id] = result.docs.single.data();
      }),
    );
    check();
    for (final row in rows) {
      if (row.beneficiaryCpf.trim().isEmpty) {
        row.beneficiaryCpf = '${patients[row.patientId]?['cpf'] ?? ''}';
      }
    }
    final profiles = <String, Map<String, dynamic>>{};
    if (session.isOwner || session.userRole == 'superadmin') {
      final private = await db
          .collection('clinics')
          .doc(clinic)
          .collection('members_private')
          .get();
      for (final d in private.docs) {
        profiles[d.id] = d.data();
      }
    }
    if (session.userId != null &&
        rows.any((r) => r.professionalId == session.userId)) {
      final own = await db.collection('users').doc(session.userId).get();
      if (own.exists) profiles[own.id] = {...?profiles[own.id], ...own.data()!};
    }
    check();
    return ReceitaSaudeData(rows, profiles);
  }
}
