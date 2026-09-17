import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/session_manager.dart'; // Import necessário
import '../../ui/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String _selectedRole = 'dentist';
  bool _isLoading = false;

  // --- NOVO: BUSCA DADOS DA SESSÃO APÓS LOGIN ---
  Future<void> _initializeSession(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (userDoc.exists) {
      final data = userDoc.data()!;
      String? firstClinicId;

      if (data['allowedClinics'] != null &&
          (data['allowedClinics'] as List).isNotEmpty) {
        firstClinicId = (data['allowedClinics'] as List).first.toString();
      }

      final clinic = await SessionManager().resolveClinic(firstClinicId);
      final firstClinicName = clinic.name;
      final firstClinicType = clinic.type;

      SessionManager().setUser(
        id: uid,
        role: data['role'] ?? 'receptionist',
        name: data['name'] ?? 'Usuário',
        email: data['email'],
        clinicId: firstClinicId,
        clinicName: firstClinicName,
        clinicType: firstClinicType,
      );
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      UserCredential userCred;
      if (_isLogin) {
        userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(), 
          password: _passwordController.text.trim()
        );
      } else {
        userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(), 
          password: _passwordController.text.trim()
        );
        
        // Novo cadastro nasce SEM clínica: o owner libera em Funcionários.
        // (Antes caía hardcoded em ['matriz_santa_isabel'], dando acesso
        // imediato a dados reais para qualquer conta auto-registrada.)
        await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'created_at': DateTime.now(),
          'allowedClinics': [],
          'status': 'pending_approval',
        });
      }
      
      // OBRIGATÓRIO: Inicializa a sessão antes de liberar o loading
      await _initializeSession(userCred.user!.uid);

    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Erro")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Mantido o código do build do LoginScreen igual)
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: ClipRRect(borderRadius: BorderRadius.circular(20.0), child: Image.asset('assets/dente.png', height: 120))),
                const SizedBox(height: 20),
                Text(_isLogin ? "Bem-vindo(a)" : "Criar acesso", style: AppTextStyles.h1, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text("Consultório Odontológico", style: AppTextStyles.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 30),
              TextField(controller: _emailController, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus(), decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.email_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: "Senha", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.lock_outline)), obscureText: true),
              if (!_isLogin)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Radio(value: 'dentist', groupValue: _selectedRole, onChanged: (v) => setState(() => _selectedRole = v.toString())), const Text("Dentista"),
                      Radio(value: 'receptionist', groupValue: _selectedRole, onChanged: (v) => setState(() => _selectedRole = v.toString())), const Text("Recepção"),
                  ]),
                )
              else const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(width: double.infinity, height: 48, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _submit, child: Text(_isLogin ? "ACESSAR" : "CADASTRAR", style: const TextStyle(fontWeight: FontWeight.bold)))),
              Center(child: TextButton(onPressed: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? "Criar conta nova" : "Já tenho conta"))),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

