---
title: Session Multitenant
tags:
  - nexosaude
  - brain
  - modules
name: session-multitenant
description: Sessão global, isolamento multi-tenant por clinicId, fluxo de auth e decisões por tipo de clínica.
type: module
status: stable
updated: 2026-09-30
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
- `lib/services/menu_access.dart` — `canShow` role-aware + `defaultFor` + sub-chaves `g_*` (abas/seções da Gestão); mapa `menuAccess` por usuário
- `lib/services/user_service.dart` — `getDentistsForClinic`, `getDentistsStream` (filtra dentista vs psicólogo)
- `lib/screens/auth/login_screen.dart` → `role_check_screen.dart` → `MainWebDashboard`

## Fluxos

- Login → `_initializeSession` (resolve primeira clínica via `resolveClinic`) → `RoleCheckScreen` valida role → dashboard.
- `setUser` grava `name/email` (chip do usuário no menu + assinatura da evolução).
- Troca de clínica: `setClinic` + `ValueKey(_currentClinicId)` nas telas força rebuild.
- Owner vê todas (`allowedClinics` + `ownerId`); staff restrito a `allowedClinics`.

## Regras / Gotchas

- Sem `clinicId`, `applyFilter` retorna query impossível (`waiting_session_init`) — tela vazia, não erro.
- `clinicType` padrão: `dental`. Nunca compare string solta — use `ClinicCapabilities`.
- `RoleCheckScreen` roda a cada start — manter rápido.

## Ver também

- [[screens/auth/auth-login-rolecheck|auth-login-rolecheck]] — login + resolução pós-login
- [[screens/reports/main-dashboard|main-dashboard]] — shell que consome sessão, clínica e acesso
- [[screens/operations/clinic-management|clinic-management]] — cria unidades + troca de contexto
- [[screens/operations/employee-manager|employee-manager]] — vínculo `allowedClinics` por usuário
