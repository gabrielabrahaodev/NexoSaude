import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart'; // Certifique-se de ter o pacote intl no pubspec.yaml

class MockDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lista de Nomes para Randomizar
  final List<String> _firstNames = ['Ana', 'Bruno', 'Carla', 'Daniel', 'Eduarda', 'Felipe', 'Gabriela', 'Hugo', 'Isabela', 'João'];
  final List<String> _lastNames = ['Silva', 'Santos', 'Oliveira', 'Souza', 'Pereira', 'Lima', 'Ferreira', 'Costa', 'Rodrigues', 'Almeida'];

  // Gera um número de telefone fake
  String _generatePhone() {
    var rng = Random();
    String number = '9${rng.nextInt(9000) + 1000}${rng.nextInt(9000) + 1000}';
    return "11$number";
  }

  // Gera a data formatada como a UI espera (String) e Timestamp para ordenação
  Map<String, dynamic> _generateDates() {
    final now = DateTime.now();
    // Subtrai alguns minutos/horas aleatórios para parecer natural
    final randomDate = now.subtract(Duration(minutes: Random().nextInt(300))); 
    final formatted = DateFormat('dd/MM/yyyy - HH:mm').format(randomDate);
    return {
      'formatted': formatted,
      'timestamp': Timestamp.fromDate(randomDate)
    };
  }

  Future<void> generateLeads({int quantity = 5}) async {
    try {
      debugPrint("🚀 Iniciando geração de $quantity leads simulados...");

      for (int i = 0; i < quantity; i++) {
        bool isHot = Random().nextBool(); // 50% de chance de ser quente ou frio
        Map<String, dynamic> dateData = _generateDates();
        String name = "${_firstNames[Random().nextInt(_firstNames.length)]} ${_lastNames[Random().nextInt(_lastNames.length)]}";

        // Estrutura do Lead
        Map<String, dynamic> leadData = {
          "name": name,
          "phone": _generatePhone(),
          "date": dateData['formatted'], // Para exibição na UI
          "createdAt": dateData['timestamp'], // Para ordenação no backend
          "status": "Novo",
          "origin": isHot ? "Campanha Jabaquara (3km)" : "Google Orgânico",
          
          // Lógica Quente vs Frio
          "answers": isHot ? _generateHotAnswers() : _generateColdAnswers(),
          
          // Campo auxiliar para facilitar consultas futuras
          "isHotLead": isHot, 
          "clinicId": "ID_DA_CLINICA_ATUAL" // Substitua ou pegue da sessão se necessário
        };

        await _firestore.collection('leads').add(leadData);
      }

      debugPrint("✅ Sucesso! $quantity leads adicionados ao Firestore.");
    } catch (e) {
      debugPrint("❌ Erro ao gerar leads: $e");
    }
  }

  // --- PERFIL QUENTE (Ticket Alto / Dor Aguda) ---
  Map<String, String> _generateHotAnswers() {
    return {
      "desejo": "Alinhadores Invisíveis",
      "historico": "Já usei e voltou", // O grande gatilho da dor
      "prioridade": "Estética e Rapidez",
      "periodo": "Manhã"
    };
  }

  // --- PERFIL FRIO (Ticket Baixo / Curioso) ---
  Map<String, String> _generateColdAnswers() {
    return {
      "desejo": "Limpeza / Checkup",
      "historico": "Nunca usei",
      "prioridade": "Custo-benefício", // O gatilho de preço
      "periodo": "Tarde"
    };
  }
}