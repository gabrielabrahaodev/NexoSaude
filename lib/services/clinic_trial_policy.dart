import 'package:cloud_firestore/cloud_firestore.dart';

/// IDs explicitamente aceitos sem trial apenas por serem dados de teste
/// conhecidos. Qualquer outro documento precisa ter trialEndsAt válido.
const Set<String> legacyTriallessTestClinicIds = {
  'MxftREXD5vjKtE7SyJIH',
  'VlFVjTlNX8yqijeHyczt',
};

bool isLegacyTriallessTestClinic(String clinicId) =>
    legacyTriallessTestClinicIds.contains(clinicId);

/// true quando a expiração está ausente fora da allowlist, inválida ou vencida.
bool clinicTrialExpiredOrInvalid(
  String clinicId,
  Object? expiry, {
  DateTime? now,
}) {
  if (expiry == null) return !isLegacyTriallessTestClinic(clinicId);
  if (expiry is! Timestamp) return true;
  return !expiry.toDate().isAfter(now ?? DateTime.now());
}
