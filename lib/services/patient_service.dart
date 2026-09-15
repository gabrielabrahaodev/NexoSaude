import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';

class PatientService {
  final CollectionReference<Map<String, dynamic>> _collection = 
      FirebaseFirestore.instance.collection('patients'); 

  // Referência para agendamentos (Necessária para o cálculo de risco)
  final CollectionReference _appointments = 
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
      final snapshot = await _appointments
          .where('patientId', isEqualTo: patientId)
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
        bool cancelledByPatient = data['status'] == 'Cancelado' && data['cancellationSource'] == 'Paciente';
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
    return _collection.snapshots().map((s) => 
      s.docs.map((d) => PatientModel.fromMap(d.id, d.data())).toList()
    );
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

  static const _patientSubcollections = [
    'odontogram',
    'anamnesis',
    'documents',
    'photos',
  ];

  // --- EXCLUSÃO EM CASCATA DO PACIENTE ---
  Future<void> deletePatientCascade(String patientId, String clinicId) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    for (final collection in _cascadeCollections) {
      final snap = await db
          .collection(collection)
          .where('patientId', isEqualTo: patientId)
          .where('clinicId', isEqualTo: clinicId)
          .get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    // Subcoleções do paciente (Odontograma, Anamnese, etc.)
    final patientRef = _collection.doc(patientId);
    for (final sub in _patientSubcollections) {
      final subDocs = await patientRef.collection(sub).get();
      for (final doc in subDocs.docs) {
        batch.delete(doc.reference);
      }
    }

    // Finalmente, deleta o próprio paciente
    batch.delete(patientRef);

    await batch.commit();
  }
}