import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/models/psychology_schedule_model.dart';
import 'package:odonto_controle/services/agenda_professionals.dart';

void main() {
  Map<String, dynamic> member(
    String id,
    String role, {
    String status = 'Ativo',
  }) => {'uid': id, 'name': id, 'role': role, 'status': status};
  final members = [
    member('owner', 'owner'),
    member('dentist', 'Dentist'),
    member('psico', 'Psicólogo'),
    member('psico-en', 'psychologist'),
    member('reception', 'recepcionista'),
    member('inactive', 'dentista', status: 'Inativo'),
    member('pending', 'owner', status: 'pending_approval'),
    member('root', 'superadmin'),
  ];
  test(
    'diretório inclui donos, dentistas e psicólogos ativos, com aliases',
    () {
      final users = agendaProfessionalsFromMembers(members);
      expect(users.map((u) => u.id).toSet(), {
        'owner',
        'dentist',
        'psico',
        'psico-en',
      });
      expect(users.firstWhere((u) => u.id == 'psico').role, 'psicologo');
    },
  );
  test('recepção pode selecionar todos; profissionais só a própria agenda', () {
    final users = agendaProfessionalsFromMembers(members);
    expect(
      selectableAgendaProfessionals(
        users,
        role: 'receptionist',
        userId: 'r',
      ).length,
      4,
    );
    expect(
      selectableAgendaProfessionals(
        users,
        role: 'owner',
        userId: 'owner',
      ).length,
      4,
    );
    expect(
      selectableAgendaProfessionals(
        users,
        role: 'psychologist',
        userId: 'psico',
      ).single.id,
      'psico',
    );
    expect(
      selectableAgendaProfessionals(
        users,
        role: 'dentist',
        userId: 'dentist',
      ).single.id,
      'dentist',
    );
  });
  test(
    'trocar clínica ou remover vínculo não mantém seleção da outra unidade',
    () {
      final a = agendaProfessionalsFromMembers([member('a', 'owner')]);
      final b = agendaProfessionalsFromMembers([member('b', 'dentista')]);
      expect(selectedAgendaProfessional('a', a), 'a');
      expect(selectedAgendaProfessional('a', b), 'b');
      expect(selectedAgendaProfessional('b', []), isNull);
    },
  );
  test(
    'deduplica UID e não retorna diretório vazio como todos os profissionais',
    () {
      final users = agendaProfessionalsFromMembers([
        member('a', 'owner'),
        member('a', 'owner'),
        member('', 'dentista'),
      ]);
      expect(users.length, 1);
      expect(selectedAgendaProfessional(null, []), isNull);
    },
  );
  AppointmentModel appt(String? dentistId) => AppointmentModel(
    id: '1',
    patientId: 'p',
    patientName: 'P',
    date: DateTime(2026),
    status: 'Confirmado',
    procedure: 'Consulta',
    clinicId: 'a',
    dentistId: dentistId,
  );
  test('seleção filtra consultas e restringe também psicólogo/aliases', () {
    expect(
      agendaAppointmentMatchesProfessional(
        appt('a'),
        selectedId: 'a',
        role: 'owner',
        userId: 'o',
      ),
      isTrue,
    );
    expect(
      agendaAppointmentMatchesProfessional(
        appt('b'),
        selectedId: 'a',
        role: 'owner',
        userId: 'o',
      ),
      isFalse,
    );
    expect(
      agendaAppointmentMatchesProfessional(
        appt('b'),
        selectedId: 'b',
        role: 'psychologist',
        userId: 'a',
      ),
      isFalse,
    );
    expect(
      agendaAppointmentMatchesProfessional(
        appt('a'),
        selectedId: 'a',
        role: 'psychologist',
        userId: 'a',
      ),
      isTrue,
    );
    expect(
      agendaAppointmentMatchesProfessional(
        appt('a'),
        selectedId: null,
        role: 'owner',
        userId: 'o',
      ),
      isFalse,
    );
  });
  test('consulta legada sem profissional fica só na visão da gestão', () {
    expect(
      agendaAppointmentMatchesProfessional(
        appt(null),
        selectedId: 'a',
        role: 'owner',
        userId: 'o',
      ),
      isTrue,
    );
    expect(
      agendaAppointmentMatchesProfessional(
        appt(null),
        selectedId: 'a',
        role: 'psicologo',
        userId: 'a',
      ),
      isFalse,
    );
  });
  test(
    'vínculo escolhido acompanha os formulários; profissional mantém o próprio UID',
    () {
      expect(
        agendaBookingProfessionalId(
          role: 'recepcionista',
          userId: 'r',
          selectedId: 'p',
        ),
        'p',
      );
      expect(
        agendaBookingProfessionalId(
          role: 'owner',
          userId: 'o',
          selectedId: 'p',
        ),
        'p',
      );
      expect(
        agendaBookingProfessionalId(
          role: 'psychologist',
          userId: 'p',
          selectedId: 'outro',
        ),
        'p',
      );
      expect(
        agendaBookingProfessionalId(
          role: 'dentist',
          userId: 'd',
          selectedId: 'outro',
        ),
        'd',
      );
    },
  );
  test('pacote de psicologia preserva o profissional na serialização', () {
    final model = PsychologyScheduleModel(
      id: 's',
      clinicId: 'c',
      dentistId: 'p',
      patientId: 'patient',
      patientName: 'Paciente',
      scheduleType: PsychologyScheduleType.package,
      startDate: DateTime(2026, 10, 26),
      dayOfWeek: 'Segunda',
      time: '09:00',
      packageValue: 100,
      sessionValue: 25,
      createdAt: DateTime(2026),
    );
    expect(PsychologyScheduleModel.fromMap('s', model.toMap()).dentistId, 'p');
    expect(
      model.generateSessionDates(endDate: DateTime(2026, 11, 2)).length,
      2,
    );
  });
}
