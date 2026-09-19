import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Lógica pura do espelho do portal (testada em
/// `test/portal_mirror_test.dart`). Escrita no Firestore vive em
/// `syncPortalMirror` (glue fino, sem teste) + rules A4.

const _tokenChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Token opaco de 32 chars (URL-safe). Quem tem o link, vê o espelho.
String newPortalToken() {
  final rnd = Random.secure();
  return List.generate(
      32, (_) => _tokenChars[rnd.nextInt(_tokenChars.length)]).join();
}

/// Monta o mapa do espelho `portal/{token}`: próximas 3 sessões futuras
/// ordenadas + débitos em aberto + Pix. Listas de entrada usam os campos
/// crus (`date`, `amount`, `paidAmount`); filtragem acontece aqui.
Map<String, dynamic> buildPortalMirror({
  required String clinicId,
  required List<Map<String, dynamic>> sessions,
  required List<Map<String, dynamic>> debts,
  required String pixKey,
  required DateTime now,
  List<String> refusedIso = const [],
}) {
  final upcoming = sessions
      .where((s) => !(s['date'] as DateTime).isBefore(now))
      .toList()
    ..sort((a, b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  // Portal mostra SÓ atrasos (vencimento < hoje), igual ao combinado:
  // sem data ou futuro não entra; quitado também não.
  final today = DateTime(now.year, now.month, now.day);
  final open = debts.where((d) {
    final amount = (d['amount'] as num).toDouble();
    final paid = (d['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final due = d['dueDate'] as DateTime?;
    return paid < amount && due != null && due.isBefore(today);
  }).toList();
  // Igual à aba Pagamentos: próximos vencimentos primeiro (sem data por último).
  open.sort((a, b) {
    final da = a['dueDate'] as DateTime?;
    final db = b['dueDate'] as DateTime?;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  final total =
      open.fold<double>(0.0, (s, d) => s + (d['amount'] as num).toDouble());
  return {
    'clinicId': clinicId,
    'sessions': upcoming.take(3).toList(),
    'debts': open.take(3).toList(),
    'debtsTotal': total,
    'debtsCount': open.length,
    'pixKey': pixKey,
    'propostasRecusadas': refusedIso,
    'updatedAt': now,
  };
}

/// Livres = grade − ocupados − recusados (strings "HH:mm", ordenado).
/// Base do espelho `portal_slots/{clinicId}` e do picker do portal.
List<String> freeSlots({
  required List<String> grade,
  required List<String> busy,
  required List<String> refused,
}) {
  final out =
      grade.where((s) => !busy.contains(s) && !refused.contains(s)).toList();
  out.sort();
  return out;
}

/// Grade-fonte v1: a mesma da agenda (08:30–20:00, slots de 30min).
List<String> dailyGrade() {
  final out = <String>[];
  for (var m = 8 * 60 + 30; m <= 20 * 60; m += 30) {
    out.add(
        "${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}");
  }
  return out;
}

String _dayKey(DateTime d) =>
    "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

String _slotTime(DateTime d) =>
    "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

/// GLUE (sem teste: depende do Firestore). Chamado pelos pontos de escrita
/// de agenda/financeiro + no login (owner/recepção) para a janela rolante.
/// Best-effort de propósito: falha no espelho NUNCA quebra a escrita principal.
class PortalMirrorSync {
  static final _db = FirebaseFirestore.instance;

  /// Reescreve `portal/{token}` do paciente. Cria o token se não existir
  /// (autocura de pacientes antigos).
  static Future<void> patient(String patientId) async {
    try {
      await _patientUnsafe(patientId);
    } catch (e) {
      debugPrint("PortalMirror paciente falhou: $e");
    }
  }

  static Future<void> _patientUnsafe(String patientId) async {
    final pRef = _db.collection('patients').doc(patientId);
    final pDoc = await pRef.get();
    final pdata = pDoc.data();
    if (pdata == null) return;
    var token = '${pdata['portalToken'] ?? ''}';
    if (token.isEmpty) {
      token = newPortalToken();
      await pRef.update({'portalToken': token});
    }
    final now = DateTime.now();
    final appts = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .limit(30)
        .get();
    final sessions = <Map<String, dynamic>>[];
    for (final d in appts.docs) {
      final m = d.data();
      final date = (m['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      sessions.add({
        'id': d.id,
        'date': date,
        'professional': '${m['dentistName'] ?? ''}',
        'dentistId': '${m['dentistId'] ?? ''}',
        'status': '${m['status'] ?? ''}',
      });
    }
    final fins = await _db
        .collection('financial')
        .where('patientId', isEqualTo: patientId)
        .limit(50)
        .get();
    final debts = <Map<String, dynamic>>[];
    for (final d in fins.docs) {
      final m = d.data();
      debts.add({
        'id': d.id,
        'title': '${m['title'] ?? 'Lançamento'}',
        'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
        'paidAmount': (m['paidAmount'] as num?)?.toDouble() ?? 0.0,
        'dueDate': (m['dueDate'] as Timestamp?)?.toDate(),
        'status': '${m['status'] ?? ''}',
      });
    }
    String pixKey = '';
    try {
      final cDoc = await _db
          .collection('clinics')
          .doc('${pdata['clinicId'] ?? ''}')
          .get();
      pixKey = '${cDoc.data()?['pixKey'] ?? ''}';
    } catch (_) {}
    final refused = <String>[];
    try {
      final mirror =
          await _db.collection('portal').doc(token).get();
      final raw = mirror.data()?['propostasRecusadas'];
      if (raw is List) refused.addAll(raw.map((e) => '$e'));
    } catch (_) {}
    await _db.collection('portal').doc(token).set(buildPortalMirror(
      clinicId: '${pdata['clinicId'] ?? ''}',
      sessions: sessions,
      debts: debts,
      pixKey: pixKey,
      now: now,
      refusedIso: refused,
    ), SetOptions(merge: true)); // merge: preserva campos do portal (statusSessao, pedidos, avisos)
  }

  static Future<void> _slotOp({
    required String clinicId,
    required String dentistId,
    required DateTime date,
    required bool occupy,
  }) async {
    try {
      if (dentistId.isEmpty) return;
      final time = _slotTime(date);
      if (!dailyGrade().contains(time)) return;
      await _db.collection('portal_slots').doc(clinicId).set({
        '$dentistId.${_dayKey(date)}': occupy
            ? FieldValue.arrayRemove([time])
            : FieldValue.arrayUnion([time]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("PortalMirror slot falhou: $e");
    }
  }

  /// Reserva o slot no espelho (agendar/bloquear).
  static Future<void> occupySlot({
    required String clinicId,
    required String dentistId,
    required DateTime date,
  }) =>
      _slotOp(
          clinicId: clinicId,
          dentistId: dentistId,
          date: date,
          occupy: true);

  /// Devolve o slot ao espelho (cancelar/desbloquear).
  static Future<void> releaseSlot({
    required String clinicId,
    required String dentistId,
    required DateTime date,
  }) =>
      _slotOp(
          clinicId: clinicId,
          dentistId: dentistId,
          date: date,
          occupy: false);

  /// Lote por dentista (bloqueio/desbloqueio do dia). Uma escrita só.
  static Future<void> adjustSlots({
    required String clinicId,
    required Map<String, List<DateTime>> byDentist,
    required bool occupy,
  }) async {
    try {
      final ops = <String, dynamic>{};
      for (final entry in byDentist.entries) {
        if (entry.key.isEmpty || entry.value.isEmpty) continue;
        final byDay = <String, List<String>>{};
        for (final s in entry.value) {
          if (!dailyGrade().contains(_slotTime(s))) continue;
          byDay
              .putIfAbsent(
                  '${entry.key}.${_dayKey(s)}', () => [])
              .add(_slotTime(s));
        }
        for (final e in byDay.entries) {
          ops[e.key] = occupy
              ? FieldValue.arrayRemove(e.value)
              : FieldValue.arrayUnion(e.value);
        }
      }
      if (ops.isEmpty) return;
      await _db
          .collection('portal_slots')
          .doc(clinicId)
          .set(ops, SetOptions(merge: true));
    } catch (e) {
      debugPrint("PortalMirror lote falhou: $e");
    }
  }

  /// Mantém a janela rolante de 14 dias (roda no login; sem backend,
  /// alguém precisa varrer). Completa faltantes, apaga dias passados.
  static Future<void> ensureWindow(String clinicId) async {
    try {
      await _ensureWindowUnsafe(clinicId);
    } catch (e) {
      debugPrint("PortalMirror janela falhou: $e");
    }
  }

  static Future<void> _ensureWindowUnsafe(String clinicId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 14));
    final users = await _db
        .collection('users')
        .where('allowedClinics', arrayContains: clinicId)
        .get();
    final dentists = users.docs
        .where((d) {
          final r = '${(d.data())['role'] ?? ''}'.toLowerCase();
          return r.contains('dentist') ||
              r == 'dentista' ||
              r == 'psicologo';
        })
        .map((d) => d.id)
        .toList();
    if (dentists.isEmpty) return;
    final appts = await _db
        .collection('appointments')
        .where('clinicId', isEqualTo: clinicId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    final busyByDentistDay = <String, Set<String>>{};
    for (final d in appts.docs) {
      final m = d.data();
      final date = (m['date'] as Timestamp?)?.toDate();
      final did = '${m['dentistId'] ?? ''}';
      if (date == null || did.isEmpty) continue;
      final st = '${m['status'] ?? ''}'.toLowerCase();
      if (st == 'cancelado') continue;
      busyByDentistDay
          .putIfAbsent('$did.${_dayKey(date)}', () => <String>{})
          .add(_slotTime(date));
    }
    final grade = dailyGrade();
    final data = <String, dynamic>{};
    for (final did in dentists) {
      for (var i = 0; i < 14; i++) {
        final day = start.add(Duration(days: i));
        final key = '$did.${_dayKey(day)}';
        final busy = busyByDentistDay[key] ?? <String>{};
        data[key] = freeSlots(grade: grade, busy: busy.toList(), refused: const []);
      }
    }
    // Apaga dias passados (limpeza da janela).
    final old = await _db.collection('portal_slots').doc(clinicId).get();
    final prune = <String, dynamic>{};
    for (final k in (old.data() ?? {}).keys) {
      final dayPart = k.contains('.') ? k.split('.').last : '';
      if (dayPart.compareTo(_dayKey(start)) < 0) {
        prune[k] = FieldValue.delete();
      }
    }
    await _db
        .collection('portal_slots')
        .doc(clinicId)
        .set({...data, ...prune}, SetOptions(merge: true));
  }
}
