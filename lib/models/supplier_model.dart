class SupplierModel {
  final String id;
  final String clinicId;
  final String name;
  final String taxId; // CPF ou CNPJ
  final String phone;
  final String category; // Ex: "Laboratório", "Serviços Gerais", "Impostos"
  final bool isProfessional; // Se true, é um dentista/médico da clínica (para comissões)

  SupplierModel({
    required this.id,
    required this.clinicId,
    required this.name,
    this.taxId = '',
    this.phone = '',
    required this.category,
    this.isProfessional = false,
  });

  factory SupplierModel.fromMap(String id, Map<String, dynamic> map) {
    return SupplierModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      name: map['name'] ?? 'Sem Nome',
      taxId: map['taxId'] ?? '',
      phone: map['phone'] ?? '',
      category: map['category'] ?? 'Geral',
      isProfessional: map['isProfessional'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'name': name,
      'taxId': taxId,
      'phone': phone,
      'category': category,
      'isProfessional': isProfessional,
    };
  }
}