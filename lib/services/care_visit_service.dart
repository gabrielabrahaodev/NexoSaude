import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import 'care_workflow.dart';
import 'portal_mirror.dart';
import 'session_manager.dart';

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
      tx.set(record, {
        'clinicId': a.clinicId,
        'patientId': a.patientId,
        'patientName': a.patientName,
        'appointmentId': a.id,
        'planId': a.planId,
        'scheduleId': a.scheduleId,
        'treatmentId': null,
        'procedureName': a.procedure,
        'description': description.trim(),
        'careType': psychology ? 'psychology' : 'dental',
        'authorId': uid,
        'dentistId': a.dentistId,
        'dentistName': SessionManager().userName ?? 'Profissional',
        'date': Timestamp.fromDate(a.date),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.update(ref, {
        FieldPath(['careDrafts', uid]): FieldValue.delete(),
        'careEvolutionSavedAt': FieldValue.serverTimestamp(),
        'careEvolutionId': record.id,
        if (finalize) ...{
          'status': 'Finalizado',
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
