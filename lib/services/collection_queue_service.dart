import '../utils/display.dart' show parseBRL;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/collection_queue.dart';
import 'clinical_record_service.dart';
import 'oracle_report_service.dart';
import 'session_manager.dart';

/// The aggregate view uses an explicit clinicId for EVERY operational query.
/// It never uses SessionManager's unbounded owner/ALL query or changes the shell unit.
class CollectionQueueService {
  CollectionQueueService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  final Set<String> _authorized = {};
  String? _user;

  Future<List<CollectionClinic>> clinics() async {
    final session = SessionManager();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || session.userId != uid) {
      throw StateError('Sessão não inicializada.');
    }
    final profile = await _db.collection('users').doc(uid).get();
    if (!profile.exists ||
        profile.data()?['status'] == 'blocked' ||
        profile.data()?['status'] == 'inactive') {
      throw StateError('Usuário indisponível.');
    }
    final data = profile.data()!;
    final raw = data['allowedClinics'];
    final ids = <String>{
      if (raw is List) ...raw.whereType<String>(),
      if (data['clinicId'] is String) data['clinicId'] as String,
      if (data['role'] == 'superadmin' &&
          session.currentClinicId != null &&
          session.currentClinicId != 'ALL')
        session.currentClinicId!,
    };
    final docs = <String, Map<String, dynamic>>{};
    if (data['role'] == 'owner') {
      final owned = await _db
          .collection('clinics')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (final d in owned.docs) {
        docs[d.id] = d.data();
        ids.remove(d.id);
      }
    }
    // Direct gets are checked individually by Rules; no global clinics enumeration.
    for (final id in ids.where((id) => id.isNotEmpty && id != 'ALL')) {
      final d = await _db.collection('clinics').doc(id).get();
      if (d.exists) docs[d.id] = d.data()!;
    }
    if (SessionManager().userId != uid) {
      throw StateError('A sessão foi alterada.');
    }
    docs.removeWhere((id, m) {
      final trial = reportDate(m['trialEndsAt']);
      return data['role'] != 'superadmin' &&
          (m['blockedByAdmin'] == true ||
              (trial != null && !trial.isAfter(DateTime.now())));
    });
    _user = uid;
    _authorized
      ..clear()
      ..addAll(docs.keys);
    final result = [
      for (final e in docs.entries) CollectionClinic.fromMap(e.key, e.value),
    ];
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  void _guard(String clinic) {
    if (_user == null ||
        SessionManager().userId != _user ||
        FirebaseAuth.instance.currentUser?.uid != _user ||
        !_authorized.contains(clinic)) {
      throw StateError('Unidade não autorizada ou sessão alterada.');
    }
  }

  Stream<CollectionQueue> watch(
    List<CollectionClinic> clinics,
    DateTime month,
  ) async* {
    if (clinics.isEmpty) {
      yield CollectionQueue(clinics: [], charges: []);
      return;
    }
    final start = DateTime(month.year, month.month),
        end = DateTime(month.year, month.month + 1);
    final streams = <Stream<QuerySnapshot>>[];
    final kinds = <String>[];
    void add(String kind, Query<Map<String, dynamic>> q) {
      kinds.add(kind);
      streams.add(q.snapshots());
    }

    for (final clinic in clinics) {
      _guard(clinic.id);
      Query<Map<String, dynamic>> scope(String collection) =>
          _db.collection(collection).where('clinicId', isEqualTo: clinic.id);
      for (final field in ['dueDate', 'date', 'paymentDate', 'paidDate']) {
        add(
          'financial',
          scope('financial')
              .where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where(field, isLessThan: Timestamp.fromDate(end)),
        );
      }
      if (clinic.psychology) {
        add(
          'financial',
          scope(
            'financial',
          ).where('monthlyPeriod', isEqualTo: collectionPeriod(month)),
        );
      }
      add('patients', scope('patients'));
      if (clinic.psychology) {
        add(
          'appointments',
          scope('appointments')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where('date', isLessThan: Timestamp.fromDate(end)),
        );
        add('plans', scope('treatment_plans'));
      }
    }
    yield* StreamCombiner.combineDocs(streams).map((lists) {
      for (final c in clinics) {
        _guard(c.id);
      }
      List<ReportDocument> docs(String kind) => [
        for (var i = 0; i < lists.length; i++)
          if (kinds[i] == kind)
            for (final d in lists[i])
              ReportDocument(d.id, d.data() as Map<String, dynamic>),
      ];
      return CollectionQueue.build(
        clinics: clinics,
        month: month,
        financial: docs('financial'),
        patients: docs('patients'),
        appointments: docs('appointments'),
        plans: docs('plans'),
        now: DateTime.now(),
      );
    });
  }

