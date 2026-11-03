import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/models/appointment_model.dart';
import 'package:odonto_controle/services/care_workflow.dart';
import 'package:odonto_controle/services/package_billing.dart';
import 'package:odonto_controle/utils/patient_route.dart';

AppointmentModel visit(
  String id,
  DateTime date, {
  String status = 'Confirmado',
  String? attendance,
  bool certificate = false,
}) => AppointmentModel(
  id: id,
  patientId: 'p',
  patientName: 'Paciente',
  clinicId: 'c',
  procedure: 'Sessão',
  date: date,
  status: status,
  attendanceStatus: attendance,
  hasMedicalCertificate: certificate,
);
void main() {
  test(
    'perfis legados de psicologia e odontologia mantêm restrição própria',
    () {
      for (final role in ['Dentist', 'dentista', 'psychologist', 'Psicólogo']) {
        expect(isCareProfessional(role), isTrue);
      }
      expect(isCareProfessional('owner'), isFalse);
      expect(isCareProfessional('recepcionista'), isFalse);
    },
  );
  test('retornos são diferentes por especialidade', () {
    expect(careReturnOffsets(true), [7, 14]);
    expect(careReturnOffsets(false), [30, 21]);
    expect(carePaused('Pausado'), isTrue);
    expect(careInProgress('Em Atendimento'), isTrue);
    expect(careInProgress('Confirmado'), isFalse);
  });
  test(
    'texto formal só contém marcadores escolhidos e detalhes informados',
    () {
      expect(careEvolutionText([], ''), isEmpty);
      expect(careEvolutionText(['Marcador'], ' Texto '), 'Marcador\nTexto');
    },
  );
  test(
    'intervalo livre verifica toda a duração e respeita o fim do expediente',
    () {
      final date = DateTime(2026, 10, 30, 13, 30);
      expect(careIntervalIsFree(date, 60, ['14:00']), isFalse);
      expect(careIntervalIsFree(date, 30, ['14:00']), isTrue);
      expect(careIntervalFitsGrade(date, 60, ['13:30']), isFalse);
      expect(careIntervalFitsGrade(date, 60, ['13:30', '14:00']), isTrue);
      expect(careIntervalIsFree(date, 0, []), isFalse);
      expect(
        careIntervalFitsGrade(DateTime(2026, 10, 30, 23, 30), 60, [
          '23:30',
          '00:00',
        ]),
        isFalse,
      );
    },
  );
  test('alteração de clínica, paciente ou cancelamento impede gravação', () {
    final a = visit('1', DateTime(2026));
    final current = {'clinicId': 'c', 'patientId': 'p', 'status': 'Confirmado'};
    expect(() => validateCareScope(a, current, 'c'), returnsNormally);
    expect(() => validateCareScope(a, current, 'outra'), throwsStateError);
    expect(
      () => validateCareScope(a, {...current, 'patientId': 'outro'}, 'c'),
      throwsStateError,
    );
    expect(
      () => validateCareScope(a, {...current, 'status': 'Cancelado'}, 'c'),
      throwsStateError,
    );
    expect(() => validateCareScope(a, null, 'c'), throwsStateError);
  });
  test(
    'progresso usa sessões reais, ignora canceladas e reutiliza a próxima existente',
    () {
      final now = DateTime(2026, 10, 30);
      final next = visit('next', now.add(const Duration(days: 7)));
      final sessions = [
        visit('done', now, status: 'Finalizado', attendance: 'Attended'),
        visit(
          'missed',
          now,
          status: 'Finalizado',
          attendance: 'Missed',
          certificate: true,
        ),
        visit('cancel', now, status: 'Cancelado'),
        next,
      ];
      final progress = CarePackageProgress.fromSessions(sessions, now);
      expect(progress.planned, 3);
      expect(progress.finalized, 2);
      expect(progress.attended, 1);
      expect(progress.remaining, 1);
      expect(progress.next, same(next));
      // A interface não debita créditos fictícios nem altera a regra de rateio por presença.
      final bill = PackageBilling.compute(
        packageAmount: 300,
        discount: 0,
        sessions: sessions,
      );
      expect(bill.billable, 1);
      expect(bill.amountDue, 100);
    },
  );
  test(
    'links de prontuário e pagamentos escolhem as abas corretas para cada clínica',
    () {
      expect(patientSectionIndex(PatientSection.payments, psychology: true), 5);
      expect(
        patientSectionIndex(PatientSection.payments, psychology: false),
        8,
      );
      expect(patientSectionIndex(PatientSection.record, psychology: true), 3);
      expect(patientSectionIndex(PatientSection.record, psychology: false), 4);
      expect(
        patientSectionIndex(PatientSection.documents, psychology: true),
        4,
      );
      expect(
        patientSectionIndex(PatientSection.documents, psychology: false),
        7,
      );
    },
  );
  test('navegação aguarda rascunhos e bloqueia saída em falha', () async {
    final first = Object();
    final second = Object();
    var calls = 0;
    CareDraftRegistry.register(first, () async {
      calls++;
      return true;
    });
    CareDraftRegistry.register(second, () async {
      calls++;
      return false;
    });
    expect(await CareDraftRegistry.flush(), isFalse);
    expect(calls, 2);
    CareDraftRegistry.unregister(second);
    expect(await CareDraftRegistry.flush(), isTrue);
    CareDraftRegistry.unregister(first);
    expect(await CareDraftRegistry.flush(), isTrue);
  });
}
