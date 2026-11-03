import 'patient_model.dart';
import '../utils/display.dart';

/// Registration-only fields. Consent and clinical/financial data are never in this patch.
class PatientRegistrationDraft {
  PatientRegistrationDraft.fromMap(Map<String, dynamic> data)
    : original = Map.of(data) {
    final patient = PatientModel.fromMap('registration', {
      ...data,
      if (data['birthDate'] == null && data['birth'] != null)
        'birthDate': data['birth'],
    });
    final address = _map(data['addressDetails']);
    final oldAddress = _map(data['address']);
    final emergency = _map(data['emergencyContact']);
    final preferences = _map(data['contactPreferences']);
    values = {
      'name': '${data['name'] ?? ''}',
      'phone': patient.phone ?? '',
      'cpf': patient.cpf ?? '',
      'rg': patient.rg ?? '',
      'birthDate': patient.birthDate ?? '',
      for (final key in [
        'socialName',
        'profession',
        'email',
        'biologicalSex',
        'maritalStatus',
        'rgIssuer',
        'cns',
      ])
        key: '${data[key] ?? ''}',
      for (final key in [
        'cep',
        'street',
        'number',
        'complement',
        'neighborhood',
        'city',
        'state',
      ])
        key: '${address[key] ?? oldAddress[key] ?? ''}',
      'emergencyName': '${emergency['name'] ?? ''}',
      'emergencyRelationship': '${emergency['relationship'] ?? ''}',
      'emergencyPhone': '${emergency['phone'] ?? ''}',
      'referralSource': '${preferences['referralSource'] ?? ''}',
    };
    if (values['street']!.isEmpty) values['street'] = patient.address ?? '';
    final channels = preferences['reminderChannels'];
    reminderChannels = channels is List
        ? channels.map((e) => '$e').toSet()
        : <String>{};
    values['cityState'] = [
      values['city'],
      values['state'],
    ].where((v) => v?.isNotEmpty == true).join(' - ');
    seedAddress = {for (final k in addressKeys) k: values[k] ?? ''};
  }
  final Map<String, dynamic> original;
  late Map<String, String> values, seedAddress;
  late Set<String> reminderChannels;
  static const addressKeys = [
    'cep',
    'street',
    'number',
    'complement',
    'neighborhood',
    'city',
    'state',
  ];
  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  Map<String, dynamic> toPatch() {
    final cityState = values['cityState'] ?? '';
    final seedCityState = [
      seedAddress['city'],
      seedAddress['state'],
    ].where((v) => v?.isNotEmpty == true).join(' - ');
    if (cityState != seedCityState) {
      final match = RegExp(
        r'^(.*?)\s*[-/]\s*([A-Za-z]{2})$',
      ).firstMatch(cityState);
      values['city'] = match?.group(1)?.trim() ?? cityState;
      values['state'] = match?.group(2)?.toUpperCase() ?? '';
    }
    final addressChanged = addressKeys.any((k) => values[k] != seedAddress[k]);
    final fullAddress = [
      values['street'],
      values['number'],
      values['complement'],
      values['neighborhood'],
      [
        values['city'],
        values['state'],
      ].where((v) => v?.isNotEmpty == true).join(' - '),
      values['cep'],
    ].where((v) => v?.isNotEmpty == true).join(', ');
    final originalAddress = original['address'];
    return {
      for (final key in [
        'name',
        'phone',
        'cpf',
        'rg',
        'birthDate',
        'socialName',
        'profession',
        'email',
        'biologicalSex',
        'maritalStatus',
        'rgIssuer',
        'cns',
      ])
        key: (values[key] ?? '').trim(),
      'birthMonth': birthMonthOf(values['birthDate']),
      'searchKey': (values['name'] ?? '').trim().toLowerCase(),
      'address': !addressChanged && originalAddress != null
          ? originalAddress
          : (originalAddress is Map
                ? {..._map(originalAddress), 'full_address': fullAddress}
                : fullAddress),
      'addressDetails': {
        ..._map(original['addressDetails']),
        for (final key in addressKeys) key: values[key] ?? '',
      },
      'emergencyContact': {
        ..._map(original['emergencyContact']),
        'name': values['emergencyName'] ?? '',
        'relationship': values['emergencyRelationship'] ?? '',
        'phone': values['emergencyPhone'] ?? '',
      },
      'contactPreferences': {
        ..._map(original['contactPreferences']),
        'reminderChannels': reminderChannels.toList(),
        'referralSource': values['referralSource'] ?? '',
      },
    };
  }

  static bool validCpf(String text) {
    final d = text.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11 || RegExp(r'^(\d)\1+$').hasMatch(d)) return false;
    final digits = d.split('').map(int.parse).toList();
    for (var size = 9; size <= 10; size++) {
      var sum = 0;
      for (var i = 0; i < size; i++) {
        sum += digits[i] * (size + 1 - i);
      }
      final digit = (sum * 10) % 11;
      if ((digit == 10 ? 0 : digit) != digits[size]) return false;
    }
    return true;
  }
}
