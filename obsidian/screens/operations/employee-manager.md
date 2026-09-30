---
title: Employee Manager
tags:
  - nexosaude
  - brain
  - screens
name: screen-employee-manager
description: Gestão de funcionários — cria Auth + doc users com role e allowedClinics.
type: screen
status: stable
updated: 2026-09-30
---

# EmployeeManagerScreen

`lib/screens/employees/employee_manager_screen.dart`

## O que é

Lista `users` da(s) clínica(s), cria funcionário (Auth + Firestore) e edita acesso.

## Quando usar

Contratar, trocar papel, dar/remover acesso a clínica.

## Fluxos

- Criar: `createUserWithEmailAndPassword` + `users.set({role, allowedClinics})`.
- Filtro por clínica via dropdown (`clinics` do owner).
- Tile → sheet: gerar nova senha (cria `password_reset_requests` pendente; `.bat` efetiva com temporária `Nx-xxxxxx`, aparece em Pedidos; dispensar apaga o doc) + **Clínicas liberadas** (checkboxes das unidades, salva `allowedClinics`; desmarcar tudo pede confirmação).
- Seção Pedidos segue o item (sem `if owner`); dono não abre sheet.

## Gotchas

- `value` de dropdown depreciado; papel `dentista` vs `psicologo` filtrado por `ClinicCapabilities` no uso (não aqui).

## Ver também

- [[screens/operations/clinic-management|clinic-management]] — unidades que o vínculo referencia
- [[screens/operations/operations-tabs|operations-tabs]] — editor de `menuAccess` (quem vê o quê)
- [[session-multitenant]] — `allowedClinics` e isolamento
- [[screens/auth/auth-login-rolecheck|auth-login-rolecheck]] — primeiro acesso do funcionário criado
