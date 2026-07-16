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
            
            if (role == 'owner') {
              clinicId = 'matriz_santa_isabel'; 
            } else if (allowedClinics.isNotEmpty) {
              clinicId = allowedClinics.first.toString(); 
            } else {
              clinicId = 'matriz_santa_isabel';
            }

            SessionManager().setUser(id: user.uid, role: role, clinicId: clinicId);

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