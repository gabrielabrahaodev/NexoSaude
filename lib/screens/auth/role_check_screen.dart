import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odonto_controle/screens/dashboard/main_web_dashboard.dart';
import '../../services/session_manager.dart'; 

class RoleCheckScreen extends StatefulWidget {
  const RoleCheckScreen({super.key});
  @override
  State<RoleCheckScreen> createState() => _RoleCheckScreenState();
}

class _RoleCheckScreenState extends State<RoleCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        if (doc.exists && doc.data() != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('role')) {
            String role = data['role'];
            List<dynamic> allowedClinics = data['allowedClinics'] ?? [];
            String? clinicId;

            if (allowedClinics.isNotEmpty) {
              clinicId = allowedClinics.first.toString();
            } else if (role == 'owner') {
              final ownerClinics = await FirebaseFirestore.instance
                  .collection('clinics')
                  .where('ownerId', isEqualTo: user.uid)
                  .limit(1)
                  .get();
              if (ownerClinics.docs.isNotEmpty) {
                clinicId = ownerClinics.docs.first.id;
              }
            }

            final clinic =
                await SessionManager().resolveClinic(clinicId);
            final clinicName = clinic.name;
            final clinicType = clinic.type;

            SessionManager().setUser(
              id: user.uid,
              role: role,
              clinicId: clinicId,
              clinicName: clinicName,
              clinicType: clinicType,
            );

            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => MainWebDashboard()));
          } else {
            _showErrorAndLogout("Cadastro incompleto.");
          }
        } else {
          _showErrorAndLogout("Usuário não encontrado.");
        }
      } catch (e) {
        _showErrorAndLogout("Erro de conexão: $e");
      }
    }
  }

  void _showErrorAndLogout(String msg) async {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    await Future.delayed(const Duration(seconds: 2));
    await FirebaseAuth.instance.signOut();
    SessionManager().clear();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}