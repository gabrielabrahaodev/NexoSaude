import 'package:cloud_firestore/cloud_firestore.dart';

/// Diretório mínimo de membros para listagens por tenant.
/// O perfil completo fica em users/{uid}; a projeção só existe dentro de cada
/// clínica e contém os campos necessários às telas de equipe/profissionais.
class ClinicMemberDirectory {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> syncUserForClinic({
    required String uid,
    required String clinicId,
  }) async {
    final userSnap = await _db.collection('users').doc(uid).get();
    if (!userSnap.exists) {
      throw StateError('Não foi possível sincronizar membro: usuário inexistente.');
    }
    final user = userSnap.data()!;
    final allowed = (user['allowedClinics'] as List? ?? [])
        .map((value) => '$value').toSet();
    if (!allowed.contains(clinicId)) {
      throw StateError('O usuário não está vinculado à clínica informada.');
    }
    final clinicSnap = await _db.collection('clinics').doc(clinicId).get();
    if (!clinicSnap.exists) {
      throw StateError('Não foi possível sincronizar membro: clínica inexistente.');
    }
    final ownerId = (clinicSnap.data()?['ownerId'] ?? '').toString();
    if (ownerId.isEmpty) {
      throw StateError('A clínica ainda não tem proprietário definido.');
    }
    final ownedClinics = await _db.collection('clinics')
        .where('ownerId', isEqualTo: ownerId).get();
    final localAllowed = ownedClinics.docs
        .map((doc) => doc.id).where(allowed.contains).toSet().toList()..sort();

    await _db.collection('clinics').doc(clinicId)
        .collection('members').doc(uid).set({
      'uid': uid,
      'name': user['name'] ?? '',
      'email': user['email'] ?? '',
      'role': user['role'] ?? '',
      'status': user['status'] ?? '',
      'phone': user['phone'] ?? '',
      'whatsapp': user['whatsapp'] ?? '',
      'cpf': user['cpf'] ?? '',
      'menuAccess': user['menuAccess'] is Map ? user['menuAccess'] : <String, dynamic>{},
      'allowedClinics': localAllowed,
      'createdAt': user['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
