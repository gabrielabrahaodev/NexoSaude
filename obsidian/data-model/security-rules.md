---
title: Regras de segurança Firestore
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - data-model
  - firestore
  - seguranca
---

# Regras de segurança Firestore

Resumo do que existe no vault (`Requisitos.md` RN-58, `foundation/01-prd.md` §4 Security & Privacy).

## Resumo (fonte: RN-58)

- `isOwner()`: `users/{uid}.role == 'owner'`.
- `hasClinicAccess(clinicId)`: `clinicId in users/{uid}.allowedClinics`.
- `patients/appointments/financial/treatments/treatment_plans/budgets/clinical_records/psychology_schedules`: auth + (owner **ou** acesso à clínica).
- `expenses`/`lab_orders`: blocos próprios escopados por `clinicId`.
- `settings/*`: leitura auth, escrita owner; `settings/integrations/**`: só owner.
- Exceções públicas: `/anamnesis` (`get` público + escrita por allowlist), `/appointments` update de status para `'Confirmado'` (WhatsApp).
- Mantidos amplos de propósito: `procedures` (global), `inventory`/`suppliers` (leitores legados), `plans`, `anticipations`, `news`.
- Portal: `get` público em `portal/{token}` + `portal_slots/{clinicId}`; escritas por allowlist (`statusSessao`, `pedidoRemarcacao`, `avisoPagamento`, `propostasRecusadas`).

## TODOs

- Importado de firestore.rules (293 linhas) em 2026-09-30. Helpers: `isAuthenticated`, `isOwner` (role owner), `isSuperAdmin` (role superadmin), `isPlatformDebtor`, `hasClinicAccess` (allowedClinics), `isSecretsPath`. - Matches: users (auto-cadastro com allowlist de roles + trial owner pendente), trial_requests (create público com allowlist de 7 campos), user_prefs (próprio ou owner), password_reset_requests (create público, resto owner), clinics (staff atualiza pixKey/gradeConfig/whatsappNumber com flags g_pix/g_grade/g_clinica), platform_config + platform_debits, news, appointments (update Confirmado e remarcar por allowlist), portal get público + update por allowlist de 4 chaves, portal_slots read público, financial (avisoPagamento), anamnesis (14 campos), catch-all F para 8 coleções operacionais, procedures/inventory/suppliers amplos de propósito, expenses/lab_orders escopados, settings com segredos só owner, subcoleções de patients. - Divergências contra o resumo RN-58: allowlist do portal tem 4 chaves, sem propostasRecusadas; rules trazem isSuperAdmin, isPlatformDebtor, trial_requests e flags de clínica não citadas no RN. <!-- fonte: firestore.rules:8-291 -->

Ver [[data-model/collections]], [[decisions/0002-multitenant-session]].
