import '../models/appointment_model.dart';
import '../models/user_model.dart';
import 'clinic_capabilities.dart';

/// Política de apresentação da agenda. Não concede permissões no Firestore.
bool canChooseAgendaProfessional(String? role) => const {
  'owner',
  'recepcionista',
  'superadmin',
}.contains(ClinicCapabilities.normalizeRole(role ?? ''));

bool isAgendaProfessional(String? role) => const {
  'owner',
  'dentista',
  'psicologo',
}.contains(ClinicCapabilities.normalizeRole(role ?? ''));

/// Recebe SOMENTE os espelhos da clínica selecionada. Nunca une tenants.
List<UserModel> agendaProfessionalsFromMembers(
  Iterable<Map<String, dynamic>> members,
) {
  final users = <String, UserModel>{};
  for (final member in members) {
    final id = '${member['uid'] ?? ''}'.trim();
    if (id.isEmpty ||
        '${member['status'] ?? ''}'.trim().toLowerCase() != 'ativo' ||
        !isAgendaProfessional('${member['role'] ?? ''}')) {
      continue;
    }
    users[id] = UserModel(
      id: id,
      name: '${member['name'] ?? ''}'.trim(),
      email: '',
      role: ClinicCapabilities.normalizeRole('${member['role'] ?? ''}'),
    );
  }
  return users.values.toList()..sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName == 0 ? a.id.compareTo(b.id) : byName;
  });
}

List<UserModel> selectableAgendaProfessionals(
  List<UserModel> users, {
  required String? role,
  required String? userId,
}) => canChooseAgendaProfessional(role)
    ? users
    : users.where((u) => u.id == userId).toList();

String? selectedAgendaProfessional(String? previous, List<UserModel> users) {
  if (users.any((u) => u.id == previous)) return previous;
  return users.isEmpty ? null : users.first.id;
}

bool agendaAppointmentMatchesProfessional(
  AppointmentModel appointment, {
  required String? selectedId,
  required String? role,
  required String? userId,
}) {
  if (selectedId == null) return false;
  if (!canChooseAgendaProfessional(role)) {
    return selectedId == userId && appointment.dentistId == userId;
  }
  // Legado sem profissional permanece visível para a gestão, como na agenda original.
  return appointment.dentistId == selectedId ||
      (appointment.dentistId ?? '').isEmpty;
}

String agendaProfessionalRoleLabel(String role) =>
    switch (ClinicCapabilities.normalizeRole(role)) {
      'owner' => 'Dono da clínica',
      'psicologo' => 'Psicólogo',
      'dentista' => 'Dentista',
      _ => 'Profissional',
    };

/// Equipe gestora usa a seleção; profissional atende na própria agenda.
String? agendaBookingProfessionalId({
  required String? role,
  required String? userId,
  String? selectedId,
}) {
  if (canChooseAgendaProfessional(role)) return selectedId;
  return isAgendaProfessional(role) ? userId : selectedId;
}
