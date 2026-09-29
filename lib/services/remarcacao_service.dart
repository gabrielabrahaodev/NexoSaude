import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import 'appointment_service.dart';
import 'portal_mirror.dart';
import '../utils/display.dart';

/// Link público do portal a partir do token.
String portalUrl(String token) =>
    'https://nexosaude.web.app/sistema-interno/portal.html?t=$token';

/// Texto do WhatsApp de recusa (testado): pede nova escolha com o link.
String refuseText({
  required String patientName,
  required DateTime proposed,
  String portalUrl = '',
}) {
  final when = formatDateShort(proposed);
  final hour = DateFormat('HH:mm').format(proposed);
  final link = portalUrl.isEmpty ? '' : ' Escolha outro horário aqui: $portalUrl';
  return 'Olá $patientName, a data $when às $hour não está mais disponível.$link';
}

/// Texto do WhatsApp de confirmação (testado): novo horário aprovado.
String confirmText({
  required String patientName,
  required DateTime confirmed,
}) {
  final when = formatDateShort(confirmed);
  final hour = DateFormat('HH:mm').format(confirmed);
  return 'Olá $patientName, sua consulta foi confirmada para $when às $hour. Até lá!';
}

String _isoSlot(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

/// Caixa de pendências da remarcação (glue: sem teste, depende do Firestore).
/// Aprovar revalida no vivo; recusar volta p/ Agendado e esconde o slot
/// SÓ desse paciente (segue livre para os demais).
class RemarcacaoService {
  static final _db = FirebaseFirestore.instance;

  /// Aprova: revalida choque, move a data, confirma, sincroniza espelhos.
  /// Retorna null se ok, ou o motivo do bloqueio.
  static Future<String?> approve(AppointmentModel appt) async {
    final proposed = appt.proposedDate;
    if (proposed == null) return "Sem data proposta.";
    try {
      final busy = await AppointmentService().getBusySlots(
        appt.clinicId,
        proposed,
        excludeId: appt.id,
      );
      final want =
          "${proposed.hour.toString().padLeft(2, '0')}:${proposed.minute.toString().padLeft(2, '0')}";
      if (busy.contains(want)) {
        return "Horário ocupado no vivo. Recuse e peça outra data.";
      }
      await _db.collection('appointments').doc(appt.id).update({
        'date': Timestamp.fromDate(proposed),
        'status': 'Confirmado',
        'proposedDate': null,
      });
      await PortalMirrorSync.releaseSlot(
        clinicId: appt.clinicId,
        dentistId: appt.dentistId ?? '',
        date: appt.date,
      );
      await PortalMirrorSync.occupySlot(
        clinicId: appt.clinicId,
        dentistId: appt.dentistId ?? '',
        date: proposed,
      );
      await PortalMirrorSync.upsertSession(
        patientId: appt.patientId,
        token: (appt.portalToken ?? '').isEmpty
            ? null
            : appt.portalToken,
        session: {
          'id': appt.id,
          'date': proposed,
          'professional': '',
          'dentistId': appt.dentistId ?? '',
          'status': 'Confirmado',
        },
      );
      final token = appt.portalToken ?? '';
      if (token.isNotEmpty) {
        await _db.collection('portal').doc(token).set({
          'pedidoRemarcacao': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
      return null;
    } catch (e) {
      debugPrint("Aprovar remarcacao falhou: $e");
      return "Falha ao aprovar: $e";
    }
  }

  /// Recusa: volta p/ Agendado, registra nas recusadas, limpa o pedido.
  /// Retorna o texto pronto p/ o caller abrir no WhatsApp.
  static Future<String> refuse(AppointmentModel appt) async {
    final proposed = appt.proposedDate;
    final token = appt.portalToken ?? '';
    await _db.collection('appointments').doc(appt.id).update({
      'status': 'Aguardando Confirmação',
      'proposedDate': null,
    });
    await PortalMirrorSync.upsertSession(
      patientId: appt.patientId,
      token:
          (appt.portalToken ?? '').isEmpty ? null : appt.portalToken,
      session: {
        'id': appt.id,
        'date': appt.date,
        'professional': '',
        'dentistId': appt.dentistId ?? '',
        'status': 'Aguardando Confirmação',
      },
    );
    if (token.isNotEmpty) {
      final data = <String, dynamic>{
        'pedidoRemarcacao': FieldValue.delete(),
      };
      if (proposed != null) {
        data['propostasRecusadas'] =
            FieldValue.arrayUnion([_isoSlot(proposed)]);
      }
      await _db
          .collection('portal')
          .doc(token)
          .set(data, SetOptions(merge: true));
    }
    return refuseText(
      patientName: appt.patientName,
      proposed: proposed ?? appt.date,
      portalUrl: token.isEmpty ? '' : portalUrl(token),
    );
  }
}
