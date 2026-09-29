import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import '../../widgets/page_header.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session_manager.dart';
import '../../utils/display.dart';
import '../dashboard/main_web_dashboard.dart'; 

class ClinicManagementScreen extends StatefulWidget {
  const ClinicManagementScreen({super.key});

  @override
  State<ClinicManagementScreen> createState() => _ClinicManagementScreenState();
}

class _ClinicManagementScreenState extends State<ClinicManagementScreen> {
  bool _isOwner = false;
  List<String> _myClinicIds = [];
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  /// Owner vê as unidades dele; demais veem as liberadas (troca via Gerenciar).
  Future<void> _loadRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _isOwner = data?['role'] == 'owner';
        final allowed = data?['allowedClinics'];
        _myClinicIds = allowed is List
            ? allowed.map((e) => e.toString()).take(10).toList()
            : const [];
        _loadingRole = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRole = false);
    }
  }
  
  // Função atualizada com StatefulBuilder para o Dropdown funcionar
  void _showAddClinicDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    
    // Variável de estado local do modal
    String selectedType = 'dental'; // Padrão

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder é necessário para atualizar o Dropdown dentro do Dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Nova Clínica / Unidade"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Nome da Clínica", border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 15),
                    
                    // --- NOVO SELETOR DE TIPO ---
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: "Especialidade / Tipo",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'dental', child: Text("Odontológica (Padrão)")),
                        DropdownMenuItem(value: 'psychology', child: Text("Psicológica")),
                        DropdownMenuItem(value: 'physiotherapy', child: Text("Fisioterapêutica")),
                        DropdownMenuItem(value: 'yoga', child: Text("Estúdio de Ioga")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedType = val);
                        }
                      },
                    ),
                    // ----------------------------

                    const SizedBox(height: 15),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Telefone", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: "Endereço Completo", border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      _saveClinic(
                        nameController.text,
                        phoneController.text,
                        addressController.text,
                        selectedType, // Passamos o tipo selecionado
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Cadastrar"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // Recebe o TYPE agora
  Future<void> _saveClinic(String name, String phone, String address, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      toast(context, "Erro: Usuário não logado.");
      return;
    }

    try {
      DocumentReference newClinicRef = await FirebaseFirestore.instance.collection('clinics').add({
        'name': name,
        'phone': phone,
        'address': address,
        'type': type, // Salva no banco: 'dental', 'psychology', etc.
        'ownerId': user.uid, 
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'allowedClinics': FieldValue.arrayUnion([newClinicRef.id])
      });

      if (mounted) {
        toast(context, "Clínica de $type cadastrada com sucesso!");
      }
    } catch (e) {
      if (mounted) {
        toast(context, "Erro ao cadastrar: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const PageTitle(
                  title: "Gestão de Clínicas",
                  subtitle: "Cadastre e visualize suas unidades",
                ),
                if (_isOwner)
                  ElevatedButton.icon(
                    onPressed: () => _showAddClinicDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text("NOVA UNIDADE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _loadingRole
                  ? const Center(child: CircularProgressIndicator())
                  : (!_isOwner && _myClinicIds.isEmpty)
                      ? const Center(
                          child: Text("Nenhuma clínica liberada.",
                              style: TextStyle(color: Colors.grey)))
                      : StreamBuilder<QuerySnapshot>(
                      stream: _isOwner
                          ? FirebaseFirestore.instance
                              .collection('clinics')
                              .where('ownerId', isEqualTo: user?.uid)
                              .orderBy('createdAt', descending: true)
                              .snapshots()
                          : FirebaseFirestore.instance
                              .collection('clinics')
                              .where(FieldPath.documentId,
                                  whereIn: _myClinicIds)
                              .snapshots(),
                      builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          const Text("Nenhuma clínica cadastrada.", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      
                      // Ícone dinâmico baseado no tipo
                      IconData typeIcon = Icons.store;
                      Color typeColor = Colors.blue;
                      String typeName = "Geral";

                      switch (data['type']) {
                        case 'dental': typeIcon = Icons.medical_services; typeName = "Odontologia"; break;
                        case 'psychology': typeIcon = Icons.psychology; typeName = "Psicologia"; typeColor = Colors.purple; break;
                        case 'physiotherapy': typeIcon = Icons.accessibility_new; typeName = "Fisioterapia"; typeColor = Colors.green; break;
                        case 'yoga': typeIcon = Icons.self_improvement; typeName = "Ioga"; typeColor = Colors.orange; break;
                      }

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(typeIcon, color: typeColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? 'Sem Nome',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(typeName, style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              _infoRow(Icons.phone, data['phone'] ?? 'Não informado'),
                              const SizedBox(height: 8),
                              _infoRow(Icons.location_on, data['address'] ?? 'Não informado'),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    final type =
                                        '${data['type'] ?? 'dental'}';
                                    SessionManager().setClinic(docs[index].id,
                                        '${data['name'] ?? 'Clínica'}', type);
                                    toast(context,
                                        "Acessando: ${data['name']}");
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (c) =>
                                              const MainWebDashboard()),
                                      (route) => false,
                                    );
                                  },
                                  child: const Text("Gerenciar"),
                                ),
                              )
                            ],
                          ),
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

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}