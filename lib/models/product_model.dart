class ProductModel {
  final String id;
  final String name;
  final int currentQuantity;
  final int minQuantity; // Quantidade mínima segura
  final double costPrice;
  final String unit; // 'un', 'cx', 'ml'

  ProductModel({
    required this.id,
    required this.name,
    required this.currentQuantity,
    required this.minQuantity,
    required this.costPrice,
    this.unit = 'un',
  });

  // --- LÓGICA INTELIGENTE ---

  // Precisa repor estoque?
  bool get needsRestock => currentQuantity <= minQuantity;

  // Valor total parado em estoque
  double get totalStockValue => currentQuantity * costPrice;

  // --- SERIALIZAÇÃO ---

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['name'] ?? 'Produto',
      currentQuantity: map['currentQuantity'] ?? 0,
      minQuantity: map['minQuantity'] ?? 5,
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? 'un',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'currentQuantity': currentQuantity,
      'minQuantity': minQuantity,
      'costPrice': costPrice,
      'unit': unit,
    };
  }
}