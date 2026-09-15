---
name: session-multitenant
description: Sessão global, isolamento multi-tenant por clinicId, fluxo de auth e decisões por tipo de clínica.
---

# Session / Multi-tenant

## O que é

Núcleo do isolamento multi-clínica. `SessionManager` (singleton `ChangeNotifier`)
guarda usuário + clínica atual; `ClinicCapabilities` decide comportamento por tipo.

## Quando usar

Auth, troca de clínica, filtro por clínica, regra "só psico" / "só dental", papéis.

## Arquivos-chave

- `lib/services/session_manager.dart` — `setUser`, `setClinic`, `clear`, `applyFilter(query)`, `resolveClinic(clinicId)`
- `lib/services/clinic_capabilities.dart` — `isPsychology/isDental`, `canShowBudgets/Lab/Odontogram`, `canUseMonthlyPackages`, `professionalRole`, `patientTabCount`
- `lib/services/user_service.dart` — `getDentistsForClinic`, `getDentistsStream` (filtra dentista vs psicólogo)
- `lib/screens/auth/login_screen.dart` → `role_check_screen.dart` → `MainWebDashboard`

## Fluxos

- Login → `_initializeSession` (resolve primeira clínica via `resolveClinic`) → `RoleCheckScreen` valida role → dashboard.
- Troca de clínica: `setClinic` + `ValueKey(_currentClinicId)` nas telas força rebuild.
- Owner vê todas (`allowedClinics` + `ownerId`); staff restrito a `allowedClinics`.

## Regras / Gotchas

- Sem `clinicId`, `applyFilter` retorna query impossível (`waiting_session_init`) — tela vazia, não erro.
- `clinicType` padrão: `dental`. Nunca compare string solta — use `ClinicCapabilities`.
- `RoleCheckScreen` roda a cada start — manter rápido.
