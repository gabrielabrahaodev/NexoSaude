import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Lógica pura do espelho do portal (testada em
/// `test/portal_mirror_test.dart`). Escrita no Firestore vive em
/// `syncPortalMirror` (glue fino, sem teste) + rules A4.

const _tokenChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Quem tem agenda no portal: papéis clínicos + owner de clínica
/// psicológica (psicólogo atuante). Puro e testado; usado pelo rebuild
/// da janela (`ensureWindow`) e replicado em `migrate/slots-backfill.js`.
bool isPortalProfessional({
  required String role,
  required String clinicType,
}) {
  final r = role.toLowerCase();
  if (r.contains('dentist') || r == 'dentista' || r == 'psicologo') {
    return true;
  }
  return clinicType == 'psychology' && r == 'owner';
}

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
  String clinicName = '',
  required List<Map<String, dynamic>> sessions,
  required List<Map<String, dynamic>> debts,
  required String pixKey,
  required DateTime now,
  List<String> refusedIso = const [],
}) {
  final upcoming = sessions
      .where((s) {
        // Cancelada não é "próxima": delta remove do espelho, rebuild igual.
        final st = '${s['status'] ?? ''}'.toLowerCase();
        if (st == 'cancelado' || st == 'cancelled') return false;
        return !(s['date'] as DateTime).isBefore(now);
      })
      .toList()
    ..sort((a, b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  // Portal mostra as 3 mais antigas EM ABERTO (vencidas ou não),
  // ordenadas por vencimento: sem data, quitada, cancelada ou
  // substituída não entra.
  final open = debts.where((d) {
    final amount = (d['amount'] as num).toDouble();
    final paid = (d['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final due = d['dueDate'] as DateTime?;
    final st = '${d['status'] ?? ''}'.toLowerCase();
    if (st == 'cancelado' ||
        st == 'cancelled' ||
        st.contains('substitu')) return false;
    return paid < amount && due != null;
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
    'clinicName': clinicName,
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

/// Upsert de sessão no espelho (por id). Puro e testado.
List<Map<String, dynamic>> applySessionUpsert(
    List sessions, Map<String, dynamic> s) {
  final out = [
    for (final e in sessions) Map<String, dynamic>.from(e as Map)
  ];
  final i =
      out.indexWhere((e) => '${e['id']}' == '${s['id']}');
  if (i >= 0) {
    out[i] = {...out[i], ...s};
  } else {
    out.add(Map<String, dynamic>.from(s));
  }
  return out;
}

/// Remove sessão do espelho (por id). Puro e testado.
List<Map<String, dynamic>> applySessionRemove(
    List sessions, String id) {
  return [
    for (final e in sessions)
      if ('${(e as Map)['id']}' != id)
        Map<String, dynamic>.from(e)
  ];
}

/// Upsert de débito: pago/cancelado vira remoção. Puro e testado.
List<Map<String, dynamic>> applyDebtUpsert(
    List debts, Map<String, dynamic> d) {
  final st = '${d['status'] ?? ''}'.toLowerCase();
  final paid = (d['paidAmount'] as num?)?.toDouble() ?? 0.0;
  final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
  final dead = st == 'cancelado' ||
      st == 'cancelled' ||
      (amount > 0 && paid >= amount) ||
      st == 'pago' ||
      st == 'paid' ||
      st == 'quitado';
  final out = [
    for (final e in debts) Map<String, dynamic>.from(e as Map)
  ];
  out.removeWhere((e) => '${e['id']}' == '${d['id']}');
  if (!dead) out.add(Map<String, dynamic>.from(d));
  return out;
}

/// Grade de horários (configurável por clínica; default = agenda atual).
/// `gradeConfig` em `clinics/{id}`: {start: "08:30", end: "20:00", slot: 30}.
List<String> dailyGrade({String start = '08:30', String end = '20:00', int slot = 30}) {
  int toMin(String s) {
    final p = s.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  final out = <String>[];
  for (var m = toMin(start); m <= toMin(end); m += slot) {
    out.add(
        "${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}");
  }
  return out;
}

/// Lê a grade da clínica (com fallback para o default).
Future<List<String>> clinicGrade(String clinicId) async {  try {
    final doc = await FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .get();
    final cfg = (doc.data()?['gradeConfig'] as Map?) ?? {};
    return dailyGrade(
      start: '${cfg['start'] ?? '08:30'}',
      end: '${cfg['end'] ?? '20:00'}',
      slot: (cfg['slot'] as num?)?.toInt() ?? 30,
    );
    } catch (_) {
      return dailyGrade();
    }
}

/// Tipo da clínica (`dental` por fallback). Usado para incluir o
/// owner-psicólogo nos profissionais do portal (1 leitura).
Future<String> clinicTypeOf(String clinicId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .get();
    return '${doc.data()?['type'] ?? 'dental'}';
  } catch (_) {
    return 'dental';
  }
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
      // LGPD linha dura: token só nasce com aceite explícito (checkbox,
      // diálogo do balcão ou cadastro rápido). Sem aceite, sem link —
      // sem autocura de legados (sweep 09/2026 apagou os sem aceite).
      final consent = (pdata['lgpdPortalConsent'] as Map?)?['accepted'];
      if (consent != true) return;
      token = newPortalToken();
      await pRef.update({'portalToken': token});
    }
    final now = DateTime.now();
    // Limites altos de propósito: pacote psico gera ~52 appointments/ano;
    // limit baixo + sem orderBy truncava futuros (portal sem psicologia).
    final appts = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .limit(100)
        .get();
    final sessions = <Map<String, dynamic>>[];
    for (final d in appts.docs) {
      final m = d.data();
      final date = (m['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      if ('${m['status'] ?? ''}'.toLowerCase() == 'cancelado') continue;
      final prof = '${m['dentistName'] ?? ''}';
      sessions.add({
        'id': d.id,
        'date': date,
        // Psico não tem dentistName: mostra o procedimento ("Pacote ...").
        'professional': prof.isEmpty ? '${m['procedure'] ?? ''}' : prof,
        'dentistId': '${m['dentistId'] ?? ''}',
        'status': '${m['status'] ?? ''}',
      });
    }
    final fins = await _db
        .collection('financial')
        .where('patientId', isEqualTo: patientId)
        .limit(100)
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
    String clinicName = '';
    try {
      final cDoc = await _db
          .collection('clinics')
          .doc('${pdata['clinicId'] ?? ''}')
          .get();
      pixKey = '${cDoc.data()?['pixKey'] ?? ''}';
      clinicName = '${cDoc.data()?['name'] ?? ''}';
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
      clinicName: clinicName,
      sessions: sessions,
      debts: debts,
      pixKey: pixKey,
      now: now,
      refusedIso: refused,
    ), SetOptions(merge: true)); // merge: preserva campos do portal (statusSessao, pedidos, avisos)
  }

  /// Delta: token do paciente (1 leitura) ou null.
  static Future<String?> _tokenOf(String patientId) async {
    try {
      final p = await _db.collection('patients').doc(patientId).get();
      final t = '${(p.data() ?? {})['portalToken'] ?? ''}';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _patchList(
    String token,
    String key,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) fn,
  ) async {
    try {
      final ref = _db.collection('portal').doc(token);
      final snap = await ref.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final list = ((data[key] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await ref.set({
        key: fn(list),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("PortalMirror delta falhou: $e");
    }
  }

  /// Delta de sessão (2 leituras + 1 escrita, sem scans).
  static Future<void> upsertSession({
    required String patientId,
    String? token,
    required Map<String, dynamic> session,
  }) async {
    token ??= await _tokenOf(patientId);
    if (token == null || token.isEmpty) return;
    await _patchList(
        token, 'sessions', (l) => applySessionUpsert(l, session));
  }

  /// Remove sessão do espelho.
  static Future<void> removeSession({
    required String patientId,
    String? token,
    required String sessionId,
  }) async {
    token ??= await _tokenOf(patientId);
    if (token == null || token.isEmpty) return;
    await _patchList(
        token, 'sessions', (l) => applySessionRemove(l, sessionId));
  }

  /// Delta de débito (pago/cancelado vira remoção).
  static Future<void> upsertDebt({
    required String patientId,
    String? token,
    required Map<String, dynamic> debt,
  }) async {
    token ??= await _tokenOf(patientId);
    if (token == null || token.isEmpty) return;
    await _patchList(
        token, 'debts', (l) => applyDebtUpsert(l, debt));
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
      if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) return;
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
          if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(_slotTime(s))) continue;
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
    // Throttle: 1 leitura; se a janela foi construída há < 6h, não faz nada.
    final slotsRef = _db.collection('portal_slots').doc(clinicId);
    final old = await slotsRef.get();
    final builtAt = (old.data()?['windowBuiltAt'] as Timestamp?)?.toDate();
    if (builtAt != null &&
        now.difference(builtAt) < const Duration(hours: 6)) {
      return;
    }
    final grade = await clinicGrade(clinicId);
    final clinicType = await clinicTypeOf(clinicId);
    final users = await _db
        .collection('users')
        .where('allowedClinics', arrayContains: clinicId)
        .get();
    final dentists = users.docs
        .where((d) => isPortalProfessional(
              role: '${(d.data())['role'] ?? ''}',
              clinicType: clinicType,
            ))
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
      // Expande pela duração (bloco por intervalo e consultas longas
      // ocupam todos os slots cobertos, igual à grade e ao getBusySlots).
      final dur = (m['durationMinutes'] as num?)?.toInt() ?? 30;
      final steps = dur <= 0 ? 1 : (dur / 30).ceil();
      for (var i = 0; i < steps; i++) {
        final slot = date.add(Duration(minutes: 30 * i));
        busyByDentistDay
            .putIfAbsent('$did.${_dayKey(slot)}', () => <String>{})
            .add(_slotTime(slot));
      }
    }
    final data = <String, dynamic>{};
    for (final did in dentists) {
      for (var i = 0; i < 14; i++) {
        final day = start.add(Duration(days: i));
        final key = '$did.${_dayKey(day)}';
        final busy = busyByDentistDay[key] ?? <String>{};
        data[key] = freeSlots(grade: grade, busy: busy.toList(), refused: const []);
      }
    }
    // Apaga dias passados (limpeza da janela; reusa o doc já lido).
    // Pula metadados (windowBuiltAt) — só chaves '{dentistId}.{dia}'.
    final prune = <String, dynamic>{};
    for (final k in (old.data() ?? {}).keys) {
      if (!k.contains('.')) continue;
      final dayPart = k.split('.').last;
      if (dayPart.compareTo(_dayKey(start)) < 0) {
        prune[k] = FieldValue.delete();
      }
    }
    await slotsRef.set(
        {...data, ...prune, 'windowBuiltAt': Timestamp.fromDate(now)},
        SetOptions(merge: true));
  }
}
