/// BR Code Pix estático (copia-e-cola + QR) — 100% local, grátis, sem API.
/// Padrão aberto Bacen/EMVCo: payload + CRC16-CCITT-FALSE.
/// Testado em `test/pix_brcode_test.dart` (vetor 29B1 + montagem).
library;

/// CRC16-CCITT-FALSE (poly 0x1021, init 0xFFFF).
int crc16(String data) {
  var crc = 0xFFFF;
  for (final unit in data.codeUnits) {
    crc ^= (unit << 8);
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}

String _field(String id, String value) {
  return '$id${value.length.toString().padLeft(2, '0')}$value';
}

const _accents = {
  'á': 'A', 'à': 'A', 'ã': 'A', 'â': 'A', 'ä': 'A',
  'é': 'E', 'è': 'E', 'ê': 'E', 'ë': 'E',
  'í': 'I', 'ì': 'I', 'î': 'I', 'ï': 'I',
  'ó': 'O', 'ò': 'O', 'õ': 'O', 'ô': 'O', 'ö': 'O',
  'ú': 'U', 'ù': 'U', 'û': 'U', 'ü': 'U',
  'ç': 'C', 'ñ': 'N',
};

/// Maiúsculo, sem acento, só [A-Z0-9 .,-], truncado.
String _norm(String s, int max) {
  var out = s.toLowerCase().split('').map((c) => _accents[c] ?? c).join();
  out = out.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 .,\-]'), '');
  if (out.length > max) out = out.substring(0, max);
  return out;
}

/// Monta o BR Code. Sem [amount] = valor aberto (sem campo 54).
/// [txid] alfanumérico sem espaço (default `***`).
String pixBrCode({
  required String chave,
  double? amount,
  required String nome,
  required String cidade,
  String txid = '***',
}) {
  final gui = _field('00', 'br.gov.bcb.pix') + _field('01', chave.trim());
  var payload = _field('00', '01') +
      _field('26', gui) +
      _field('52', '0000') +
      _field('53', '986');
  if (amount != null && amount > 0) {
    payload += _field('54', amount.toStringAsFixed(2));
  }
  payload += _field('58', 'BR') +
      _field('59', _norm(nome, 25)) +
      _field('60', _norm(cidade, 15)) +
      _field('62', _field('05', txid)) +
      '6304';
  final crc = crc16(payload).toRadixString(16).toUpperCase().padLeft(4, '0');
  return payload + crc;
}
