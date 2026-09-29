import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import '../services/whatsapp_helper.dart';
import 'display.dart';

/// Links externos sem cair no bloqueador de pop-up (web).
///
/// Regra: `openBlankTab()` como PRIMEIRA linha do handler (roda síncrono
/// no gesto); a URL chega depois dos `await`s via `openLinkSafe` /
/// `openWhatsAppSafe`. Sem telefone ou com falha, a aba é fechada.

/// Aba em branco no gesto (evita bloqueador de pop-up na web).
html.WindowBase? openBlankTab() {
  if (!kIsWeb) return null;
  try {
    return html.window.open('', '_blank');
  } catch (_) {
    return null;
  }
}

void _closeQuietly(html.WindowBase? tab) {
  try {
    tab?.close();
  } catch (_) {}
}

/// Consome a aba com a URL; sem aba (mobile) cai p/ launchUrl.
Future<bool> openLinkSafe(html.WindowBase? tab, String url) async {
  if (tab != null) {
    try {
      tab.location.href = url;
      return true;
    } catch (_) {}
  }
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  }
  _closeQuietly(tab);
  return false;
}

/// WhatsApp com validação de telefone + fechamento da aba em falha.
Future<bool> openWhatsAppSafe(
  BuildContext context,
  html.WindowBase? tab, {
  required String phone,
  required String message,
}) async {
  String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (clean.length < 10) {
    _closeQuietly(tab);
    toast(context, "Telefone não cadastrado p/ avisar.");
    return false;
  }
  if (!clean.startsWith('55')) clean = '55$clean';
  final waUrl =
      "https://wa.me/$clean?text=${Uri.encodeComponent(message)}";
  if (tab != null) {
    try {
      tab.location.href = waUrl;
      return true;
    } catch (_) {}
  }
  return WhatsAppHelper.openWhatsApp(phone: clean, message: message);
}
