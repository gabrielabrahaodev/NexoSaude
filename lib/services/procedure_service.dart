import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/procedure_model.dart';
import 'session_manager.dart';
import 'procedure_tags.dart';

class ProcedureService {
  // CORREÇÃO: Tipagem forte para evitar erro de Object? vs Map
  final CollectionReference<Map<String, dynamic>> _collection = 
      FirebaseFirestore.instance.collection('procedures');

  Stream<List<ProcedureModel>> getAllStream() {
    // A query agora nasce tipada corretamente
    Query<Map<String, dynamic>> query = _collection.orderBy('name');
    
    // O SessionManager aceita pois os tipos batem
    query = SessionManager().applyFilter(query);
    
    return query.snapshots().map((s) => 
      s.docs.map((d) => ProcedureModel.fromMap(d.id, d.data())).toList()
    );
  }

  Future<void> save(ProcedureModel model) async {
    if (model.clinicId != SessionManager().currentClinicId) throw StateError('Unidade alterada.');
    final ref = model.id.isEmpty ? _collection.doc() : _collection.doc(model.id);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(ref, model.toMap(), SetOptions(merge: true));
    batch.set(ref.collection('tags').doc('definition'), {
      ...procedureTagDefinition(model.toMap(), ref.id), 'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}