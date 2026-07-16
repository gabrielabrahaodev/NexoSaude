import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
//import 'db_config.dart';

class ProductService {
  final CollectionReference _collection = FirebaseFirestore.instance.collection('inventory'); // ou DbConfig.inventory

  Stream<List<ProductModel>> getAllStream() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Retorna APENAS produtos que precisam de reposição
  Stream<List<ProductModel>> getLowStockStream() {
    // Nota: Firestore tem limitações para comparar dois campos (current <= min) na query.
    // Então filtramos no Dart. Para estoque pequeno/médio, isso é muito rápido.
    return getAllStream().map((list) => 
      list.where((p) => p.needsRestock).toList()
    );
  }

  Future<void> add(ProductModel product) async {
    await _collection.add(product.toMap());
  }

  Future<void> updateQuantity(String id, int newQuantity) async {
    await _collection.doc(id).update({'currentQuantity': newQuantity});
  }
}