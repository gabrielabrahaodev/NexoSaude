---
name: screen-employee-manager
description: Gestão de funcionários — cria Auth + doc users com role e allowedClinics.
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

## Gotchas

- `value` de dropdown depreciado; papel `dentista` vs `psicologo` filtrado por `ClinicCapabilities` no uso (não aqui).
