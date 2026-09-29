import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odonto_controle/screens/dashboard/main_web_dashboard.dart';
import '../../services/session_manager.dart';
import '../../services/subscription.dart';
import '../../services/theme_controller.dart';
import 'package:odonto_controle/utils/display.dart';

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
              name: (data['name'] ?? '').toString(),
              email: (data['email'] ?? user.email ?? '').toString(),
              clinicId: clinicId,
              clinicName: clinicName,
              clinicType: clinicType,
            );

            // Trava de assinatura: trial expirado OU bloqueio manual.
            // Superadmin passa direto (gerencia a plataforma).
            if (role != 'superadmin' && clinicId != null) {
              final blocked =
                  await _clinicBlocked(clinicId);
              if (blocked != null && mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (c) =>
                          _BlockedScreen(reason: blocked)),
                );
                return;
              }
            }

            // Tema = preferência do usuário (não bloqueia a navegação em erro)
            await ThemeController().loadForUser(user.uid);

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
    if (mounted) toast(context, msg, error: true);
    await Future.delayed(const Duration(seconds: 2));
    await FirebaseAuth.instance.signOut();
    SessionManager().clear();
  }

  /// Motivo do bloqueio da clínica, ou null se liberada. Sem data de
  /// trial = sem trava (clínicas legadas entram normal).
  Future<String?> _clinicBlocked(String clinicId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .get();
      final data = doc.data();
      if (data == null) return null;
      final trial =
          (data['trialEndsAt'] as Timestamp?)?.toDate();
      final manual = data['blockedByAdmin'] == true;
      if (!blockEffective(
          trialOver: trialExpired(trial, DateTime.now()),
          manual: manual)) {
        return null;
      }
      if (manual && trialExpired(trial, DateTime.now())) {
        return "Acesso suspenso. Fale com o suporte da plataforma.";
      }
      if (manual) {
        return "Acesso suspenso pelo suporte. Regularize sua assinatura.";
      }
      return "Período de teste encerrado. Fale com o suporte para continuar.";
    } catch (_) {
      return null; // Erro de leitura não bloqueia (fail-open pontual).
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Tela de bloqueio da assinatura (trial expirado ou suspensão manual).
class _BlockedScreen extends StatelessWidget {
  final String reason;
  const _BlockedScreen({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 56, color: Colors.orange),
                const SizedBox(height: 16),
                const Text("Acesso suspenso",
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(reason, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    SessionManager().clear();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const RoleCheckScreen()),
                        (r) => false,
                      );
                    }
                  },
                  child: const Text("Voltar ao login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}