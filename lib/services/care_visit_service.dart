import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import 'care_workflow.dart';
import 'portal_mirror.dart';
import 'session_manager.dart';
import 'procedure_tags.dart';

/// Rascunho por operador dentro do agendamento e evolução formal idempotente.
/// Toda escrita valida novamente clínica/paciente em transação.
class CareVisitService {
  final FirebaseFirestore _db;
  final String? _operatorId = SessionManager().userId;
  CareVisitService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  String _uid() {
    final uid = SessionManager().userId;
    if (uid == null || uid.isEmpty || uid != _operatorId) {
      throw StateError('Sessão inválida ou alterada.');
    }
    return uid;
  }

  String recordId(String appointmentId) => 'care_$appointmentId';

  Future<void> saveDraft(
    AppointmentModel a, {
    required String text,
    required List<String> markers,
    Map<String, bool>? procedureTags,
  }) async {
    final uid = _uid();
    final ref = _db.collection('appointments').doc(a.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      validateCareScope(a, snap.data(), SessionManager().currentClinicId);
      if (snap.data()?['status'] == 'Finalizado') {
        throw StateError('Atendimento já finalizado.');
      }
      tx.update(ref, {
        FieldPath(['careDrafts', uid]): {
          'text': text,
          'markers': markers,
          if (procedureTags != null) 'procedureTags': procedureTags,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    });
  }

  Future<void> saveEvolution(
    AppointmentModel a, {
    required String description,
    required bool psychology,
    bool finalize = false,
    Map<String, bool>? procedureTags,
  }) async {
    if (description.trim().isEmpty) {
      throw StateError('Descreva a evolução antes de salvar.');
    }
    final uid = _uid();
    final ref = _db.collection('appointments').doc(a.id);
    final record = _db.collection('clinical_records').doc(recordId(a.id));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      validateCareScope(a, snap.data(), SessionManager().currentClinicId);
      if (snap.data()?['status'] == 'Finalizado') {
        throw StateError('Atendimento já finalizado; consulte o prontuário.');
      }
      final decisions = finalize && !psychology
          ? (procedureTags ?? {for (final id in (snap.data()?['procedureTagIds'] as List? ?? []).whereType<String>()) id: false})
          : <String, bool>{};
      final tags = decisions.isEmpty ? <Map<String, dynamic>>[] : await ProcedureTags.readForVisit(tx, _db, a.patientId, a.clinicId, decisions.keys.toList());
      final plans = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final tag in tags) {
        final id = '${tag['planId'] ?? ''}';
        if (id.isEmpty) throw StateError('Tag sem plano de origem.');
        if (!plans.containsKey(id)) plans[id] = tag['_planDoc'] as DocumentSnapshot<Map<String, dynamic>>;
        final p = plans[id]!.data();
        if (p == null || p['clinicId'] != a.clinicId || p['patientId'] != a.patientId || p['status'] != 'active') throw StateError('Plano indisponível. Atualize as Tags.');
      }
      String? professionalName;
      if (a.dentistId != null && a.dentistId!.isNotEmpty) {
        final member = await tx.get(_db.collection('clinics').doc(a.clinicId).collection('members').doc(a.dentistId));
        professionalName = member.data()?['name']?.toString();
      }
      final tagSnapshots = <Map<String, dynamic>>[];
      for (final tag in tags) {
        final id = '${tag['id']}';
        final completed = decisions[id] == true;
        tx.update(_db.collection('patients').doc(a.patientId).collection('procedure_tags').doc(id), {
          'status': completed ? 'completed' : 'in_progress',
          'sessionCount': FieldValue.increment(1), 'lastAppointmentId': a.id,
          'lastAttendedAt': Timestamp.fromDate(a.date), 'lastProfessionalId': a.dentistId, 'lastOperatorId': uid, 'updatedAt': FieldValue.serverTimestamp(),
          if (completed) 'completedAt': FieldValue.serverTimestamp(),
        });
        tagSnapshots.add({'id': id, 'name': tag['name'], 'planId': tag['planId'], 'budgetId': tag['budgetId'], 'lineIndex': tag['lineIndex'], 'completed': completed});
      }
      for (final entry in plans.entries) {
        final items = (entry.value.data()?['items'] as List? ?? []).map((v) => Map<String, dynamic>.from(v as Map)).toList();
        for (final tag in tags.where((t) => t['planId'] == entry.key)) {
          final index = tag['lineIndex'];
          if (index is! int || index < 0 || index >= items.length) throw StateError('Etapa do plano inválida.');
          if (items[index]['procedureTagId'] != null && items[index]['procedureTagId'] != tag['id']) throw StateError('Vínculo de etapa alterado.');
          items[index]['procedureTagId'] = tag['id'];
          items[index]['status'] = decisions[tag['id']] == true ? 'completed' : 'em_andamento';
        }
        tx.update(entry.value.reference, {'items': items});
      }
      if (finalize && !psychology) {
        tx.set(_db.collection('patients').doc(a.patientId).collection('clinical_data').doc('tag_visit_${a.id}'), {
          'clinicId': a.clinicId, 'patientId': a.patientId, 'appointmentId': a.id,
          'tags': tagSnapshots, 'description': description.trim(), 'operatorId': uid,
          'professionalId': a.dentistId, 'date': Timestamp.fromDate(a.date), 'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(record, {
        'clinicId': a.clinicId,
        'patientId': a.patientId,
        'patientName': a.patientName,
        'appointmentId': a.id,
        'procedureTags': tagSnapshots,
        'planId': a.planId,
        'scheduleId': a.scheduleId,
        'treatmentId': null,
        'procedureName': a.procedure,
        'description': description.trim(),
        'careType': psychology ? 'psychology' : 'dental',
        'authorId': uid,
        'dentistId': a.dentistId,
        'dentistName': professionalName ?? 'Profissional não informado',
        'operatorName': SessionManager().userName ?? 'Operador não informado',
        'date': Timestamp.fromDate(a.date),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.update(ref, {
        FieldPath(['careDrafts', uid]): FieldValue.delete(),
        'careEvolutionSavedAt': FieldValue.serverTimestamp(),
        'careEvolutionId': record.id,
        if (finalize) ...{
          'status': 'Finalizado',
          if (!psychology) 'procedureTagIds': decisions.keys.toList(),
          'attendanceStatus': 'Attended',
          'hasMedicalCertificate': false,
          'careFinishedAt': FieldValue.serverTimestamp(),
        },
      });
    });
    if (finalize) {
      try {
        await PortalMirrorSync.upsertSession(
          patientId: a.patientId,
          session: {
            'id': a.id,
            'date': a.date,
            'dentistId': a.dentistId ?? '',
            'professional': '',
            'status': 'Finalizado',
          },
        );
      } catch (error) {
        debugPrint('Evolução salva; atualização do portal pendente: $error');
      }
    }
  }

  Future<void> changeStatus(AppointmentModel a, String status) async {
    _uid();
    if (!const {'Em Atendimento', 'Pausado'}.contains(status)) {
      throw ArgumentError('Status de atendimento inválido.');
    }
    final ref = _db.collection('appointments').doc(a.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      validateCareScope(a, snap.data(), SessionManager().currentClinicId);
      if (snap.data()?['status'] == 'Finalizado') {
        throw StateError('Atendimento já finalizado.');
      }
      tx.update(ref, {'status': status});
    });
  }
}
