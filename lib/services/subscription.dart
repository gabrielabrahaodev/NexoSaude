/// Lógica pura da assinatura da plataforma (testada em
/// `test/subscription_test.dart`). Cobrança por usuário do owner:
/// R$ 40 o primeiro + R$ 15 por adicional (configurável via
/// `platform_config/geral`). Trial de 7 dias + bloqueio manual.

/// Mensalidade: 0 sem usuários; base + extra×(n−1).
double subscriptionAmount(int users, {double base = 40, double extra = 15}) {
  if (users <= 0) return 0.0;
  return base + extra * (users - 1);
}

/// Trial vencido? Sem data = sem trial configurado (não bloqueia).
bool trialExpired(DateTime? trialEndsAt, DateTime now) {
  if (trialEndsAt == null) return false;
  return !trialEndsAt.isAfter(now);
}

/// Bloqueio efetivo: trial expirado OU bloqueio manual do Master.
bool blockEffective({required bool trialOver, required bool manual}) {
  return trialOver || manual;
}
