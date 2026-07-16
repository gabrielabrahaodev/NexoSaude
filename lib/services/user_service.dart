import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'session_manager.dart';

class UserService {
  // Tipagem explícita para evitar erros
  final CollectionReference<Map<String, dynamic>> _users = 
      FirebaseFirestore.instance.collection('users');
      
  final CollectionReference _clinics = FirebaseFirestore.instance.collection('clinics');

  // --- MÉTODO EXISTENTE (Mantido para compatibilidade) ---
  Future<List<UserModel>> getDentistsForClinic(String clinicId) async {
    try {
      List<UserModel> professionals = [];

      final workersSnapshot = await _users
          .where('allowedClinics', arrayContains: clinicId)
          .get();

      for (var doc in workersSnapshot.docs) {
        professionals.add(UserModel.fromMap(doc.id, doc.data())); 
      }

      final clinicDoc = await _clinics.doc(clinicId).get();
      if (clinicDoc.exists) {
        final data = clinicDoc.data() as Map<String, dynamic>?; 
        final ownerId = data?['ownerId'];
        
        if (ownerId != null && !professionals.any((p) => p.id == ownerId)) {
          final ownerDoc = await _users.doc(ownerId).get();
          if (ownerDoc.exists) {
            professionals.add(UserModel.fromMap(ownerDoc.id, ownerDoc.data()!));
          }
        }
      }

      return professionals.where((u) => u.role == 'dentista' || u.role == 'owner').toList();
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

    // 2. CORREÇÃO: Usa 'allowedClinics' com 'arrayContains' em vez de applyFilter genérico
    // Isso garante que ache os dentistas que têm acesso a esta clínica
    Query<Map<String, dynamic>> query = _users
        .where('allowedClinics', arrayContains: clinicId);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).where((user) {
        final role = user['role'] ?? '';
        // Aceita Dentista OU Dono
        return role == 'dentista' || role == 'owner';
      }).toList();
    });
  }
}