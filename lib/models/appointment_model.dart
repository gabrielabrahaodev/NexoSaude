import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final String patientName;
  final DateTime date;
  final String status; // 'Agendado', 'Confirmado', 'Finalizado', 'Cancelado', 'Faltou'
  final String procedure;
  final String? notes;
  
  // NOVOS CAMPOS ESSENCIAIS
  final String clinicId;
  final String? dentistId;
  final int durationMinutes;

  // Vínculo com pacote de psicologia + presença
  final String? scheduleId;
  final String? planId;
  final String? monthlyPeriod; // "YYYY-MM"
  final String? attendanceStatus; // 'Attended' | 'Missed' | null
  final bool hasMedicalCertificate;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.status,
    required this.procedure,
    required this.clinicId,
    this.dentistId,
    this.durationMinutes = 30, // Valor padrão para evitar nulos
    this.notes,
    this.scheduleId,
    this.planId,
    this.monthlyPeriod,
    this.attendanceStatus,
    this.hasMedicalCertificate = false,
  });

  bool get isPast => DateTime.now().isAfter(date);
  bool get isCancelled => status.toLowerCase() == 'cancelado';
  bool get isDone => status.toLowerCase() == 'finalizado';
  bool get isMissed => attendanceStatus == 'Missed';
  bool get isMissedWithCertificate =>
      isMissed && hasMedicalCertificate;

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  factory AppointmentModel.fromMap(String id, Map<String, dynamic> map) {
    return AppointmentModel(
      id: id,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Desconhecido',
      date: (map['date'] as Timestamp).toDate(),
      status: map['status'] ?? 'Agendado',
      procedure: map['procedure'] ?? 'Consulta',
      clinicId: map['clinicId'] ?? '',
      dentistId: map['dentistId'] ?? map['userId'], // Mantém compatibilidade com legado
      durationMinutes: map['durationMinutes'] ?? 30,
      notes: map['notes'],
      scheduleId: map['scheduleId']?.toString(),
      planId: map['planId']?.toString(),
      monthlyPeriod: map['monthlyPeriod']?.toString(),
      attendanceStatus: map['attendanceStatus']?.toString(),
      hasMedicalCertificate: _toBool(map['hasMedicalCertificate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'date': Timestamp.fromDate(date),
      'status': status,
      'procedure': procedure,
      'clinicId': clinicId,
      'dentistId': dentistId,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'scheduleId': scheduleId,
      'planId': planId,
      'monthlyPeriod': monthlyPeriod,
      'attendanceStatus': attendanceStatus,
      'hasMedicalCertificate': hasMedicalCertificate,
    };
  }
}