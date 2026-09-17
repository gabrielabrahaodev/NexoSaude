import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  String? userId;
  String? userName;        
  String? userEmail;       
  String? userRole;        
  String? currentClinicId;
  String? currentClinicName; 
  String clinicType = 'dental';

  bool get isOwner => userRole == 'owner';

  void setUser({
    required String id,
    required String role,
    String? name,
    String? email,
    String? clinicId,
    String? clinicName,
    String? clinicType,
  }) {
    userId = id;
    userRole = role;
    userName = name;
    userEmail = email;
    currentClinicId = clinicId;
    currentClinicName = clinicName;
    if (clinicType != null) {
      this.clinicType = clinicType;
    }

    notifyListeners();
  }

  void setClinic(String clinicId, String clinicName, String type) {
    currentClinicId = clinicId;
    currentClinicName = clinicName;
    clinicType = type;
    notifyListeners();
  }

  Future<({String? id, String? name, String? type})> resolveClinic(
      String? clinicId) async {
    if (clinicId == null) return (id: null, name: null, type: null);
    final doc = await FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .get();
    if (!doc.exists) {
      debugPrint('SessionManager.resolveClinic: clínica $clinicId não existe.');
      return (id: clinicId, name: null, type: 'dental');
    }
    final data = doc.data();
    return (
      id: clinicId as String?,
      name: data?['name']?.toString(),
      type: (data?['type']?.toString() ?? 'dental'),
    );
  }

  // MÉTODO DE FILTRO (SEGURANÇA)
  Query<Map<String, dynamic>> applyFilter(Query<Map<String, dynamic>> query) {
    if (isOwner && (currentClinicId == 'ALL' || currentClinicId == null)) {
      return query;
    }

    if (currentClinicId == null) {
      // Se não houver clínica, retorna query vazia para não dar erro de permissão
      return query.where('clinicId', isEqualTo: 'waiting_session_init');
    }

    return query.where('clinicId', isEqualTo: currentClinicId);
  }

  void clear() {
    userId = null;
    userName = null;
    userEmail = null;
    userRole = null;
    currentClinicId = null;
    currentClinicName = null;
    clinicType = 'dental';
    notifyListeners();
  }
}