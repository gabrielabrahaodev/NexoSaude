import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_list_entry.dart';
import 'session_manager.dart';
import 'oracle_report_service.dart';

class PatientListService {
  final _db = FirebaseFirestore.instance;
  Stream<List<PatientListEntry>> patients() => SessionManager()
      .applyFilter(_db.collection('patients'))
      .snapshots()
      .map((s) => [for (final d in s.docs) PatientListEntry(d.id, d.data())]);
  Stream<PatientListContext> context(String clinic) async* {
    if (SessionManager().currentClinicId != clinic) return;
    final now = DateTime.now();
    Query<Map<String, dynamic>> query(String collection) =>
        SessionManager().applyFilter(_db.collection(collection));
    final streams = <Stream<QuerySnapshot>>[
      query('financial')
          .where('status', whereIn: ['pendente', 'pending', 'Pendente'])
          .snapshots(),
      query('financial').where('isPaid', isEqualTo: false).snapshots(),
      query('treatment_plans').where('status', isEqualTo: 'active').snapshots(),
      for (final status in ['Pendente', 'pendente', 'pending'])
        query('budgets').where('status', isEqualTo: status).snapshots(),
      query('appointments')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              now.subtract(const Duration(days: 90)),
            ),
          )
          .where(
            'date',
            isLessThanOrEqualTo: Timestamp.fromDate(
              now.add(const Duration(days: 90)),
            ),
          )
          .snapshots(),
    ];
    List<ReportDocument> docs(List<QueryDocumentSnapshot> list) => [
      for (final d in list)
        ReportDocument(d.id, d.data() as Map<String, dynamic>),
    ];
    yield* StreamCombiner.combineDocs(streams).map(
      (lists) => PatientListContext.fromDocuments(
        financial: [...docs(lists[0]), ...docs(lists[1])],
        plans: docs(lists[2]),
        quotes: [for (final l in lists.sublist(3, 6)) ...docs(l)],
        appointments: docs(lists[6]),
        now: DateTime.now(),
      ),
    );
  }
}
