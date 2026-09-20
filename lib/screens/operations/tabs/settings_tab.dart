import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/menu_access.dart';
import '../../../services/portal_mirror.dart';
import '../../../services/session_manager.dart';
import '../../../services/theme_controller.dart';
import '../../../services/user_service.dart';
import '../../../ui/app_theme.dart';

/// Aba CONFIGURAÇÕES (Gestão): conta + aparência + controle de acesso.
///
/// - Minha conta: troca de senha (re-autentica com a senha atual).
///   Conta que só usa login Google pede a temporária ao responsável
///   (sem e-mail automático: e-mails genéricos).
/// - Tema claro/escuro: preferência do usuário (ver `ThemeController`).
/// - Acesso: owner marca o que cada usuário da clínica vê no menu lateral
///   (campo `menuAccess` no doc do usuário; ausente = tudo visível;
///   owner ignora restrições). Escrita em `users` exige owner (rules).
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _userService = UserService();
  final _edits = <String, Map<String, bool>>{};
  final _saving = <String>{};

  final _currentPass = TextEditingController();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();
  final _pixCtrl = TextEditingController();
  bool _savingPix = false;
  final _gradeStartCtrl = TextEditingController();
  final _gradeEndCtrl = TextEditingController();
  int _gradeSlot = 30;
  bool _savingGrade = false;
  bool _changing = false;

  @override
  void dispose() {
    _currentPass.dispose();
    _newPass.dispose();
    _confirmPass.dispose();
    _pixCtrl.dispose();
    _gradeStartCtrl.dispose();
    _gradeEndCtrl.dispose();
    super.dispose();
  }

  bool get _isOwner => SessionManager().isOwner;

  /// Chaves que fazem sentido p/ o tipo da clínica atual (espelha o menu:
  /// psico esconde laboratório; dental esconde fluxo terapêutico).
  List<String> get _visibleKeys =>
      MenuAccess.keysForClinicType(SessionManager().clinicType);

  Map<String, bool> _effectiveAccess(Map<String, dynamic> user) {
    final saved = _edits[user['id'] as String];
    if (saved != null) return saved;
    final stored = MenuAccess.parse(user['menuAccess']);
    return {for (final k in _visibleKeys) k: stored[k] ?? true};
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  /// Troca de senha com re-autenticação (exigência do Firebase para
  /// operação sensível).
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    if (user == null || email.isEmpty) {
      _snack("Sessão inválida. Entre novamente.", error: true);
      return;
    }
    final current = _currentPass.text;
    final nouveau = _newPass.text;
    if (nouveau.length < 6) {
      _snack("A nova senha precisa de ao menos 6 caracteres.", error: true);
      return;
    }
    if (nouveau != _confirmPass.text) {
      _snack("A confirmação não confere com a nova senha.", error: true);
      return;
    }
    setState(() => _changing = true);
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
      await user.updatePassword(nouveau);
      _currentPass.clear();
      _newPass.clear();
      _confirmPass.clear();
      _snack("Senha alterada com sucesso.");
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'wrong-password' ||
              e.code == 'invalid-credential')
          ? "Senha atual incorreta."
          : (e.code == 'too-many-requests'
              ? "Muitas tentativas. Aguarde e tente de novo."
              : (e.message ?? "Erro"));
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _save(String uid) async {
    final access = _edits[uid];
    if (access == null) return;
    setState(() => _saving.add(uid));
    try {
      await _userService.updateMenuAccess(uid, access);
      if (mounted) {
        setState(() {
          _edits.remove(uid);
          _saving.remove(uid);
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Acesso atualizado.")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving.remove(uid));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Falha ao salvar: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager().currentClinicId;
    final themeController = ThemeController();

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- MINHA CONTA ----------
          _accountCard(),
          const SizedBox(height: 16),

          // ---------- PIX DA CLÍNICA (vai p/ o portal) ----------
          _pixCard(clinicId),
          const SizedBox(height: 16),

          // ---------- GRADE DE HORÁRIOS (slots do portal) ----------
          _gradeCard(clinicId),
          const SizedBox(height: 16),

          // ---------- APARÊNCIA ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Aparência", style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  const Text(
                      "Tema claro ou escuro — vale para o seu usuário em qualquer aparelho."),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text("Claro"),
                          icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(
                          value: true,
                          label: Text("Escuro"),
                          icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {themeController.isDark},
                    onSelectionChanged: (s) async {
                      final ok =
                          await themeController.setDark(s.first);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Aplicado aqui, mas NÃO salvou na nuvem. Rode: firebase deploy --only firestore:rules"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- CONTROLE DE ACESSO ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Controle de acesso", style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  const Text(
                      "O que cada usuário vê no menu da clínica. Sem restrição = tudo visível. O proprietário sempre vê tudo."),
                  const SizedBox(height: 12),
                  if (!_isOwner)
                    const Text(
                        "Disponível apenas para o proprietário da clínica.",
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  if (_isOwner && (clinicId == null || clinicId.isEmpty))
                    const Text("Selecione uma clínica."),
                  if (_isOwner &&
                      clinicId != null &&
                      clinicId.isNotEmpty)
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _userService.watchClinicUsers(clinicId),
                      builder: (context, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Text("Erro: ${snap.error}");
                        }
                        final users = snap.data ?? [];
                        if (users.isEmpty) {
                          return const Text(
                              "Nenhum usuário vinculado à clínica.");
                        }
                        return Column(
                          children: [
                            for (final u in users) _userTile(u),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cartão "Minha conta": troca de senha (conta com senha) ou link de
  /// redefinição (conta que só usa login Google).
  Widget _accountCard() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? SessionManager().userEmail ?? '';
    final hasPassword =
        user?.providerData.any((p) => p.providerId == 'password') ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Minha conta", style: AppTextStyles.h2),
            const SizedBox(height: 4),
            if (email.isNotEmpty) Text(email),
            const SizedBox(height: 12),
            if (!hasPassword) ...[
              const Text(
                  "Sua conta usa login Google e ainda não tem senha. Peça ao responsável para gerar uma senha temporária (tela Funcionários); depois de entrar com ela, troque aqui."),
            ] else ...[
              TextField(
                controller: _currentPass,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: "Senha atual",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPass,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: "Nova senha (mín. 6 caracteres)",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPass,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _changePassword(),
                decoration: InputDecoration(
                    labelText: "Confirmar nova senha",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              _changing
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _changePassword,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text("Alterar senha"),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pix da clínica (exibido no portal do paciente). Escrita só owner
  /// (rules de `clinics`); demais veem somente leitura.
  Widget _pixCard(String? clinicId) {
    if (clinicId == null || clinicId.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text("Selecione uma clínica."),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('clinics')
              .doc(clinicId)
              .get(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (_pixCtrl.text.isEmpty) {
              _pixCtrl.text =
                  '${(snap.data!.data() as Map?)?['pixKey'] ?? ''}';
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pix da clínica", style: AppTextStyles.h2),
                const SizedBox(height: 4),
                const Text(
                    "Chave exibida no portal do paciente para pagamento."),
                const SizedBox(height: 12),
                TextField(
                  controller: _pixCtrl,
                  enabled: _isOwner && !_savingPix,
                  decoration: InputDecoration(
                      labelText: "Chave Pix",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                if (_isOwner) ...[
                  const SizedBox(height: 12),
                  _savingPix
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: () async {
                            setState(() => _savingPix = true);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('clinics')
                                  .doc(clinicId)
                                  .update({
                                'pixKey':
                                    _pixCtrl.text.trim()
                              });
                              _snack("Pix salvo.");
                            } catch (e) {
                              _snack("Falha ao salvar: $e",
                                  error: true);
                            } finally {
                              if (mounted) {
                                setState(
                                    () => _savingPix = false);
                              }
                            }
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text("Salvar Pix"),
                        ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Grade de horários (slots livres do portal). Salvar reconstrói a
  /// janela de 14 dias na hora (rebuild automático).
  Widget _gradeCard(String? clinicId) {
    if (clinicId == null || clinicId.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text("Selecione uma clínica."),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('clinics')
              .doc(clinicId)
              .get(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final cfg =
                ((snap.data!.data() as Map?)?['gradeConfig'] as Map?) ?? {};
            if (_gradeStartCtrl.text.isEmpty) {
              _gradeStartCtrl.text = '${cfg['start'] ?? '08:30'}';
              _gradeEndCtrl.text = '${cfg['end'] ?? '20:00'}';
              _gradeSlot =
                  (cfg['slot'] as num?)?.toInt() ?? 30;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Grade de horários", style: AppTextStyles.h2),
                const SizedBox(height: 4),
                const Text(
                    "Vale para a agenda do portal (slots livres). Salvar reconstrói na hora."),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _gradeStartCtrl,
                        enabled: _isOwner && !_savingGrade,
                        decoration: InputDecoration(
                            labelText: "Início (HH:mm)",
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _gradeEndCtrl,
                        enabled: _isOwner && !_savingGrade,
                        decoration: InputDecoration(
                            labelText: "Fim (HH:mm)",
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _gradeSlot,
                        decoration: InputDecoration(
                            labelText: "Slot",
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12))),
                        items: const [
                          DropdownMenuItem(
                              value: 15, child: Text("15min")),
                          DropdownMenuItem(
                              value: 30, child: Text("30min")),
                          DropdownMenuItem(
                              value: 60, child: Text("60min")),
                        ],
                        onChanged: !_isOwner
                            ? null
                            : (v) => setState(
                                () => _gradeSlot = v ?? 30),
                      ),
                    ),
                  ],
                ),
                if (_isOwner) ...[
                  const SizedBox(height: 12),
                  _savingGrade
                      ? const Center(
                          child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: () async {
                            final ok = RegExp(r'^\d{2}:\d{2}$')
                                    .hasMatch(_gradeStartCtrl.text
                                        .trim()) &&
                                RegExp(r'^\d{2}:\d{2}$').hasMatch(
                                    _gradeEndCtrl.text.trim());
                            if (!ok) {
                              _snack(
                                  "Use HH:mm (ex. 08:30).",
                                  error: true);
                              return;
                            }
                            setState(() => _savingGrade = true);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('clinics')
                                  .doc(clinicId)
                                  .update({
                                'gradeConfig': {
                                  'start': _gradeStartCtrl.text
                                      .trim(),
                                  'end': _gradeEndCtrl.text
                                      .trim(),
                                  'slot': _gradeSlot,
                                }
                              });
                              await PortalMirrorSync.ensureWindow(
                                  clinicId);
                              _snack("Grade salva e slots "
                                  "reconstruídos.");
                            } catch (e) {
                              _snack("Falha ao salvar: $e",
                                  error: true);
                            } finally {
                              if (mounted) {
                                setState(() =>
                                    _savingGrade = false);
                              }
                            }
                          },
                          icon: const Icon(
                              Icons.schedule_outlined),
                          label:
                              const Text("Salvar e reconstruir"),
                        ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final uid = user['id'] as String;
    final name = '${user['name'] ?? user['email'] ?? 'Usuário'}';
    final role = '${user['role'] ?? ''}';
    final access = _effectiveAccess(user);
    final dirty = _edits.containsKey(uid);
    final saving = _saving.contains(uid);

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(role + (dirty ? ' • alterado' : '')),
        trailing: dirty
            ? (saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    onPressed: () => _save(uid),
                    child: const Text("Salvar"),
                  ))
            : null,
        children: [
          for (final k in _visibleKeys)
            CheckboxListTile(
              dense: true,
              title: Text(MenuAccess.labels[k] ?? k),
              value: access[k] ?? true,
              onChanged: (v) => setState(() {
                final map = Map<String, bool>.from(access);
                map[k] = v ?? true;
                _edits[uid] = map;
              }),
            ),
        ],
      ),
    );
  }
}
