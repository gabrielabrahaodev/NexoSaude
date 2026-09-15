---
name: screen-clinic-management
description: CRUD de clínicas (owner) com vínculo de ownerId e nome.
---

# ClinicManagementScreen

`lib/screens/clinics/clinic_management_screen.dart`

## O que é

Lista `clinics` do owner (`where ownerId`), cria clínica (`name/type/ownerId`) e
atualiza `users` no vínculo.

## Quando usar

Nova clínica, renomear, trocar tipo dental/psicologia.

## Fluxos

- Criar: `clinics.add` + update do usuário.
- `DropdownButtonFormField value` depreciado → `initialValue` ao tocar.

## Gotchas

- Trocar `type` da clínica muda menu, tabs e filtro de profissionais imediatamente (via `SessionManager`).
- Somente `owner` acessa (guard no dashboard).
