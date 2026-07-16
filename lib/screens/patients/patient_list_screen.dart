import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../ui/app_theme.dart';
import 'patient_details_screen.dart'; 
import 'create_patient_screen.dart'; 
import '../../services/session_manager.dart'; 

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return AppColors.primary;
    final int hash = name.codeUnitAt(0) + (name.length > 1 ? name.codeUnitAt(1) : 0);
    final List<Color> colors = [
      Colors.blue, Colors.teal, Colors.indigo, Colors.deepPurple,
      Colors.orange, Colors.pinkAccent, Colors.green, Colors.redAccent
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager().currentClinicId;

    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        title: const Text("Meus Pacientes"),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePatientScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add),
        label: const Text("NOVO PACIENTE"),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: AppColors.surface,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: "Buscar por nome, CPF ou telefone...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchText = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .where('clinicId', isEqualTo: clinicId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erro ao carregar pacientes."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState("Nenhum paciente cadastrado.");

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final cpf = (data['cpf'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();

                  return _searchText.isEmpty ||
                      name.contains(_searchText) ||
                      cpf.contains(_searchText) ||
                      phone.contains(_searchText);
                }).toList();
                
                docs.sort((a, b) {
                  final da = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  final db = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  return db.compareTo(da);
                });

                if (docs.isEmpty) return _buildEmptyState("Nenhum paciente encontrado para a busca.");

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    // Passa o ID do documento corretamente
                    return _buildPatientCard(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final String name = data['name'] ?? 'Sem Nome';
    final String phone = data['phone'] ?? 'Sem telefone';
    final String cpf = data['cpf'] ?? '';
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final Color avatarColor = _getAvatarColor(name);

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDetailsScreen(
                patientName: name,
                patientId: docId, // CORREÇÃO: Usar docId (parâmetro) em vez de doc.id
                phone: phone,
                cpf: cpf,
                birth: data['birthDate'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'avatar_$name',
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: avatarColor.withOpacity(0.2),
                  child: Text(firstLetter, style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.phone, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(phone.isNotEmpty ? phone : "Não informado", style: AppTextStyles.caption)]),
                    if (cpf.isNotEmpty) ...[const SizedBox(height: 2), Row(children: [const Icon(Icons.badge_outlined, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(cpf, style: AppTextStyles.caption)])],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_search, size: 80, color: Colors.grey[300]), const SizedBox(height: 16), Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16))]));
  }
}