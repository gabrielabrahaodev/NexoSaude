import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/clinic_capabilities.dart';
import '../psychology/psychology_schedule_form_screen.dart';
import 'agenda_form_screen.dart';

/// Delegate que decide qual formulário abrir a partir de uma célula vazia
/// da grade, sem espalhar `if (clinicType)` pela agenda.
class AgendaCellFactory {
  static void openForm({
    required BuildContext context,
    required DateTime date,
    required String time,
    required String? selectedDentistId,
    required String Function(int weekday) fullWeekdayName,
  }) {
    final caps = ClinicCapabilities.current();
    if (caps.isPsychology) {
      final dayOfWeek = fullWeekdayName(date.weekday);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => PsychologyScheduleFormScreen(
            preSelectedDate: DateTime(date.year, date.month, date.day),
            preSelectedDayOfWeek: dayOfWeek,
            preSelectedTime: time,
          ),
        ),
      );
      return;
    }

    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final preFill = {
      'date': Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, hour, minute)),
      'dentistId': selectedDentistId
    };
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (c) => AgendaFormScreen(initialData: preFill)));
  }
}
