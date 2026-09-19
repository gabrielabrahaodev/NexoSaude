import 'package:flutter/material.dart';

/// Helpers puros de exibição (testados em `test/display_helpers_test.dart`).
///
/// Centralizam micro-lógicas repetidas nas telas sem mudar comportamento.

/// Parse tolerante de moeda BR/US ("R$ 1.500,50", "1500.50", num, null).
/// Impede crash com banco corrompido ou digitação parcial.
double parseBRL(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return 0.0;
    // Formato US (1500.50)
    if (s.contains('.') && !s.contains(',')) {
      return double.tryParse(s.replaceAll(RegExp(r'[^0-9\-\.]'), '')) ?? 0.0;
    }
    // Formato BR (1.500,50)
    final clean =
        s.replaceAll('.', '').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9\-\.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }
  return 0.0;
}

/// "hoje" / "ontem" / "há N dias".
String daysAgoLabel(int daysAgo) {
  if (daysAgo == 0) return 'hoje';
  if (daysAgo == 1) return 'ontem';
  return 'há $daysAgo dias';
}

/// Cor do texto do slot da agenda: ocupado > selecionado > livre.
Color slotCardColor({required bool isOccupied, required bool isSelected}) {
  if (isOccupied) return Colors.grey;
  if (isSelected) return Colors.black;
  return Colors.black87;
}

/// Cor do selo do lançamento: pago > pendente > demais (cancelado).
Color chargeBadgeColor({required bool isPaid, required bool isPending}) {
  if (isPaid) return Colors.green;
  if (isPending) return Colors.red;
  return Colors.orange;
}
