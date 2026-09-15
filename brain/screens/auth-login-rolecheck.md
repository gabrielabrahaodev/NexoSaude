---
name: screen-auth
description: Login/cadastro e resolução de papel e clínica pós-login.
---

# LoginScreen + RoleCheckScreen

`lib/screens/auth/login_screen.dart`, `role_check_screen.dart`

## O que é

Email/senha (Firebase Auth); registro cria `users` com role + `allowedClinics` padrão;
`RoleCheckScreen` (loading) resolve clínica via `SessionManager().resolveClinic`.

## Quando usar

Auth, primeiro acesso, troca de papel, onboarding de funcionário.

## Fluxos

- Registro: `dentist` ou `receptionist`; owner vinculado depois.
- `_initializeSession`: primeira `allowedClinics` → nome/tipo da clínica → `setUser`.
- Sem role ou sem doc → logout com SnackBar.

## Gotchas

- `Radio groupValue/onChanged` depreciados aqui também.
- `RoleCheckScreen` roda a cada start: manter só 2 gets (`users` + `clinics`).
