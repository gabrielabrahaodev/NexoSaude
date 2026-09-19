import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';
import 'document_service.dart';
import 'session_manager.dart';

class PatientService {
  final CollectionReference<Map<String, dynamic>> _collection = 
      FirebaseFirestore.instance.collection('patients'); 

  // Referência para agendamentos (Necessária para o cálculo de risco)
  final CollectionReference<Map<String, dynamic>> _appointments =
      FirebaseFirestore.instance.collection('appointments');

  Stream<PatientModel?> getByIdStream(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PatientModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> update(PatientModel patient) async {
    await _collection.doc(patient.id).update(patient.toMap());
  }
  
  Future<void> add(PatientModel patient) async {
    await _collection.add(patient.toMap());
  }

  // --- CÁLCULO DE ASSIDUIDADE (RISCO) ---
  Future<Map<String, dynamic>> getPatientRiskProfile(String patientId) async {
    try {
      final snapshot = await SessionManager()
          .applyFilter(_appointments.where('patientId', isEqualTo: patientId))
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) return {'level': 'green', 'missed': 0};

      int total = snapshot.docs.length;
      int missed = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Falta com atestado não conta como falta (docs antigos sem o campo caem em false).
        final bool excused =
            '${data['hasMedicalCertificate']}'.toLowerCase() == 'true';
        bool isNoShow =
            data['attendanceStatus'] == 'Missed' && !excused;
        bool cancelledByPatient =
            '${data['status']}'.toLowerCase() == 'cancelado' &&
                data['cancellationSource'] == 'Paciente';
        if (isNoShow || cancelledByPatient) missed++;
      }

      double rate = total > 0 ? (missed / total) : 0.0;
      
      if (rate >= 0.3 || missed >= 3) { 
        return {'level': 'red', 'missed': missed}; 
      } else if (rate >= 0.1) {
        return {'level': 'yellow', 'missed': missed};
      } else {
        return {'level': 'green', 'missed': missed};
      }
    } catch (e) {
      return {'level': 'green', 'missed': 0};
    }
  }
  
  Stream<List<PatientModel>> getAllStream() {
    return SessionManager()
        .applyFilter(_collection)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PatientModel.fromMap(d.id, d.data()))
            .toList());
  }

  static const _cascadeCollections = [
    'appointments',
    'budgets',
    'treatments',
    'treatment_plans',
    'financial',
    'clinical_records',
    'lab_orders',
    'psychology_schedules',
  ];

  // Subcoleções reais do paciente ('docs' = uploads via DocumentService;
  // 'clinical_data' guarda o doc 'odontogram').
  static const _patientSubcollections = [
    'clinical_data',
    'docs',
  ];

  // --- EXCLUSÃO EM CASCATA DO PACIENTE ---
  // Ordem: coleta deletes → commit em blocos de 450 → SÓ ENTÃO purge remoto.
  // (Purge antes do commit apagava arquivos irreversíveis mesmo se o commit
  // estourasse o limite de 500 writes do batch.)
  Future<void> deletePatientCascade(String patientId, String clinicId) async {
    final db = FirebaseFirestore.instance;
    final deletes = <DocumentReference>[];
    List<Map<String, dynamic>> docsMeta = [];

    for (final collection in _cascadeCollections) {
      final snap = await db
          .collection(collection)
          .where('patientId', isEqualTo: patientId)
          .where('clinicId', isEqualTo: clinicId)
          .get();
      for (final doc in snap.docs) {
        deletes.add(doc.reference);
      }
    }

    // Subcoleções do paciente (clinical_data/odontogram, uploads).
    final patientRef = _collection.doc(patientId);
    for (final sub in _patientSubcollections) {
      final subDocs = await patientRef.collection(sub).get();
      if (sub == 'docs') {
        docsMeta = subDocs.docs.map((d) => d.data()).toList();
      }
      for (final doc in subDocs.docs) {
        deletes.add(doc.reference);
      }
    }

    // Anamnese pública (doc top-level `anamnesis/{patientId}`, fora do paciente)
    deletes.add(db.collection('anamnesis').doc(patientId));

    // Finalmente, o próprio paciente
    deletes.add(patientRef);

    // Commit em blocos de 450 (limite do batch = 500)
    var batch = db.batch();
    var count = 0;
    for (final ref in deletes) {
      batch.delete(ref);
      count++;
      if (count >= 450) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();

    // 'docs' tem limpeza remota no Cloudinary SÓ após o commit OK.
    await DocumentService().purgePatientFiles(
      clinicId: clinicId,
      docs: docsMeta,
    );
  }
}