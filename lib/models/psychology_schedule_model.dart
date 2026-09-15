import 'package:cloud_firestore/cloud_firestore.dart';

enum PsychologyScheduleType { package, session }

class PsychologyScheduleModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final PsychologyScheduleType scheduleType;
  final DateTime startDate;
  final String dayOfWeek;
  final String time;
  final double packageValue;
  final double sessionValue;
  final bool fromThirdParty;
  final double thirdPartyDiscount;
  final String status;
  final DateTime createdAt;
  final String? notes;

  PsychologyScheduleModel({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.patientName,
    required this.scheduleType,
    required this.startDate,
    required this.dayOfWeek,
    required this.time,
    required this.packageValue,
    required this.sessionValue,
    this.fromThirdParty = false,
    this.thirdPartyDiscount = 0.0,
    this.status = 'active',
    required this.createdAt,
    this.notes,
  });

  factory PsychologyScheduleModel.fromMap(String id, Map<String, dynamic> map) {
    return PsychologyScheduleModel(
      id: id,
      clinicId: map['clinicId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      scheduleType: map['scheduleType'] == 'session' 
          ? PsychologyScheduleType.session 
          : PsychologyScheduleType.package,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dayOfWeek: map['dayOfWeek'] ?? '',
      time: map['time'] ?? '',
      packageValue: (map['packageValue'] ?? 0.0).toDouble(),
      sessionValue: (map['sessionValue'] ?? 0.0).toDouble(),
      fromThirdParty: map['fromThirdParty'] ?? false,
      thirdPartyDiscount: (map['thirdPartyDiscount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'active',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'patientId': patientId,
      'patientName': patientName,
      'scheduleType': scheduleType.name,
      'startDate': Timestamp.fromDate(startDate),
      'dayOfWeek': dayOfWeek,
      'time': time,
      'packageValue': packageValue,
      'sessionValue': sessionValue,
      'fromThirdParty': fromThirdParty,
      'thirdPartyDiscount': thirdPartyDiscount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }

  double get effectiveValue {
    if (scheduleType == PsychologyScheduleType.package) {
      return packageValue - thirdPartyDiscount;
    }
    return sessionValue - thirdPartyDiscount;
  }

  List<DateTime> generateSessionDates({DateTime? endDate}) {
    final end = endDate ?? DateTime(startDate.year, 12, 31, 23, 59);
    final sessions = <DateTime>[];
    final targetWeekday = _weekdayFromString(dayOfWeek);
    final startHour = int.parse(time.split(':')[0]);
    final startMinute = int.parse(time.split(':')[1]);

    DateTime current = startDate;
    // Adjust to the first occurrence of the target weekday on or after startDate
    while (current.weekday != targetWeekday) {
      current = current.add(const Duration(days: 1));
    }

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final sessionDate = DateTime(current.year, current.month, current.day, startHour, startMinute);
      sessions.add(sessionDate);
      current = current.add(const Duration(days: 7));
    }

    return sessions;
  }

  int _weekdayFromString(String day) {
    const weekdays = {
      'Segunda': 1,
      'Terça': 2,
      'Quarta': 3,
      'Quinta': 4,
      'Sexta': 5,
      'Sábado': 6,
      'Domingo': 7,
    };
    return weekdays[day] ?? 1;
  }
}