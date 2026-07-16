import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // Necessário para criar App Secundário
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../services/session_manager.dart';

class EmployeeManagerScreen extends StatefulWidget {
  const EmployeeManagerScreen({super.key});

  @override
  State<EmployeeManagerScreen> createState() => _EmployeeManagerScreenState();
}

class _EmployeeManagerScreenState extends State<EmployeeManagerScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Estado
  String _selectedRole = 'recepcionista'; // Padrão
  String? _selectedClinicId; // Só usado se for Owner
  bool _isLoading = false;

  // Máscara
  final maskCPF = MaskTextInputFormatter(
    mask: '###.###.###-##', 
    filter: {"#": RegExp(r'[0-9]')}
  );

  @override
  void initState() {
    super.initState();
    _checkOwnerPermission();
  }

  // Se não for owner, já fixa a clínica atual
  void _checkOwnerPermission() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get();
    final role = userDoc.data()?['role'];
    
    if (role != 'owner') {
      setState(() {
        _selectedClinicId = SessionManager().currentClinicId;
      });
    }
  }

  // --- LÓGICA CORE: CRIAR USUÁRIO SEM DESLOGAR ---
  Future<void> _registerEmployee() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _cpfController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos.")));
      return;
    }

    if (_selectedClinicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Nenhuma clínica selecionada/identificada.")));
      return;
    }

    setState(() => _isLoading = true);

    FirebaseApp? tempApp;
    try {
      // 1. Cria uma instância temporária do Firebase para não deslogar o Admin
      tempApp = await Firebase.initializeApp(
        name: 'TemporaryRegisterApp',
        options: Firebase.app().options,
      );

      // 2. Cria o usuário na Autenticação usando o App Temporário
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. Salva os dados no Firestore (Indexando Usuário + Clínica)
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'cpf': _cpfController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole, // 'dentista' ou 'recepcionista'
        'allowedClinics': [_selectedClinicId], // VINCULA À CLÍNICA ESPECÍFICA
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Ativo'
      });

      // 4. Limpa e Sucesso
      if (mounted) {
        Navigator.pop(context); // Fecha o modal
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Funcionário cadastrado com sucesso!")));
        _clearForm();
      }

    } on FirebaseAuthException catch (e) {
      String msg = "Erro ao cadastrar";
      if (e.code == 'email-already-in-use') msg = "Este email já está em uso.";
      if (e.code == 'weak-password') msg = "A senha é muito fraca.";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      // 5. Destrói o app temporário para liberar memória
      await tempApp?.delete();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _cpfController.clear();
    _emailController.clear();
    _passwordController.clear();
  }

  void _showRegisterModal() {
    showDialog(
      context: context,
      builder: (context) {
        // Verifica se é Owner para mostrar o Dropdown de Clínicas
        final isOwner = SessionManager().userRole == 'owner';
        final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

        return AlertDialog(
          title: const Text("Novo Funcionário"),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // SELECIONAR CLÍNICA (SÓ SE FOR OWNER)
                  if (isOwner)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('clinics')
                          .where('ownerId', isEqualTo: currentUserUid).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        var clinics = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: _selectedClinicId,
                          hint: const Text("Selecione a Clínica"),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: clinics.map((doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(doc['name']),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedClinicId = val),
                        );
                      }
                    ),
                  if (isOwner) const SizedBox(height: 15),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cpfController,
                    inputFormatters: [maskCPF],
                    decoration: const InputDecoration(labelText: "CPF", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(labelText: "Função", border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
                    items: const [
                      DropdownMenuItem(value: 'recepcionista', child: Text("Recepcionista")),
                      DropdownMenuItem(value: 'dentista', child: Text("Dentista")),
                      DropdownMenuItem(value: 'gerente', child: Text("Gerente")),
                    ],
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const Text("Dados de Acesso", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "E-mail (Login)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: "Senha Inicial", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: _isLoading ? null : _registerEmployee,
              child: _isLoading ? const CircularProgressIndicator() : const Text("Cadastrar"),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtra funcionários da clínica atual
    final currentClinic = SessionManager().currentClinicId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Funcionários", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
                    Text("Gerencie o acesso da sua equipe", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showRegisterModal,
                  icon: const Icon(Icons.person_add),
                  label: const Text("NOVO FUNCIONÁRIO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),

            // LISTA DE FUNCIONÁRIOS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Busca usuários que tenham o ID desta clínica na lista 'allowedClinics'
                stream: FirebaseFirestore.instance.collection('users')
                    .where('allowedClinics', arrayContains: currentClinic)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}")); // Provavelmente pedirá índice na primeira vez
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(child: Text("Nenhum funcionário nesta clínica.", style: TextStyle(color: Colors.grey[500])));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      bool isOwner = data['role'] == 'owner';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOwner ? Colors.purple[100] : Colors.blue[100],
                            child: Icon(isOwner ? Icons.star : Icons.person, color: isOwner ? Colors.purple : Colors.blue),
                          ),
                          title: Text(data['name'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${data['role'].toString().toUpperCase()} • ${data['email']}"),
                          trailing: isOwner ? const Chip(label: Text("Dono")) : const Icon(Icons.more_vert),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}