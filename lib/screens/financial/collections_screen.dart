import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/financial_model.dart';
import '../../services/session_manager.dart';
import '../../services/whatsapp_helper.dart'; // Importe o novo helper

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> with WidgetsBindingObserver {
  DateTime _currentMonth = DateTime.now();
  String _filterName = "";
  
  // Controle de quem está sendo cobrado no momento para exibir o Dialog ao voltar
  String? _currentProcessingId;
  String? _currentProcessingName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Escuta o ciclo de vida do app
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Detecta quando o usuário volta do WhatsApp
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentProcessingId != null) {
      // Pequeno delay para garantir que a UI estabilizou
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showConfirmationDialog();
      });
    }
  }

  void _changeMonth(int i) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + i, 1);
    });
  }

  // Ação de Cobrança Individual (Híbrida)
  Future<void> _handleCharge(FinancialModel item) async {
    // 1. Busca dados atualizados do paciente (Telefone)
    final docPatient = await FirebaseFirestore.instance.collection('patients').doc(item.patientId).get();
    
    if (!docPatient.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Paciente não encontrado.")));
      return;
    }

    final data = docPatient.data();
    var rawPhone = data?['phone'] ?? data?['celular'] ?? data?['whatsapp'];
    String? phone = rawPhone?.toString().trim();

    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Paciente sem telefone cadastrado.")));
      return;
    }

    // 2. Gera mensagem rotativa
    final message = WhatsAppHelper.getMessage(item.patientName, item.amount, item.dueDate ?? DateTime.now());

    // 3. Abre WhatsApp
    final success = await WhatsAppHelper.openWhatsApp(phone: phone, message: message);

    if (success) {
      // Marca que estamos aguardando retorno deste item
      setState(() {
        _currentProcessingId = item.id;
        _currentProcessingName = item.patientName;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o WhatsApp.")));
    }
  }

  // Dialog de Confirmação (O Humano confirma o envio)
  void _showConfirmationDialog() {
    final id = _currentProcessingId;
    final name = _currentProcessingName;
    
    // Limpa estado para não abrir de novo
    setState(() {
      _currentProcessingId = null;
      _currentProcessingName = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Confirmação: $name"),
        content: const Text("Você enviou a mensagem de cobrança no WhatsApp?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Não / Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _markAsCharged(id!);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("SIM, Marcar Cobrado"),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsCharged(String financialId) async {
    try {
      await FirebaseFirestore.instance.collection('financial').doc(financialId).update({
        'status': 'cobrado', // Ou manter pendente e usar lastContactDate para filtrar visualmente
        'lastContactDate': FieldValue.serverTimestamp(),
        'contactHistory': FieldValue.arrayUnion([
          {'date': DateTime.now().toIso8601String(), 'method': 'whatsapp_manual'}
        ])
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status atualizado com sucesso!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao atualizar status.")));
    }
  }

  DateTime get _startOfMonth => DateTime(_currentMonth.year, _currentMonth.month, 1);
  DateTime get _endOfMonth => DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    final clinicId = SessionManager().currentClinicId;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Cobrança Manual Inteligente", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Filtros de Mês
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
                Text(DateFormat('MMMM yyyy', 'pt_BR').format(_currentMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // Lista de Cobrança
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('financial')
                  .where('clinicId', isEqualTo: clinicId)
                  .where('status', isEqualTo: 'pendente') // Traz só o que precisa cobrar
                  .where('type', isEqualTo: 'income')
                  .where('dueDate', isGreaterThanOrEqualTo: _startOfMonth)
                  .where('dueDate', isLessThanOrEqualTo: _endOfMonth)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                   return Center(child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.check_circle, size: 60, color: Colors.green[200]),
                       const SizedBox(height: 10),
                       const Text("Tudo em dia! Nenhuma cobrança pendente.", style: TextStyle(color: Colors.grey)),
                     ],
                   ));
                }

                // Filtragem local por nome (se necessário)
                final filteredDocs = docs.where((doc) {
                   final data = doc.data() as Map<String, dynamic>;
                   final name = (data['patientName'] ?? '').toString().toLowerCase();
                   return name.contains(_filterName.toLowerCase());
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final item = FinancialModel.fromMap(filteredDocs[index].id, data);
                    
                    // Verifica se já foi contatado hoje (opcional, para UI)
                    final lastContact = data['lastContactDate'] as Timestamp?;
                    bool contactedToday = false;
                    if (lastContact != null) {
                      final contactDate = lastContact.toDate();
                      final now = DateTime.now();
                      contactedToday = contactDate.year == now.year && contactDate.month == now.month && contactDate.day == now.day;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: contactedToday ? Colors.grey : Colors.green[100],
                          child: Icon(Icons.chat, color: contactedToday ? Colors.white : Colors.green[800]),
                        ),
                        title: Text(item.patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${item.title} - Vence: ${DateFormat('dd/MM').format(item.dueDate!)}"),
                            if (contactedToday) 
                              const Text("Já contatado hoje", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("R\$ ${item.amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 10),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () => _handleCharge(item),
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}