/// Contadores do sino de pendências (testado em
/// `test/pending_counts_test.dart`). UI em `main_web_dashboard.dart`.

/// Agendamentos com pedido de remarcação do portal.
int countRemarcar(Iterable<Map<String, dynamic>> docs) {
  var n = 0;
  for (final d in docs) {
    if ('${d['status'] ?? ''}'.toLowerCase() == 'remarcar') n++;
  }
  return n;
}

/// Lançamentos com "avisei que paguei" (mapa válido).
int countAvisos(Iterable<Map<String, dynamic>> docs) {
  var n = 0;
  for (final d in docs) {
    if (d['avisoPagamento'] is Map) n++;
  }
  return n;
}
