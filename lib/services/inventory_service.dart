import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_model.dart';
import 'session_manager.dart';

class InventoryService {
  // CORREÇÃO: Tipagem forte
  final CollectionReference<Map<String, dynamic>> _collection = 
      FirebaseFirestore.instance.collection('inventory');

  Stream<List<InventoryModel>> getAllStream() {
    Query<Map<String, dynamic>> query = _collection.orderBy('name');
    query = SessionManager().applyFilter(query);
    
    return query.snapshots().map((s) => 
      s.docs.map((d) => InventoryModel.fromMap(d.id, d.data())).toList()
    );
  }

  Future<void> save(InventoryModel model) async {
    if (model.id.isEmpty) {
      await _collection.add(model.toMap());
    } else {
      await _collection.doc(model.id).update(model.toMap());
    }
  }

  // Método atômico para entrada/saída rápida (+1 / -1)
  Future<void> adjustQuantity(String id, int amount) async {
    await _collection.doc(id).update({
      'currentQty': FieldValue.increment(amount)
    });
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}