import 'package:intl/intl.dart';
import '../utils/display.dart';

/// Lógica pura do Modo Atendimento (testada em `test/care_day_test.dart`).
/// Telas em `screens/care/` consomem estes helpers; services de escrita
/// (`ClinicalRecordService`, `FinancialService`, `AppointmentService`)
/// seguem separados.

/// Intervalo do dia cheio [00:00, 00:00 do dia seguinte), pronto para
/// `getByDateRange` (inclui início, exclui fim).
({DateTime start, DateTime end}) todayBounds([DateTime? now]) {
  final ref = now ?? DateTime.now();
  final start = DateTime(ref.year, ref.month, ref.day);
  return (start: start, end: start.add(const Duration(days: 1)));
}

/// Modelos de evolução rápida por tipo de clínica (v1: fixos em código;
/// editáveis pelo owner ficam para v2).
List<String> attendanceTemplates(String? clinicType) {
  if (clinicType == 'psychology') {
    return const [
      'Sessão realizada — paciente colaborativo, sem intercorrências.',
      'Sessão realizada — trabalhadas estratégias de manejo acordadas.',
      'Sessão realizada — paciente instável; retorno antecipado sugerido.',
      'Primeira sessão — anamnese psicológica e plano terapêutico inicial.',
      'Sessão de manutenção — quadro estável, sem ajustes.',
    ];
  }
  return const [
    'Atendimento realizado sem intercorrências.',
    'Profilaxia realizada; orientação de higiene reforçada.',
    'Procedimento concluído; retorno agendado.',
    'Avaliação inicial — plano de tratamento proposto.',
    'Retorno de acompanhamento; quadro estável.',
  ];
}

/// Texto de confirmação da próxima sessão (mesmo tom do app).
String nextSessionText({required String patientName, required DateTime date}) {
  final when = formatDateShort(date);
  final hour = DateFormat('HH:mm').format(date);
  return 'Olá $patientName, por favor confirme sua próxima sessão para o dia '
      '$when às $hour. Responda esta mensagem confirmando. Obrigado!';
}
