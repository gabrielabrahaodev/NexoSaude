// lib/utils/app_constants.dart

import 'package:flutter/material.dart'; // Apenas para AppColors, se necessário para enums que usam cor

// --- Firestore Collections ---
class FirestoreCollections {
  static const String patients = 'patients';
  static const String appointments = 'appointments';
  static const String budgets = 'budgets';
  static const String treatments = 'treatments';
  static const String financial = 'financial';
  static const String users = 'users';
  static const String transactions = 'transactions';
  static const String clinicalRecords = 'clinical_records'; // Adicionado, visto em clinical_record_screen.dart
}

// --- User Roles ---
enum UserRole {
  dentist('dentist'),
  receptionist('receptionist');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String roleString) {
    return UserRole.values.firstWhere(
      (role) => role.value == roleString,
      orElse: () => UserRole.receptionist, // Default ou tratamento de erro
    );
  }
}

// --- Appointment Status ---
enum AppointmentStatus {
  pendingConfirmation('Confirmado', Colors.blue),
  confirmed('Finalizar', Colors.green),
  canceled('Cancelado', Colors.red);

  final String displayValue;
  final Color color;
  const AppointmentStatus(this.displayValue, this.color);

  static AppointmentStatus fromString(String statusString) {
    return AppointmentStatus.values.firstWhere(
      (status) => status.displayValue == statusString,
      orElse: () => AppointmentStatus.pendingConfirmation, // Default
    );
  }
}

// --- Financial Status ---
enum FinancialStatus {
  pendingPayment('Aguardando Pagamento', Colors.orange),
  paid('Pago', Colors.green),
  canceled('Cancelado', Colors.red); // Usado em '_ProcedureRowItem'

  final String displayValue;
  final Color color;
  const FinancialStatus(this.displayValue, this.color);

  static FinancialStatus fromString(String statusString) {
    return FinancialStatus.values.firstWhere(
      (status) => status.displayValue == statusString,
      orElse: () => FinancialStatus.pendingPayment, // Default
    );
  }
}

// --- Treatment Status ---
enum TreatmentStatus {
  inProgress('Em Andamento', Colors.blue),
  finished('Finalizado', Colors.grey);

  final String displayValue;
  final Color color;
  const TreatmentStatus(this.displayValue, this.color);

  static TreatmentStatus fromString(String statusString) {
    return TreatmentStatus.values.firstWhere(
      (status) => status.displayValue == statusString,
      orElse: () => TreatmentStatus.inProgress, // Default
    );
  }
}

// --- Budget Status ---
enum BudgetStatus {
  pending('Pendente', Colors.orange),
  approved('Aprovado', Colors.green);

  final String displayValue;
  final Color color;
  const BudgetStatus(this.displayValue, this.color);

  static BudgetStatus fromString(String statusString) {
    return BudgetStatus.values.firstWhere(
      (status) => status.displayValue == statusString,
      orElse: () => BudgetStatus.pending, // Default
    );
  }
}