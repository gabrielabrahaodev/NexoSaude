import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../services/subscription.dart';
import '../../ui/app_theme.dart';
import '../../utils/display.dart';

/// Master da plataforma (só `superadmin`): owners, débitos e trials.
/// Mensalidade = `40 + 15×(n−1)` sobre staff das clínicas do owner.
class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  double _base = 40;
  double _extra = 15;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('platform_config')
          .doc('geral')
          .get();
      final m = doc.data();
      if (mounted && m != null) {
        setState(() {
          _base = (m['basePrice'] as num?)?.toDouble() ?? 40;
          _extra = (m['extraPrice'] as num?)?.toDouble() ?? 15;
        });
      }
    } catch (_) {}
  }

  /// Staff (sem owner) com acesso à clínica.
  Future<List<String>> _staffOf(String clinicId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('allowedClinics', arrayContains: clinicId)
        .get();
    return [
      for (final d in snap.docs)
        if ('${(d.data())['role'] ?? ''}' != 'owner') d.id
    ];
  }

  Future<void> _toggleBlock(String clinicId, bool blocked) async {
    try {
      await FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .update({'blockedByAdmin': blocked});
      if (mounted) {
        toast(context, blocked ? "Clínica bloqueada." : "Clínica liberada.",
            ok: !blocked, error: blocked);
      }
    } catch (e) {
      if (mounted) toast(context, "Falha: $e", error: true);
    }
  }

  Future<void> _generateDebit(
      String clinicId, String ownerId, String clinicName) async {
    setState(() => _saving = true);
    try {
      final staff = await _staffOf(clinicId);
      final amount = subscriptionAmount(staff.length,
          base: _base, extra: _extra);
      if (amount <= 0) {
        if (mounted) toast(context, "Sem usuários: nada a gerar.");
        return;
      }
      final owner = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      await FirebaseFirestore.instance.collection('platform_debits').add({
        'ownerId': ownerId,
        'ownerEmail': '${(owner.data() ?? {})['email'] ?? ''}',
        'clinicId': clinicId,
        'clinicName': clinicName,
        'users': staff.length,
        'amount': amount,
        'paidAmount': 0.0,
        'date': FieldValue.serverTimestamp(),
        'dueDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30))),
        'status': 'pendente',
        'type': 'assinatura',
      });
      if (mounted) {
        toast(context,
            "Mensalidade ${formatBRL(amount)} gerada (${staff.length} usuários).",
            ok: true);
      }
    } catch (e) {
      if (mounted) toast(context, "Falha: $e", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _settleDebit(String id, double amount) async {
    try {
      await FirebaseFirestore.instance
          .collection('platform_debits')
          .doc(id)
          .update({
        'status': 'pago',
        'paidAmount': amount,
        'paymentDate': FieldValue.serverTimestamp(),
      });
      if (mounted) toast(context, "Baixa dada.", ok: true);
    } catch (e) {
      if (mounted) toast(context, "Falha: $e", error: true);
    }
  }

  Future<void> _dismissNotice(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('platform_debits')
          .doc(id)
          .update({'avisoPagamento': FieldValue.delete()});
    } catch (e) {
      if (mounted) toast(context, "Falha: $e", error: true);
    }
  }

  // --- NOVO OWNER (bootstrap: user + clínica + trial 7d) ---
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  String _clinicType = 'dental';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _clinicCtrl.dispose();
    super.dispose();
  }

  Future<void> _showNewOwner() async {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _passCtrl.clear();
    _clinicCtrl.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text("Novo owner + clínica (trial 7 dias)"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: "Nome")),
                TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: "E-mail (login)")),
                TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration:
                        const InputDecoration(labelText: "Senha inicial")),
                TextField(
                    controller: _clinicCtrl,
                    decoration: const InputDecoration(
                        labelText: "Nome da clínica")),
                DropdownButtonFormField<String>(
                  value: _clinicType,
                  decoration:
                      const InputDecoration(labelText: "Tipo"),
                  items: const [
                    DropdownMenuItem(
                        value: 'dental', child: Text("Odonto")),
                    DropdownMenuItem(
                        value: 'psychology',
                        child: Text("Psicologia")),
                  ],
                  onChanged: (v) =>
                      setDlg(() => _clinicType = v ?? 'dental'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Criar")),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.trim().isEmpty ||
        _clinicCtrl.text.trim().isEmpty) {
      toast(context, "Preencha todos os campos.", error: true);
      return;
    }
    setState(() => _saving = true);
    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: 'MasterRegisterApp',
        options: Firebase.app().options,
      );
      final cred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      final uid = cred.user!.uid;
      final clinicRef =
          FirebaseFirestore.instance.collection('clinics').doc();
      await clinicRef.set({
        'name': _clinicCtrl.text.trim(),
        'type': _clinicType,
        'ownerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'trialEndsAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7))),
        'blockedByAdmin': false,
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'email': _emailCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'role': 'owner',
        'allowedClinics': [clinicRef.id],
        'status': 'Ativo',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        toast(context, "Owner + clínica criados (trial 7 dias).",
            ok: true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        toast(
            context,
            e.code == 'email-already-in-use'
                ? "E-mail já em uso."
                : (e.message ?? "Erro"),
            error: true);
      }
    } catch (e) {
      if (mounted) toast(context, "Falha: $e", error: true);
    } finally {
      await tempApp?.delete();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Master",
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(tabs: [
            Tab(text: "Owners"),
            Tab(text: "Débitos"),
            Tab(text: "Trials"),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : _showNewOwner,
          icon: const Icon(Icons.person_add),
          label: const Text("Novo owner"),
        ),
        body: TabBarView(
          children: [
            _ownersTab(),
            _debitsTab(),
            _trialsTab(),
          ],
        ),
      ),
    );
  }

  Widget _ownersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('clinics').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text("Erro: ${snap.error}"));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text("Nenhuma clínica. Crie o primeiro owner."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final m = d.data() as Map<String, dynamic>;
            final trial =
                (m['trialEndsAt'] as Timestamp?)?.toDate();
            final blocked = m['blockedByAdmin'] == true;
            final trialOver =
                trialExpired(trial, DateTime.now());
            return Card(
              child: ExpansionTile(
                leading: Icon(
                    blocked || trialOver
                        ? Icons.block
                        : Icons.storefront_outlined,
                    color: blocked || trialOver
                        ? Colors.red
                        : Colors.green),
                title: Text('${m['name'] ?? 'Clínica'}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: FutureBuilder<List<String>>(
                  future: _staffOf(d.id),
                  builder: (context, s) {
                    final n = s.data?.length;
                    final trialTxt = trial == null
                        ? 'sem trial'
                        : trialOver
                            ? 'trial expirado'
                            : 'trial até ${formatDateShort(trial)}';
                    return Text(
                        "${n == null ? '…' : '$n usuários'} • $trialTxt${blocked ? ' • BLOQUEADA' : ''}");
                  },
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _toggleBlock(d.id, !blocked),
                        child: Text(blocked
                            ? "Liberar"
                            : "Bloquear"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () => _generateDebit(d.id,
                                '${m['ownerId'] ?? ''}',
                                '${m['name'] ?? ''}'),
                        child: const Text("Gerar mensalidade"),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _debitsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('platform_debits')
          .orderBy('dueDate', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text("Erro: ${snap.error}"));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text("Nenhum débito gerado."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final m = d.data() as Map<String, dynamic>;
            final paid =
                '${m['status'] ?? ''}'.toLowerCase() == 'pago';
            final noticed =
                (m['avisoPagamento'] as Map?) != null;
            return Card(
              child: ListTile(
                title: Text(
                    '${m['clinicName'] ?? ''} — ${m['users'] ?? 0} usuários',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    "${m['ownerEmail'] ?? ''} • ${formatBRL(parseBRL(m['amount']))} • ${paid ? 'Pago' : 'Pendente'}${noticed && !paid ? ' • Avisei que paguei' : ''}"),
                trailing: paid
                    ? const Icon(Icons.check_circle,
                        color: Colors.green)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (noticed)
                            IconButton(
                              tooltip: 'Dispensar aviso',
                              icon: const Icon(Icons.close,
                                  size: 20),
                              onPressed: () => FirebaseFirestore
                                  .instance
                                  .collection('platform_debits')
                                  .doc(d.id)
                                  .update({
                                'avisoPagamento':
                                    FieldValue.delete()
                              }),
                            ),
                          ElevatedButton(
                            onPressed: () => _settleDebit(d.id,
                                parseBRL(m['amount'])),
                            child: const Text("Dar baixa"),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _trialsTab() {
    final limit = DateTime.now().add(const Duration(days: 3));
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('clinics').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          final t = (m['trialEndsAt'] as Timestamp?)?.toDate();
          if (t == null) return false;
          return t.isBefore(limit) ||
              m['blockedByAdmin'] == true;
        }).toList();
        if (docs.isEmpty) {
          return const Center(
              child: Text("Nenhum trial vencendo."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final m = d.data() as Map<String, dynamic>;
            final t = (m['trialEndsAt'] as Timestamp?)?.toDate();
            final over =
                trialExpired(t, DateTime.now());
            final blocked = m['blockedByAdmin'] == true;
            return Card(
              child: ListTile(
                leading: Icon(Icons.timer_outlined,
                    color: over || blocked
                        ? Colors.red
                        : Colors.orange),
                title: Text('${m['name'] ?? ''}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(t == null
                    ? 'sem trial'
                    : over
                        ? 'expirado'
                        : 'vence ${formatDateShort(t)}'),
                trailing: TextButton(
                  onPressed: () => _toggleBlock(d.id, !blocked),
                  child:
                      Text(blocked ? "Liberar" : "Bloquear"),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
