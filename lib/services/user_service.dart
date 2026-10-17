import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'clinic_capabilities.dart';
import 'session_manager.dart';
import 'clinic_member_directory.dart';

/// Dentista padrão da próxima sessão (puro e testado): mantém o atual
/// se ainda atende; senão o primeiro da lista; sem lista, o atual.
String? resolveNextDentist(String? currentId, List<UserModel> dentists) {
  if ((currentId ?? '').isNotEmpty &&
      dentists.any((d) => d.id == currentId)) {
    return currentId;
  }
  if (dentists.isNotEmpty) return dentists.first.id;
  return currentId;
}

class UserService {
  // Tipagem explícita para evitar erros
  final CollectionReference<Map<String, dynamic>> _users = 
      FirebaseFirestore.instance.collection('users');
      
  final CollectionReference<Map<String, dynamic>> _clinics = FirebaseFirestore.instance.collection('clinics');

  Future<({String type})> _getClinicInfo(String clinicId) async {
    final doc = await _clinics.doc(clinicId).get();
    if (!doc.exists) return (type: 'dental');
    final data = doc.data() as Map<String, dynamic>?;
    return (type: data?['type']?.toString() ?? 'dental');
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
      final workersSnapshot = await _clinics.doc(clinicId)
          .collection('members').get();

      final professionals = workersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'Ativo')
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();

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
      
      // 3. Lê somente a projeção pública mínima da clínica.
      final snapshot = await _clinics.doc(clinicId).collection('members').get();
      final users = snapshot.docs
          .where((doc) => doc.data()['status'] == 'Ativo')
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .toList();

      // 4. Só profissionais ativos; aliases legados são normalizados pela
      // ClinicCapabilities, sem leitura dos perfis completos dos colegas.
      return users.where((user) {
        final role = (user['role'] ?? '').toString();
        return _matchesClinicType(role, clinicType);
      }).toList();
    });
  }

  /// Todos os usuários da clínica (sem filtro de papel) — aba Configurações.
  /// Inclui `menuAccess` (Map) quando existir.
  Stream<List<Map<String, dynamic>>> watchClinicUsers(String clinicId) {
    if (clinicId.isEmpty) return Stream.value([]);
    return _clinics.doc(clinicId)
        .collection('members_private')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Salva o mapa de acesso ao menu (`menuAccess`) do usuário.
  /// Regra Firestore: escrita em `users` só p/ owner.
  Future<void> updateMenuAccess(String uid, Map<String, bool> access) async {
    await _users.doc(uid).update({'menuAccess': access});
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null || clinicId.isEmpty || clinicId == 'ALL') return;
    await ClinicMemberDirectory.syncUserForClinic(uid: uid, clinicId: clinicId);
  }
}