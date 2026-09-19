import 'dart:async';
import '../models/appointment_model.dart';
import 'appointment_service.dart';

/// Cache deslizante de MESES da agenda (economia de leitura).
///
/// Mantem assinados os meses [anterior, atual, proximo] e cancela o resto.
/// Navegar entre semanas de meses em cache custa ZERO leitura; avancar para
/// um mes novo le SOMENTE esse mes (voltar = cache, sem leitura).
/// Troca de clinica limpa tudo e recomeca.
class MonthAgendaCache {
  final AppointmentService _service = AppointmentService();

  String? _clinicId;
  final _months = <String, List<AppointmentModel>>{};
  final _subs = <String, StreamSubscription<List<AppointmentModel>>>{};
  final _controller =
      StreamController<Map<String, List<AppointmentModel>>>.broadcast();

  /// Emite o mapa atual (chave "yyyy-MM") a cada mudanca de qualquer mes.
  Stream<Map<String, List<AppointmentModel>>> get stream => _controller.stream;

  /// Meses com dados em memoria (para skeleton/contadores).
  Set<String> get cachedMonths => _months.keys.toSet();

  static String keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static DateTime monthStart(int year, int month) => DateTime(year, month, 1);

  static DateTime monthEnd(int year, int month) =>
      month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);

  /// Garante a janela [mes-1, mes, mes+1] assinada. Idempotente: sem
  /// mudanca de janela ou clinica, nao faz nada (seguro chamar no build).
  void ensureWindow(String clinicId, DateTime ref) {
    if (_clinicId != clinicId) {
      _clear();
      _clinicId = clinicId;
    }
    final center = DateTime(ref.year, ref.month, 1);
    final want = <String>{};
    for (var delta = -1; delta <= 1; delta++) {
      final m = DateTime(center.year, center.month + delta, 1);
      want.add(keyOf(m));
      _subscribe(clinicId, m);
    }
    for (final k in _subs.keys.toList()) {
      if (!want.contains(k)) {
        _subs.remove(k)?.cancel();
        _months.remove(k);
      }
    }
  }

  void _subscribe(String clinicId, DateTime month) {
    final key = keyOf(month);
    if (_subs.containsKey(key)) return;
    _subs[key] = _service
        .getByDateRange(
          clinicId,
          monthStart(month.year, month.month),
          monthEnd(month.year, month.month),
        )
        .listen((list) {
      _months[key] = list;
      _controller.add(Map.unmodifiable(_months));
    }, onError: (e) => _controller.addError(e));
  }

  /// Agendamentos em cache dentro da semana visivel [start, end).
  /// Mesmos limites do `getByDateRange` (inclui inicio, exclui fim).
  List<AppointmentModel> forWeek(DateTime start, DateTime end) {
    final out = <AppointmentModel>[];
    for (final list in _months.values) {
      for (final a in list) {
        if (!a.date.isBefore(start) && a.date.isBefore(end)) out.add(a);
      }
    }
    return out;
  }

  void _clear() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _months.clear();
  }

  void dispose() {
    _clear();
    _controller.close();
  }
}
