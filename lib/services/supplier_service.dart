import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier_model.dart';
import 'session_manager.dart';

class SupplierService {
  final CollectionReference<Map<String, dynamic>> _collection = 
      FirebaseFirestore.instance.collection('suppliers');

  // Busca todos os fornecedores da clínica atual
  Stream<List<SupplierModel>> getAllStream() {
    Query<Map<String, dynamic>> query = _collection.orderBy('name');
    
    // Filtro de isolamento por Clínica (Multi-Tenant)
    query = SessionManager().applyFilter(query);
    
    return query.snapshots().map((s) => 
      s.docs.map((d) => SupplierModel.fromMap(d.id, d.data())).toList()
    );
  }

  // Salva (Cria ou Atualiza)
  Future<void> save(SupplierModel model) async {
    if (model.id.isEmpty) {
      await _collection.add(model.toMap());
    } else {
      await _collection.doc(model.id).update(model.toMap());
    }
  }

  // Busca um fornecedor específico (útil para detalhes)
  Future<SupplierModel?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return SupplierModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}