import 'package:cloud_firestore/cloud_firestore.dart';

/// Diretório mínimo de membros para listagens por tenant.
/// O perfil completo fica em users/{uid}; a projeção só existe dentro de cada
/// clínica e contém os campos necessários às telas de equipe/profissionais.
class ClinicMemberDirectory {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cria perfil + espelhos público/privado no mesmo batch. O UID já deve
  /// existir no Firebase Auth; se o batch falhar, nenhum dos três documentos
  /// do Firestore fica parcialmente provisionado.
  static Future<void> createUserForClinic({
    required String uid,
    required String clinicId,
    required Map<String, dynamic> profile,
  }) async {
    if (uid.isEmpty || clinicId.isEmpty) {
      throw ArgumentError('uid e clinicId são obrigatórios.');
    }
    final allowed = (profile['allowedClinics'] as List? ?? [])
        .map((value) => '$value')
        .toSet();
    if (!allowed.contains(clinicId)) {
      throw StateError('O perfil precisa incluir a clínica de destino.');
    }
    if (profile['role'] == 'owner' || profile['role'] == 'superadmin') {
      throw StateError('Este fluxo só cria papéis de equipe.');
    }
    if (profile['status'] != 'Ativo' && profile['status'] != 'pending_approval') {
      throw StateError('Status inicial inválido.');
    }

    final clinicSnap = await _db.collection('clinics').doc(clinicId).get();
    if (!clinicSnap.exists) {
      throw StateError('Clínica inexistente.');
    }
    final ownerId = '${clinicSnap.data()?['ownerId'] ?? ''}';
    if (ownerId.isEmpty) {
      throw StateError('A clínica não tem proprietário definido.');
    }
    final ownedClinics = await _db
        .collection('clinics')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final localAllowed = ownedClinics.docs
        .map((doc) => doc.id)
        .where(allowed.contains)
        .toSet()
        .toList()
      ..sort();
    if (!localAllowed.contains(clinicId)) {
      throw StateError('A clínica de destino não pertence ao proprietário esperado.');
    }

    final user = Map<String, dynamic>.from(profile);
    final createdAt = user['createdAt'] ?? user['created_at'] ?? FieldValue.serverTimestamp();
    final common = {
      'uid': uid,
      'name': user['name'] ?? '',
      'role': user['role'] ?? '',
      'status': user['status'] ?? '',
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final clinicRef = _db.collection('clinics').doc(clinicId);
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(uid), user);
    batch.set(clinicRef.collection('members').doc(uid), common);
    batch.set(clinicRef.collection('members_private').doc(uid), {
      ...common,
      'email': user['email'] ?? '',
      'phone': user['phone'] ?? '',
      'whatsapp': user['whatsapp'] ?? '',
      'cpf': user['cpf'] ?? '',
      'menuAccess': user['menuAccess'] is Map ? user['menuAccess'] : <String, dynamic>{},
      'allowedClinics': localAllowed,
    });
    await batch.commit();
  }

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

    final createdAt = user['createdAt'] ?? FieldValue.serverTimestamp();
    final clinicRef = _db.collection('clinics').doc(clinicId);
    final menuAccess = user['menuAccess'] is Map
        ? user['menuAccess']
        : <String, dynamic>{};
    final batch = _db.batch();

    batch.set(clinicRef.collection('members').doc(uid), {
      'uid': uid,
      'name': user['name'] ?? '',
      'role': user['role'] ?? '',
      'status': user['status'] ?? '',
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(clinicRef.collection('members_private').doc(uid), {
      'uid': uid,
      'name': user['name'] ?? '',
      'email': user['email'] ?? '',
      'role': user['role'] ?? '',
      'status': user['status'] ?? '',
      'phone': user['phone'] ?? '',
      'whatsapp': user['whatsapp'] ?? '',
      'cpf': user['cpf'] ?? '',
      'menuAccess': menuAccess,
      'allowedClinics': localAllowed,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
