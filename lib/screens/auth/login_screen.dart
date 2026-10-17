import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
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
      if (userCred.additionalUserInfo?.isNewUser == true) {
        // Não deixar uma conta Google órfã no Auth sem provisionamento.
        try {
          await userCred.user?.delete();
        } finally {
          await FirebaseAuth.instance.signOut();
        }
        throw FirebaseAuthException(
          code: 'user-not-provisioned',
          message: 'Peça ao proprietário para criar seu acesso ou solicite um teste grátis.',
        );
      }
      await _ensureUserDoc(userCred.user!);
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

  /// Login Google é somente para contas já provisionadas pela plataforma
  /// ou por um proprietário. Não crie perfis pendentes sem clínica, porque
  /// não há uma fila de aprovação ligada a esse cadastro genérico.
  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'user-not-provisioned',
        message: 'Acesso ainda não cadastrado. Solicite um teste grátis ou peça ao responsável para criar sua conta.',
      );
    }
  }

  Future<void> _openTrialRequest() async {
    final uri = Uri.base.resolve('/assinatura.html');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível abrir a solicitação de acesso. Acesse a página pública de teste grátis.'),
      ));
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

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _initializeSession(userCred.user!.uid);
      TextInput.finishAutofillContext();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erro ao entrar.')),
        );
      }
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
                const Text("Bem-vindo(a)", style: AppTextStyles.h1, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text("Controle de Clínicas", style: AppTextStyles.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 30),
              AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        controller: _emailController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                        decoration: InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon:
                                const Icon(Icons.email_outlined))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _passwordController,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                            labelText: "Senha",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon:
                                const Icon(Icons.lock_outline)),
                        obscureText: true),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  child: const Text("Esqueci a senha?"),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(width: double.infinity, height: 48, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _submit, child: const Text("ACESSAR", style: TextStyle(fontWeight: FontWeight.bold)))),
              Center(child: TextButton(onPressed: _isLoading ? null : _openTrialRequest, child: const Text("Solicitar teste grátis"))),
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

