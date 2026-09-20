import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
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

      // Janela de slots: reconstrução manual em Gestão → Configurações
      // (grade) ou via backfill; login não varre (economia de cota).
    }
  }

  /// Login com Google (Web: popup; mobile: conta do aparelho).
  /// Conta nova ganha doc `users` pendente (owner libera em Funcionários).
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      UserCredential userCred;
      if (kIsWeb) {
        userCred = await FirebaseAuth.instance
            .signInWithPopup(GoogleAuthProvider());
      } else {
        await GoogleSignIn.instance.initialize();
        final account = await GoogleSignIn.instance.authenticate();
        userCred = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
              idToken: account.authentication.idToken),
        );
      }
      await _ensureUserDoc(userCred.user!);

      // OBRIGATÓRIO: Inicializa a sessão antes de liberar o loading
      await _initializeSession(userCred.user!.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  "Este email já tem cadastro com senha. Entre com email e senha.")));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? "Erro")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Cria o doc do usuário Google estreante (pendente de liberação).
  /// Exige a regra de auto-cadastro em `firestore.rules` (users/create próprio).
  Future<void> _ensureUserDoc(User user) async {
    final ref =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'email': user.email ?? '',
        'name': user.displayName ?? 'Usuário',
        'role': 'receptionist',
        'created_at': DateTime.now(),
        'allowedClinics': [],
        'status': 'pending_approval',
        'authProvider': 'google',
      });
    }
  }

  /// "Esqueci a senha?" SEM e-mail automatico (e-mails sao genericos, sem
  /// caixa de entrada): grava um pedido em `password_reset_requests`
  /// (create publico, ver `firestore.rules` A3). O responsavel gera a nova
  /// senha com o `reset-senha.bat` e informa a pessoa.
  Future<void> _forgotPassword() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pedir nova senha"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Informe seu e-mail de login e avise o responsável. Ele vai gerar uma nova senha para você."),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text("Enviar pedido")),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    if (!email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("E-mail inválido."),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('password_reset_requests')
          .add({
        'email': email.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Pedido enviado! Avise o responsável para gerar sua nova senha.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Falha ao enviar pedido: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _submit() async {    if (_isLoading) return;
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
      backgroundColor: AppColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Image.asset('assets/logo.png', height: 150)),
                const SizedBox(height: 20),
                Text(_isLogin ? "Bem-vindo(a)" : "Criar acesso", style: AppTextStyles.h1, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text("Controle de Clínicas", style: AppTextStyles.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 30),
              TextField(controller: _emailController, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).nextFocus(), decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.email_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: "Senha", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.lock_outline)), obscureText: true),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text("Esqueci a senha?"),
                  ),
                ),
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
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 20),
                    label: const Text("Entrar com Google",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

