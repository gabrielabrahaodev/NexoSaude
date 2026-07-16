import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class WhatsAppHelper {
  // Templates rotativos para evitar Spam
  static String getMessage(String patientName, double amount, DateTime dueDate) {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(amount);
    final date = DateFormat('dd/MM').format(dueDate);
    
    final templates = [
      "Olá *$patientName*, tudo bem? 👋\nLembrete amigável sobre a parcela de *$money* com vencimento em *$date*.\nPodemos enviar o código de barras?",
      
      "Bom dia *$patientName*.\nNotamos uma pendência de *$money* (venceu dia $date) no seu cadastro.\nConsegue regularizar hoje para evitar juros?",
      
      "Oi *$patientName*! 😁\nPara manter seu tratamento em dia, não esqueça da fatura de *$money*.\nQualquer dúvida, estou à disposição!"
    ];

    return templates[Random().nextInt(templates.length)];
  }

  static Future<bool> openWhatsApp({required String phone, required String message}) async {
    // 1. Limpeza rigorosa do telefone
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // 2. Validação básica de DDI
    if (cleanPhone.length < 10) return false; // Número inválido
    if (!cleanPhone.startsWith('55')) cleanPhone = '55$cleanPhone';

    // 3. Montagem da URL (Encode é vital para caracteres especiais)
    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

    // 4. Lançamento
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}