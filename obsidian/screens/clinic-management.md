---
title: Clinic Management
tags:
  - nexosaude
  - brain
  - screens
name: screen-clinic-management
description: CRUD de clínicas (owner) com vínculo de ownerId e nome.
---

# ClinicManagementScreen

`lib/screens/clinics/clinic_management_screen.dart`

## O que é

Lista `clinics` do owner (`where ownerId`) — ou as liberadas (`documentId whereIn allowedClinics`, máx 10) para não-owner com o item. Cria clínica (`name/type/ownerId`) só owner e atualiza `users` no vínculo.

## Quando usar

Nova clínica, renomear, trocar tipo dental/psicologia.

## Fluxos

- Criar: `clinics.add` + update do usuário.
- `DropdownButtonFormField value` depreciado → `initialValue` ao tocar.
- **Gerenciar troca de verdade**: `setClinic` + rebuild do dashboard na unidade (antes era só toast).

## Gotchas

- Trocar `type` da clínica muda menu, tabs e filtro de profissionais imediatamente (via `SessionManager`).
- Item liberável via `menuAccess` (default: só owner); não-owner vê só as liberadas e não cria unidade.

## Ver também

- [[main-dashboard]] — seletor que troca sem sair da tela
- [[session-multitenant]] — `setClinic` + isolamento
- [[employee-manager]] — quem pode entrar em cada unidade
