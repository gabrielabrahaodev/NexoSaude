import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import '../../models/appointment_model.dart';
import '../../services/remarcacao_service.dart';
import '../../services/whatsapp_helper.dart';
import '../../utils/display.dart';

/// Abre o WhatsApp sem cair no bloqueador de pop-up (web): a aba em
/// branco nasce no gesto; a URL chega após as leituras. Sem telefone,
/// fecha a aba e avisa. Retorna true se abriu.
Future<bool> openWhatsAppSafe(
  BuildContext context,
  html.WindowBase? blankTab, {
  required String phone,
  required String message,
}) async {
  String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (clean.length < 10) {
    try {
      blankTab?.close();
    } catch (_) {}
    toast(context, "Telefone não cadastrado p/ avisar.");
    return false;
  }
  if (!clean.startsWith('55')) clean = '55$clean';
  final waUrl =
      "https://wa.me/$clean?text=${Uri.encodeComponent(message)}";
  if (blankTab != null) {
    try {
      blankTab.location.href = waUrl;
      return true;
    } catch (_) {}
  }
  return WhatsAppHelper.openWhatsApp(phone: clean, message: message);
}

/// Aba em branco no gesto (evita bloqueador de pop-up na web).
html.WindowBase? openBlankTab() {
  if (!kIsWeb) return null;
  try {
    return html.window.open('', '_blank');
  } catch (_) {
    return null;
  }
}

/// Diálogo único de decisão da remarcação (agenda + Meu dia).
/// Aprovar revalida no vivo; recusar abre o WhatsApp com texto pronto.
Future<void> showRemarcarDialog(
    BuildContext context, AppointmentModel appt) async {
  final proposed = appt.proposedDate;
  if (proposed == null) return;
  var busy = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text("Pedido de remarcação"),
        content: Text(
            "${appt.patientName} propôs ${formatDateTimeShort(proposed)}."),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    final tab = openBlankTab();
                    setDlg(() => busy = true);
                    try {
                      final text = await RemarcacaoService.refuse(appt);
                      final pdoc = await FirebaseFirestore.instance
                          .collection('patients')
                          .doc(appt.patientId)
                          .get();
                      final phone =
                          '${pdoc.data()?['phone'] ?? ''}';
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (phone.isEmpty) {
                        try {
                          tab?.close();
                        } catch (_) {}
                        toast(context,
                            "Recusado. Telefone não cadastrado p/ avisar.");
                      } else {
                        await openWhatsAppSafe(context, tab,
                            phone: phone, message: text);
                      }
                    } catch (e) {
                      try {
                        tab?.close();
                      } catch (_) {}
                      if (ctx.mounted) Navigator.pop(ctx);
                      toast(context, "Falha ao recusar: $e",
                          error: true);
                    }
                  },
            child:
                const Text("Recusar e avisar", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: busy
                ? null
                : () async {
                    setDlg(() => busy = true);
                    final msg =
                        await RemarcacaoService.approve(appt);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (msg == null) {
                      toast(context, "Agendamento aceito e confirmado.",
                          ok: true);
                      if (context.mounted) {
                        await _askConfirmWhatsApp(context, appt);
                      }
                    } else {
                      toast(context, msg, error: true);
                    }
                  },
            child: const Text("Aceitar agendamento"),
          ),
        ],
      ),
    ),
  );
}

/// Após aceitar: pergunta se quer avisar o paciente no WhatsApp.
/// O horário confirmado já foi refletido no portal pelo approve.
Future<void> _askConfirmWhatsApp(
    BuildContext context, AppointmentModel appt) async {
  final proposed = appt.proposedDate;
  if (proposed == null) return;
  html.WindowBase? blankTab;
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Avisar paciente?"),
      content: Text(
          "Enviar WhatsApp confirmando ${formatDateTimeShort(proposed)} para ${appt.patientName}?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Agora não"),
        ),
        ElevatedButton(
          onPressed: () {
            blankTab = openBlankTab();
            Navigator.pop(ctx, true);
          },
          child: const Text("Enviar"),
        ),
      ],
    ),
  );
  if (send != true || !context.mounted) {
    try {
      blankTab?.close();
    } catch (_) {}
    return;
  }
  try {
    final pdoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(appt.patientId)
        .get();
    final phone = '${pdoc.data()?['phone'] ?? ''}';
    if (phone.isEmpty) {
      try {
        blankTab?.close();
      } catch (_) {}
      toast(context, "Aceito. Telefone não cadastrado p/ avisar.");
      return;
    }
    await openWhatsAppSafe(
      context,
      blankTab,
      phone: phone,
      message: confirmText(
        patientName: appt.patientName,
        confirmed: proposed,
        portalUrl: (appt.portalToken ?? '').isEmpty
            ? ''
            : portalUrl(appt.portalToken!),
      ),
    );
  } catch (e) {
    try {
      blankTab?.close();
    } catch (_) {}
    toast(context, "Falha ao abrir WhatsApp: $e", error: true);
  }
}
