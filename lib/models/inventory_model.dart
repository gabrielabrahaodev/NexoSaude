class InventoryModel {
  final String id;
  final String clinicId;
  final String name;
  final int currentQty;
  final int minQty; // Ponto de reposição
  final String unit; // 'un', 'cx', 'ml'
  
  InventoryModel({
    required this.id,
    required this.clinicId,
    required this.name,
    required this.currentQty,
    required this.minQty,
    required this.unit,
  });

  // Lógica Inteligente: Precisa comprar?
  bool get isLowStock => currentQty <= minQty;

  factory InventoryModel.fromMap(String id, Map<String, dynamic> map) {
    return InventoryModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      name: map['name'] ?? 'Item',
      currentQty: map['currentQty'] ?? 0,
      minQty: map['minQty'] ?? 5,
      unit: map['unit'] ?? 'un',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'name': name,
      'currentQty': currentQty,
      'minQty': minQty,
      'unit': unit,
    };
  }
}