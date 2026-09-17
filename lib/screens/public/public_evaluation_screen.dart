import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Descomente se configurou web plugins

class PublicEvaluationScreen extends StatefulWidget {
  const PublicEvaluationScreen({Key? key}) : super(key: key);

  @override
  _PublicEvaluationScreenState createState() => _PublicEvaluationScreenState();
}

class _PublicEvaluationScreenState extends State<PublicEvaluationScreen> {
  // --- VARIÁVEIS DE ESTADO (ESSAS ERAM AS QUE FALTAVAM) ---
  String? clinicId;
  Map<String, dynamic>? clinicData;
  bool isLoading = true;
  
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  
  int _score = 0; 
  List<String> _answers = []; 
  bool _isSaving = false;

  // Perguntas do Questionário
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Qual o seu maior desejo hoje?',
      'options': [
        {'text': 'Alinhar de forma discreta (Alinhadores)', 'value': 'aligner', 'score': 10},
        {'text': 'Corrigir mordida ou dores', 'value': 'pain', 'score': 8},
        {'text': 'Limpeza/Check-up de rotina', 'value': 'cleaning', 'score': 1},
      ]
    },
    {
      'question': 'Você já usou aparelho antes?',
      'options': [
        {'text': 'Sim, mas voltaram a entortar', 'value': 'relapse', 'score': 20},
        {'text': 'Não, primeira vez', 'value': 'first_time', 'score': 5},
        {'text': 'Sim, quero trocar de dentista', 'value': 'switching', 'score': 15},
      ]
    },
    {
      'question': 'Qual sua prioridade?',
      'options': [
        {'text': 'Rapidez e Tecnologia', 'value': 'speed', 'score': 10},
        {'text': 'Estética Extrema (Imperceptível)', 'value': 'aesthetic', 'score': 10},
        {'text': 'Custo-benefício', 'value': 'cost', 'score': 2},
      ]
    },
    {
      'question': 'Melhor horário para contato?',
      'options': [
        {'text': 'Prefiro agendar pelo WhatsApp agora', 'value': 'whatsapp_now', 'score': 5},
        {'text': 'Manhã (08h - 12h)', 'value': 'morning', 'score': 0},
        {'text': 'Tarde (13h - 18h)', 'value': 'afternoon', 'score': 0},
      ]
    }
  ];

  @override
  void initState() {
    super.initState();
    _loadClinicData();
  }

  // 1. Carrega dados da clínica via URL
  Future<void> _loadClinicData() async {
    // Tenta pegar o ID da URL (ex: ?cid=123)
    final uri = Uri.base;
    clinicId = uri.queryParameters['cid'];

    // Sem CID = link inválido: NÃO usar fallback (antes gravava leads de
    // teste na clínica real). O build mostra "Clínica não encontrada."
    if (clinicId == null || clinicId!.isEmpty) {
      debugPrint("Avaliação sem CID na URL — link inválido.");
      if (mounted) setState(() => isLoading = false);
      return;
    }

    if (clinicId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('clinics').doc(clinicId).get();
        if (doc.exists) {
          setState(() {
            clinicData = doc.data();
            isLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Erro ao carregar clínica: $e");
      }
    }
    
    setState(() => isLoading = false);
  }

  // 2. Lógica de seleção de resposta
  void _selectOption(Map<String, dynamic> option) {
    setState(() {
      _score += (option['score'] as int);
      _answers.add(option['text'] as String);
    });

    if (_currentIndex < _questions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentIndex++);
    } else {
      _submitForm();
    }
  }

  // 3. Envia para o Firestore
  Future<void> _submitForm() async {
    if (clinicId == null) return;

    setState(() => _isSaving = true);

    final leadData = {
      'answers': _answers, 
      'score': _score,
      'createdAt': FieldValue.serverTimestamp(),
      'origin': 'web_form',
      'status': 'new_lead',
    };

    try {
      await FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .collection('leads') // Vai criar a subcoleção leads dentro de Jabaquara
          .add(leadData);

      _launchWhatsAppRedirect();
      
    } catch (e) {
      debugPrint("Erro Firestore: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao salvar.")));
      setState(() => _isSaving = false);
    }
  }

  // 4. Redireciona para o WhatsApp
  Future<void> _launchWhatsAppRedirect() async {
    // CORREÇÃO: Busca o campo 'phone' conforme seu print (ou 'whatsapp' como fallback)
    final rawPhone = clinicData?['phone'] ?? clinicData?['whatsapp'] ?? '5511999999999';
    
    // Limpeza: garante que só tem números
    final cleanPhone = rawPhone.toString().replaceAll(RegExp(r'[^\d]'), '');
    
    // Se o número do banco já tiver 55 (DDI), não adiciona. Se não tiver, adiciona.
    final finalPhone = cleanPhone.startsWith('55') ? cleanPhone : "55$cleanPhone";

    final message = "Olá! Vim pela Avaliação Online. Meu Score foi: $_score pontos.";
    
    final url = Uri.parse("https://wa.me/$finalPhone?text=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      setState(() => _isSaving = false);
      showDialog(
        context: context, 
        builder: (_) => AlertDialog(
          title: const Text("Sucesso!"),
          content: Text("Envie para o WhatsApp: $finalPhone"),
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (clinicData == null) {
      return const Scaffold(body: Center(child: Text("Clínica não encontrada.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(clinicData?['name'] ?? "Avaliação"), // Deve aparecer "Jabaquara"
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _isSaving 
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length, color: Colors.amber),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final question = _questions[index];
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                question['question'],
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 40),
                              ...(question['options'] as List).map((option) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.all(20),
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.teal[900],
                                      side: BorderSide(color: Colors.teal.shade100),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                    ),
                                    onPressed: () => _selectOption(option),
                                    child: Text(option['text'], style: const TextStyle(fontSize: 18)),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}