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

- TODO: importar de `firestore.rules` (fonte final no código, não no vault).

Ver [[data-model/collections]], [[decisions/0002-multitenant-session]].