  /// Fresh financial snapshots are checked before contact/reschedule. No payment fields change.
  Future<void> _write(
    CollectionCharge charge, {
    String? message,
    DateTime? nextContact,
    bool preparePayment = false,
    required String eventId,
  }) async {
    _guard(charge.clinic.id);
    if (charge.issue != null ||
        charge.amount <= 0 ||
        charge.documents.isEmpty ||
        charge.documents.length > 400) {
      throw StateError('Cobrança indisponível. Atualize a fila.');
    }
    final uid = _user;
    final patientRef = _db.collection('patients').doc(charge.patientId);
    final recordRef = _db.collection('clinical_records').doc(eventId);
    // Existing patient clinical_data Rules permit get of an absent receipt.
    final receiptRef = patientRef
        .collection('clinical_data')
        .doc('collection_$eventId');
    await _db.runTransaction((tx) async {
      _guard(charge.clinic.id);
      final patient = await tx.get(patientRef);
      if (!patient.exists || patient.data()?['clinicId'] != charge.clinic.id) {
        throw StateError('Paciente de outra unidade.');
      }
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final d in charge.documents) {
        snaps.add(await tx.get(_db.collection('financial').doc(d.id)));
      }
      final previous = await tx.get(receiptRef);
      if (previous.exists) {
        if (previous.data()?['clinicId'] != charge.clinic.id ||
            previous.data()?['patientId'] != charge.patientId ||
            previous.data()?['message'] != message) {
          throw StateError('Confirmação inválida.');
        }
        return; // Same confirmation retried after uncertain network result.
      }
      for (var i = 0; i < snaps.length; i++) {
        validateCollectionWrite(
          charge,
          charge.documents[i].data,
          snaps[i].data(),
        );
      }
      if ((message != null || preparePayment) && charge.bill != null) {
        for (final source in charge.billingSessions) {
          final current = await tx.get(
            _db.collection('appointments').doc(source.id),
          );
          validateCollectionSource(source.data, current.data(), plan: false);
        }
        final plan = charge.billingPlan;
        if (plan != null) {
          final current = await tx.get(
            _db.collection('treatment_plans').doc(plan.id),
          );
          validateCollectionSource(plan.data, current.data(), plan: true);
        }
      }
      if (uid != SessionManager().userId) throw StateError('Sessão alterada.');
      final now = DateTime.now();
      for (var i = 0; i < snaps.length; i++) {
        final original = charge.documents[i].data;
        final contact = <String, dynamic>{
          'eventId': eventId,
          'date': now.toIso8601String(),
          'method': preparePayment
              ? 'package_apuration'
              : message == null
              ? 'manual_reschedule'
              : charge.isPackage
              ? 'whatsapp_monthly_package'
              : 'whatsapp_manual',
          'operatorId': uid,
          if (message != null) 'confirmed': true,
          if (nextContact != null)
            'nextContactAt': nextContact.toIso8601String(),
        };
        tx.update(snaps[i].reference, {
          if (message != null) 'status': 'cobrado',
          if (message != null) 'lastContactDate': Timestamp.fromDate(now),
          if (message != null) 'nextContactAt': FieldValue.delete(),
          if (nextContact != null)
            'nextContactAt': Timestamp.fromDate(nextContact),
          // Apply the reviewed presence calculation once, preserving the original face value.
          // This is apuration of the charge, never a payment or settlement.
          if ((message != null || preparePayment) &&
              charge.isPackage &&
              charge.bill != null)
            ...collectionApurationPatch(charge, original, now),
          'contactHistory': FieldValue.arrayUnion([contact]),
        });
      }
      tx.set(receiptRef, {
        'clinicId': charge.clinic.id,
        'patientId': charge.patientId,
        'message': message,
        'eventId': eventId,
        'at': Timestamp.fromDate(now),
        'financialIds': charge.documents.map((d) => d.id).toList(),
      });
      if (message != null) {
        tx.set(recordRef, {
          ...ClinicalRecordService.whatsappChargeRecord(
            clinicId: charge.clinic.id,
            patientId: charge.patientId,
            patientName: charge.patientName,
            message: message,
            operatorName: SessionManager().userName ?? 'Operador',
            at: now,
          ),
          'collectionEventId': eventId,
          'financialIds': charge.documents.map((d) => d.id).toList(),
        });
      }
    });
  }

  Future<void> validateBeforeSend(
    CollectionCharge charge, {
    bool checkContact = true,
  }) async {
    _guard(charge.clinic.id);
    final period = charge.monthlyPeriod;
    final month = period == null
        ? charge.dueDate
        : DateTime.tryParse('$period-01');
    if (month == null) throw StateError('Competência ausente.');
    final snapshot = await watch([
      charge.clinic,
    ], month).first.timeout(const Duration(seconds: 12));
    final fresh = snapshot.charges
        .where((c) => c.key == charge.key)
        .firstOrNull;
    if (fresh == null ||
        (checkContact && !fresh.canContact(DateTime.now())) ||
        fresh.issue != null ||
        fresh.amount != charge.amount ||
        fresh.phone != charge.phone ||
        fresh.description != charge.description ||
        fresh.patientName != charge.patientName ||
        fresh.documents.length != charge.documents.length) {
      throw StateError('A cobrança mudou. Atualize a fila.');
    }
    for (final d in charge.documents) {
      final updated = fresh.documents.where((n) => n.id == d.id).firstOrNull;
      validateCollectionWrite(charge, d.data, updated?.data);
    }
  }

  Future<void> preparePayment(CollectionCharge charge) async {
    if (!charge.isPackage || charge.bill == null) return;
    await validateBeforeSend(charge, checkContact: false);
    await _write(charge, preparePayment: true, eventId: newEventId());
  }

  String newEventId() => _db.collection('clinical_records').doc().id;
  Future<void> confirmSent(
    CollectionCharge charge,
    String message,
    String eventId,
  ) => _write(charge, message: message, eventId: eventId);
  Future<void> reschedule(CollectionCharge charge, DateTime when) {
    if (!when.isAfter(DateTime.now())) {
      throw ArgumentError('Selecione uma data futura.');
    }
    return _write(charge, nextContact: when, eventId: newEventId());
  }
}

