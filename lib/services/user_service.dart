import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'clinic_capabilities.dart';
import 'session_manager.dart';

class UserService {
  // Tipagem explícita para evitar erros
  final CollectionReference<Map<String, dynamic>> _users = 
      FirebaseFirestore.instance.collection('users');
      
  final CollectionReference _clinics = FirebaseFirestore.instance.collection('clinics');

  Future<({String type, String? ownerId})> _getClinicInfo(
      String clinicId) async {
    final doc = await _clinics.doc(clinicId).get();
    if (!doc.exists) return (type: 'dental', ownerId: null);
    final data = doc.data() as Map<String, dynamic>?;
    return (
      type: data?['type']?.toString() ?? 'dental',
      ownerId: data?['ownerId']?.toString(),
    );
  }

  bool _matchesClinicType(String role, String clinicType) {
    return ClinicCapabilities.ofType(clinicType).matchesProfessionalRole(role);
  }

  // --- MÉTODO EXISTENTE (Mantido para compatibilidade) ---
  Future<List<UserModel>> getDentistsForClinic(String clinicId) async {
    try {
      final info = await _getClinicInfo(clinicId);
      if (clinicId.isEmpty) return [];

      // Busca profissionais que têm acesso a esta clínica
      final workersSnapshot = await _users
          .where('allowedClinics', arrayContains: clinicId)
          .get();

      final professionals = workersSnapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();

      // Adiciona o owner da clínica se não estiver na lista
      if (info.ownerId != null && !professionals.any((p) => p.id == info.ownerId)) {
        final ownerDoc = await _users.doc(info.ownerId!).get();
        if (ownerDoc.exists) {
          professionals.add(UserModel.fromMap(ownerDoc.id, ownerDoc.data()!));
        }
      }

      // Filtra por tipo de clínica
      return professionals.where((u) => _matchesClinicType(u.role, info.type)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- MÉTODO CORRIGIDO (Stream para o Dropdown Financeiro) ---
  Stream<List<Map<String, dynamic>>> getDentistsStream() {
    // 1. Pega o ID da clínica atual manualmente
    final String? clinicId = SessionManager().currentClinicId;
    
    if (clinicId == null || clinicId.isEmpty) {
      return Stream.value([]);
    }

    // 2. Busca a clínica para saber o tipo
    return _clinics.doc(clinicId).snapshots().asyncMap((clinicDoc) async {
      if (!clinicDoc.exists) return <Map<String, dynamic>>[];

      final clinicData = clinicDoc.data() as Map<String, dynamic>?;
      final clinicType = clinicData?['type'] ?? 'dental';
      final ownerId = clinicData?['ownerId'];
      
      // 3. Query base por allowedClinics
      Query<Map<String, dynamic>> query = _users
          .where('allowedClinics', arrayContains: clinicId);

      final snapshot = await query.get();
      List<Map<String, dynamic>> users = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // 4. Adiciona owner se não estiver na lista
      if (ownerId != null && !users.any((u) => u['id'] == ownerId)) {
        final ownerDoc = await _users.doc(ownerId).get();
        if (ownerDoc.exists) {
          final data = ownerDoc.data()!;
          data['id'] = ownerDoc.id;
          users.add(data);
        }
      }

      // 5. Filtra por tipo de clínica
      return users.where((user) {
        final role = (user['role'] ?? '').toString();
        return _matchesClinicType(role, clinicType);
      }).toList();
    });
  }
}