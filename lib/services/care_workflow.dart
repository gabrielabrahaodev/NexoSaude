import '../models/appointment_model.dart';
import 'clinic_capabilities.dart';

bool isCareProfessional(String? role) => const {
  'dentista',
  'psicologo',
}.contains(ClinicCapabilities.normalizeRole(role ?? ''));
bool careInProgress(String status) =>
    status.toLowerCase().trim() == 'em atendimento';
bool carePaused(String status) => status.toLowerCase().trim() == 'pausado';

List<int> careReturnOffsets(bool psychology) =>
    psychology ? const [7, 14] : const [30, 21];

String careEvolutionText(Iterable<String> markers, String details) => [
  ...markers.where((m) => m.trim().isNotEmpty),
  if (details.trim().isNotEmpty) details.trim(),
].join('\n').trim();

bool careIntervalIsFree(
  DateTime date,
  int durationMinutes,
  Iterable<String> busy,
) {
  if (durationMinutes <= 0) return false;
  for (var offset = 0; offset < durationMinutes; offset += 30) {
    final slot = date.add(Duration(minutes: offset));
    final label =
        '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
    if (busy.contains(label)) return false;
  }
  return true;
}

void validateCareScope(
  AppointmentModel expected,
  Map<String, dynamic>? current,
  String? clinicId,
) {
  if (current == null ||
      clinicId == null ||
      expected.clinicId != clinicId ||
      current['clinicId'] != clinicId ||
      current['patientId'] != expected.patientId) {
    throw StateError(
      'Atendimento não pertence à clínica/paciente selecionado.',
    );
  }
  if ('${current['status']}'.toLowerCase() == 'cancelado') {
    throw StateError('Este agendamento foi cancelado.');
  }
}

class CarePackageProgress {
  final int planned;
  final int finalized;
  final int attended;
  final int remaining;
  final AppointmentModel? next;
  const CarePackageProgress({
    required this.planned,
    required this.finalized,
    required this.attended,
    required this.remaining,
    this.next,
  });
  double get fraction => planned == 0 ? 0 : finalized / planned;
  factory CarePackageProgress.fromSessions(
    List<AppointmentModel> sessions,
    DateTime after,
  ) {
    final valid =
        sessions
            .where((a) => !a.isCancelled && a.status != 'Bloqueado')
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final finished = valid.where((a) => a.isDone).length;
    final future = valid.where((a) => !a.isDone && a.date.isAfter(after));
    return CarePackageProgress(
      planned: valid.length,
      finalized: finished,
      attended: valid.where((a) => a.isDone && !a.isMissed).length,
      remaining: valid.length - finished,
      next: future.isEmpty ? null : future.first,
    );
  }
}

bool careIntervalFitsGrade(
  DateTime date,
  int durationMinutes,
  Iterable<String> grade,
) {
  if (durationMinutes <= 0) return false;
  for (var offset = 0; offset < durationMinutes; offset += 30) {
    final slot = date.add(Duration(minutes: offset));
    if (slot.year != date.year ||
        slot.month != date.month ||
        slot.day != date.day) {
      return false;
    }
    final label =
        '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
    if (!grade.contains(label)) return false;
  }
  return true;
}

/// O shell aguarda os rascunhos antes de mudar a unidade, sair ou navegar.
/// Callbacks são removidos ao desmontar a ficha; não guardam textos clínicos.
class CareDraftRegistry {
  static final Map<Object, Future<bool> Function()> _pending = {};
  static void register(Object owner, Future<bool> Function() flush) =>
      _pending[owner] = flush;
  static void unregister(Object owner) => _pending.remove(owner);
  static Future<bool> flush() async {
    for (final flush in _pending.values.toList()) {
      try {
        if (!await flush()) return false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }
}