void validateCollectionWrite(
  CollectionCharge charge,
  Map<String, dynamic> expected,
  Map<String, dynamic>? current,
) {
  if (current == null ||
      current['clinicId'] != charge.clinic.id ||
      current['patientId'] != charge.patientId ||
      !collectionPending(current)) {
    throw StateError(
      'Cobrança quitada, cancelada ou de outra unidade. Atualize a fila.',
    );
  }
  for (final key in [
    'amount',
    'paidAmount',
    'status',
    'planId',
    'monthlyPeriod',
    'billingKind',
    'lastContactDate',
    'nextContactAt',
    'billingRatedAmount',
    'dueDate',
    'title',
    'description',
  ]) {
    if (current[key] != expected[key]) {
      throw StateError('A cobrança mudou. Atualize a fila antes de continuar.');
    }
  }
}

double collectionQuoteShare(CollectionCharge charge, Map<String, dynamic> doc) {
  final weights = charge.documents
      .map((d) => parseBRL(d.data['amount']))
      .toList();
  final total = weights.fold<double>(0, (a, b) => a + b);
  if (total <= 0) throw StateError('Valor inválido.');
  final target = charge.documents.indexWhere((d) => identical(d.data, doc));
  if (target < 0) throw StateError('Lançamento inválido.');
  final cents = (charge.amount * 100).round();
  var assigned = 0;
  for (var i = 0; i < weights.length; i++) {
    final portion = i == weights.length - 1
        ? cents - assigned
        : (cents * weights[i] / total).floor();
    if (i == target) return portion / 100;
    assigned += portion;
  }
  throw StateError('Lançamento inválido.');
}

Map<String, dynamic> collectionApurationPatch(
  CollectionCharge charge,
  Map<String, dynamic> doc,
  DateTime now,
) {
  if (!charge.isPackage ||
      charge.bill == null ||
      doc['billingRatedAmount'] != null ||
      doc['billingOriginalAmount'] != null ||
      !collectionPending(doc)) {
    throw StateError('Apuração inválida.');
  }
  final value = collectionQuoteShare(charge, doc);
  return {
    'amount': value,
    'billingOriginalAmount': doc['amount'],
    'billingRatedAmount': value,
    'billingAppliedAt': Timestamp.fromDate(now),
    'billingPeriod': charge.monthlyPeriod,
  };
}

void validateCollectionSource(
  Map<String, dynamic> expected,
  Map<String, dynamic>? current, {
  required bool plan,
}) {
  if (current == null) throw StateError('Fonte da apuração foi removida.');
  final fields = plan
      ? ['clinicId', 'patientId', 'thirdPartyDiscount', 'status']
      : [
          'clinicId',
          'patientId',
          'planId',
          'monthlyPeriod',
          'date',
          'status',
          'attendanceStatus',
          'hasMedicalCertificate',
        ];
  for (final key in fields) {
    if (expected[key] != current[key]) {
      throw StateError('A presença ou o desconto mudou. Atualize a apuração.');
    }
  }
}
