import 'package:cloud_firestore/cloud_firestore.dart';

class PatientModel {
  final String id;
  final String name;
  final String? phone;
  final String? cpf;
  final String? rg;
  final String? birthDate;
  final String? address; // Endereço sempre como Texto
  final DateTime createdAt;
  final String? clinicId; 
  final String? searchKey; 
  final String status;

  PatientModel({
    required this.id,
    required this.name,
    this.phone,
    this.cpf,
    this.rg,
    this.birthDate,
    this.address,
    required this.createdAt,
    this.clinicId,
    this.searchKey,
    this.status = 'Ativo',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'cpf': cpf,
      'rg': rg,
      'birthDate': birthDate,
      'address': address, // Gravamos sempre como String
      'createdAt': Timestamp.fromDate(createdAt),
      'clinicId': clinicId, 
      'searchKey': searchKey ?? name.toLowerCase(),
      'status': status,
    };
  }

  factory PatientModel.fromMap(String id, Map<String, dynamic> map) {
    
    // --- FUNÇÕES DE SEGURANÇA (BLINDAGEM) ---
    
    // 1. Tratamento seguro para o ENDEREÇO (Causa do erro LinkedMap)
    String? parseAddress(dynamic val) {
      if (val == null) return null;
      if (val is String) return val; // Se for texto, usa.
      if (val is Map) {
        // Se for Mapa, tenta pegar o campo interno ou converte tudo
        return val['full_address']?.toString() ?? val.toString();
      }
      return val.toString(); // Qualquer outra coisa vira texto
    }

    // 2. Tratamento seguro para DATA DE NASCIMENTO (Pode vir Timestamp ou String)
    String? parseBirthDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return val;
      if (val is Timestamp) {
        // Converte Timestamp para String no formato BR se necessário
        DateTime date = val.toDate();
        return "${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}";
      }
      return val.toString();
    }

    // 3. Tratamento seguro para DATA DE CRIAÇÃO
    DateTime parseCreatedAt(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return PatientModel(
      id: id,
      name: map['name']?.toString() ?? 'Sem Nome',
      phone: map['phone']?.toString(),
      cpf: map['cpf']?.toString(),
      rg: map['rg']?.toString(),
      
      // Usa as funções seguras
      birthDate: parseBirthDate(map['birthDate']),
      address: parseAddress(map['address']), 
      createdAt: parseCreatedAt(map['createdAt']),
      
      clinicId: map['clinicId']?.toString(),
      searchKey: map['searchKey']?.toString(),
      status: map['status']?.toString() ?? 'Ativo',
    );
  }
}