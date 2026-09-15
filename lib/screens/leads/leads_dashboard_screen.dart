import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Import do serviço que criamos para gerar os dados falsos
import '../../services/mock_data_service.dart';

class LeadsDashboardScreen extends StatefulWidget {
  final Key? key;
  const LeadsDashboardScreen({this.key}) : super(key: key);

  @override
  State<LeadsDashboardScreen> createState() => _LeadsDashboardScreenState();
}

class _LeadsDashboardScreenState extends State<LeadsDashboardScreen> {
  // SIMULAÇÃO DE DADOS (Visualização estática para o layout)
  final List<Map<String, dynamic>> _leads = [
    {
      "name": "Ana Paula Souza",
      "phone": "11999999999",
      "date": "12/02/2026",
      "status": "Novo", // Novo, Em Contato, Agendado
      "origin": "Jabaquara (3km)",
      "answers": {
        "desejo": "Alinhadores Invisíveis",
        "historico": "Já usou e entortou",
        "prioridade": "Rapidez e Tecnologia",
        "periodo": "Manhã"
      }
    },
    {
      "name": "Carlos Eduardo",
      "phone": "11988888888",
      "date": "12/02/2026",
      "status": "Em Contato",
      "origin": "Metrô Jabaquara",
      "answers": {
        "desejo": "Corrigir mordida",
        "historico": "Nunca usou",
        "prioridade": "Custo-benefício",
        "periodo": "Tarde"
      }
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Usamos Scaffold aqui para permitir o FloatingActionButton
    return Scaffold(
      backgroundColor: Colors.transparent, // Mantém a cor de fundo do dashboard pai
      
      // --- BOTÃO MÁGICO PARA GERAR DADOS NO FIREBASE ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Chama o serviço para criar 5 leads aleatórios (Quentes e Frios)
          await MockDataService().generateLeads(quantity: 5);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🧪 5 Leads simulados foram enviados para o Firebase!"),
                backgroundColor: Colors.purple,
              )
            );
          }
        },
        label: const Text("Gerar Mock Data"),
        icon: const Icon(Icons.science),
        backgroundColor: Colors.purple,
        tooltip: "Gera leads de teste no banco de dados",
      ),
      
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildKpiCards(),
            const SizedBox(height: 20),
            Expanded(child: _buildLeadsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pré-Avaliação Digital",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)),
            ),
            Text(
              "Gerencie os leads da campanha Jabaquara",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            // Futuramente: Ação para recarregar lista do Firebase
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Atualizando lista...")));
          },
          icon: const Icon(Icons.refresh),
          label: const Text("Atualizar Lista"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white),
        )
      ],
    );
  }

  Widget _buildKpiCards() {
    return Row(
      children: [
        _kpiCard("Novos Leads", "12", Colors.orange),
        const SizedBox(width: 15),
        _kpiCard("Agendados", "3", Colors.green),
        const SizedBox(width: 15),
        _kpiCard("Taxa de Conv.", "25%", Colors.blue),
      ],
    );
  }

  Widget _kpiCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadsList() {
    return ListView.builder(
      itemCount: _leads.length,
      itemBuilder: (context, index) {
        final lead = _leads[index];
        final answers = lead['answers'] as Map<String, dynamic>;
        
        // Lógica de "Lead Quente": Se já usou e entortou ou quer alinhador
        bool isHotLead = answers['historico'].toString().contains("Já usou") || 
                         answers['desejo'].toString().contains("Alinhadores");

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isHotLead ? Colors.red[100] : Colors.blue[100],
                      child: Icon(Icons.person, color: isHotLead ? Colors.red : Colors.blue),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(lead['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (isHotLead)
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red[200]!)),
                                  child: const Text("🔥 QUENTE", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                          Text("${lead['origin']} • ${lead['date']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Colors.green),
                      onPressed: () {
                         _openWhatsApp(lead['phone'], lead['name']);
                      },
                      tooltip: "Chamar no WhatsApp",
                    )
                  ],
                ),
                const Divider(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoBadge(Icons.star_border, "Interesse", answers['desejo']),
                    _infoBadge(Icons.history, "Histórico", answers['historico']),
                    _infoBadge(Icons.access_time, "Prefere", answers['periodo']),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBadge(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _openWhatsApp(String phone, String name) async {
    // --- MODO DE TESTE ATIVADO ---
    // Ignora o telefone do lead e usa o seu número de teste
    String testPhone = "11973490979"; // Seu número de teste
    
    // Mensagem de abordagem padrão
    String message = "Olá $name! (TESTE DE ENVIO) Aqui é da equipe da Dra. Lauciely. Vi sua pré-avaliação sobre alinhadores e tenho uma ótima notícia...";
    
    // Constrói a URL usando o número de teste
    String url = "https://wa.me/55$testPhone?text=${Uri.encodeComponent(message)}";
    
    debugPrint("🚀 Abrindo WhatsApp de Teste para: $testPhone");

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      debugPrint("Não foi possível abrir o WhatsApp");
      // Fallback: Tenta abrir sem mensagem se falhar
      await launchUrl(Uri.parse("https://wa.me/55$testPhone"));
    }
  }
}