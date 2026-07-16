class ProcedureModel {
  final String id;
  final String clinicId;
  final String name;
  final String category;
  final double price;
  final bool active;
  
  // Flags de Comportamento
  final bool hasCost;            // Gera contas a pagar (Lab)
  final bool generatesMonthlyFee; // Gera recorrência (Orto)

  // NOVOS CAMPOS DE COMISSÃO
  final String commissionType; // 'percent' ou 'fixed'
  final double commissionValue; // Ex: 30.0 (se for %) ou 200.0 (se for fixo)

  ProcedureModel({
    required this.id,
    required this.clinicId,
    required this.name,
    required this.category,
    required this.price,
    this.active = true,
    this.hasCost = false,
    this.generatesMonthlyFee = false,
    this.commissionType = 'percent', // Padrão: Porcentagem
    this.commissionValue = 0.0,
  });

  factory ProcedureModel.fromMap(String id, Map<String, dynamic> map) {
    return ProcedureModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      name: map['name'] ?? 'Sem Nome',
      category: map['category'] ?? 'Geral',
      price: (map['price'] ?? 0.0).toDouble(),
      active: map['active'] ?? true,
      hasCost: map['hasCost'] ?? false,
      generatesMonthlyFee: map['generatesMonthlyFee'] ?? false,
      // Leitura segura dos novos campos
      commissionType: map['commissionType'] ?? 'percent',
      commissionValue: (map['commissionValue'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'name': name,
      'category': category,
      'price': price,
      'active': active,
      'hasCost': hasCost,
      'generatesMonthlyFee': generatesMonthlyFee,
      'commissionType': commissionType,
      'commissionValue': commissionValue,
    };
  }

  // Helper para exibir o texto formatado na tela
  String get formattedCommission {
    if (commissionValue == 0) return 'Sem repasse';
    if (commissionType == 'percent') {
      return '${commissionValue.toStringAsFixed(1)}%';
    } else {
      return 'R\$ ${commissionValue.toStringAsFixed(2)}';
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProcedureModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}