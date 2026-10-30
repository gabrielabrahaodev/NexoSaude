import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/clinic_capabilities.dart';
import '../psychology/psychology_schedule_form_screen.dart';
import 'agenda_form_screen.dart';

/// Mantém a escolha de formulário e o profissional na mesma ação de agenda.
class AgendaCellFactory {
  static Widget formForSlot({
    required ClinicCapabilities capabilities,
    required DateTime date,
    required String time,
    required String? selectedDentistId,
    required String Function(int weekday) fullWeekdayName,
  }) {
    if (capabilities.isPsychology) {
      return PsychologyScheduleFormScreen(
        preSelectedDate: DateTime(date.year, date.month, date.day),
        preSelectedDayOfWeek: fullWeekdayName(date.weekday),
        preSelectedTime: time,
        preSelectedProfessionalId: selectedDentistId,
      );
    }
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return AgendaFormScreen(
      initialData: {
        'date': Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, hour, minute),
        ),
        'dentistId': selectedDentistId,
      },
    );
  }

  static void openForm({
    required BuildContext context,
    required DateTime date,
    required String time,
    required String? selectedDentistId,
    required String Function(int weekday) fullWeekdayName,
  }) {
    final capabilities = ClinicCapabilities.current();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => formForSlot(
          capabilities: capabilities,
          date: date,
          time: time,
          selectedDentistId: selectedDentistId,
          fullWeekdayName: fullWeekdayName,
        ),
      ),
    );
  }
}
