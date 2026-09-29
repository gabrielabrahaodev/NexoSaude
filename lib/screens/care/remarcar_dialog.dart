import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../services/remarcacao_service.dart';
import '../../services/whatsapp_helper.dart';
import '../../utils/display.dart';

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
                        toast(context,
                            "Recusado. Telefone não cadastrado p/ avisar.");
                      } else {
                        await WhatsAppHelper.openWhatsApp(
                            phone: phone, message: text);
                      }
                    } catch (e) {
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
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Enviar"),
        ),
      ],
    ),
  );
  if (send != true || !context.mounted) return;
  try {
    final pdoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(appt.patientId)
        .get();
    final phone = '${pdoc.data()?['phone'] ?? ''}';
    if (phone.isEmpty) {
      toast(context, "Aceito. Telefone não cadastrado p/ avisar.");
      return;
    }
    await WhatsAppHelper.openWhatsApp(
      phone: phone,
      message: confirmText(
          patientName: appt.patientName, confirmed: proposed),
    );
  } catch (e) {
    toast(context, "Falha ao abrir WhatsApp: $e", error: true);
  }
}
