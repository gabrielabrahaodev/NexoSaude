/// Lógica pura de bloqueio por intervalo (indisponibilidade do profissional).
///
/// Um bloqueio é 1 doc em `appointments` (`status='Bloqueado'`) com
/// `date` = início e `durationMinutes` = duração. Leitores existentes
/// (`getBusySlots`, grade da agenda) já expandem por duração — este
/// arquivo só centraliza as regras:
///
/// 1. Paciente primeiro: intervalo com consulta real não pode ser bloqueado.
/// 2. Fusão: sobrepostos/adjacentes viram um doc só.
/// 3. Idempotência: mesmo intervalo existente = nada a fazer.
///
/// Sem Firebase aqui (testável). Consultas são `(start, end)` já
/// calculadas pelo chamador (`date` + `durationMinutes`).
typedef BlockSpan = ({DateTime start, DateTime end});

/// Grade de 30min: arredonda para baixo.
DateTime snapDown(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, (t.minute ~/ 30) * 30);

/// Grade de 30min: arredonda para cima.
DateTime snapUp(DateTime t) {
  final m = t.minute + (t.second > 0 || t.millisecond > 0 ? 1 : 0);
  final snapped = ((m + 29) ~/ 30) * 30;
  return DateTime(t.year, t.month, t.day, t.hour, 0)
      .add(Duration(minutes: snapped));
}

/// Choque real (intervalo meio-aberto: encostar no limite não é choque).
bool overlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

/// Para fusão: sobrepõe OU encosta (cobertura contígua = 1 doc só).
bool touchesOrOverlaps(
        DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    !aStart.isAfter(bEnd) && !bStart.isAfter(aEnd);

/// União da cobertura (exige lista não vazia).
BlockSpan unionAll(List<BlockSpan> intervals) {
  var start = intervals.first.start;
  var end = intervals.first.end;
  for (final iv in intervals.skip(1)) {
    if (iv.start.isBefore(start)) start = iv.start;
    if (iv.end.isAfter(end)) end = iv.end;
  }
  return (start: start, end: end);
}

/// Consultas reais que chocam com o intervalo (regra 1).
List<BlockSpan> findOverlaps(
    DateTime start, DateTime end, List<BlockSpan> appts) =>
    appts.where((a) => overlap(start, end, a.start, a.end)).toList();

/// Slots de 30min cobertos por [start, end) (espelho + deltas).
List<DateTime> expandSlots(DateTime start, DateTime end) {
  final out = <DateTime>[];
  var t = DateTime(start.year, start.month, start.day, start.hour,
      (start.minute ~/ 30) * 30);
  if (t.isBefore(start)) t = t.add(const Duration(minutes: 30));
  while (t.isBefore(end)) {
    out.add(t);
    t = t.add(const Duration(minutes: 30));
  }
  return out;
}

/// Regra 3: fundiu e deu no mesmo doc sozinho que já existia = sem escrita.
bool isNoOp({
  required DateTime mergedStart,
  required DateTime mergedEnd,
  required int overlappedCount,
  required DateTime existingStart,
  required DateTime existingEnd,
}) =>
    overlappedCount == 1 &&
    mergedStart == existingStart &&
    mergedEnd == existingEnd;
