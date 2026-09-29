import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

/// "R$ 1500.50" (2 casas, ponto decimal — igual ao `toStringAsFixed(2`
/// usado nas telas; sem locale para nao mudar nenhuma string exibida).
String formatBRL(num value) => 'R\$ ${value.toStringAsFixed(2)}';

/// Datas pt-BR centralizadas (mesma saída dos `DateFormat` espalhados).
String formatDateShort(DateTime d) => DateFormat('dd/MM').format(d);
String formatDateTimeShort(DateTime d) => DateFormat('dd/MM HH:mm').format(d);
String formatDateFull(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String formatDateShortYear(DateTime d) => DateFormat('dd/MM/yy').format(d);
String formatDateTimeFull(DateTime d) =>
    DateFormat('dd/MM/yyyy HH:mm').format(d);
String formatDateDash(DateTime d) =>
    DateFormat('dd/MM/yyyy - HH:mm').format(d);
String formatDateDot(DateTime d) => DateFormat('dd/MM • HH:mm').format(d);
String formatDateAs(DateTime d) => DateFormat('dd/MM às HH:mm').format(d);

/// Atalho de SnackBar com o padrao do app: neutra, vermelha (erro), verde
/// (ok) ou cor explícita. Mesma aparencia das chamadas manuais que substitui.
void toast(BuildContext context, String msg,
    {bool error = false,
    bool ok = false,
    Color? color,
    Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor:
        color ?? (error ? Colors.red : (ok ? Colors.green : null)),
    duration: duration ?? const Duration(seconds: 4),
  ));
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

/// Mês de nascimento ("MM") p/ query de aniversariantes do KPI.
/// Aceita String dd/MM/yyyy e DateTime; nulo quando não derivável.
String? birthMonthOf(dynamic birthDate) {
  if (birthDate == null) return null;
  if (birthDate is DateTime) {
    return birthDate.month.toString().padLeft(2, '0');
  }
  if (birthDate is String) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$')
        .firstMatch(birthDate.trim());
    if (m == null) return null;
    final month = int.tryParse(m.group(2)!);
    if (month == null || month < 1 || month > 12) return null;
    return month.toString().padLeft(2, '0');
  }
  return null;
}

/// Cor do selo do lançamento: pago > pendente > demais (cancelado).
Color chargeBadgeColor({required bool isPaid, required bool isPending}) {
  if (isPaid) return Colors.green;
  if (isPending) return Colors.red;
  return Colors.orange;
}

/// WhatsApp canônico E.164 BR (só dígitos, com 55): aceita
/// "(11) 98765-4321", "11987654321", "+5511987654321", "5511…".
/// Nulo quando inválido. Usado no cadastro da clínica (n8n/Evolution).
String? normalizeWhatsApp(String? raw) {
  if (raw == null) return null;
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('55') && (d.length == 12 || d.length == 13)) return d;
  if (!d.startsWith('55') && (d.length == 10 || d.length == 11)) {
    return '55$d';
  }
  return null;
}
