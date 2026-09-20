---
title: Patient List
tags:
  - nexosaude
  - brain
  - screens
name: screen-patient-list
description: Lista de pacientes com busca, avatar e exclusão em cascata.
---

# PatientListScreen

`lib/screens/patients/patient_list_screen.dart`

## O que é

Stream `patients` por `clinicId` + busca local (nome/CPF/telefone) + ordenação por `createdAt`.

## Quando usar

Buscar paciente, abrir detalhes, excluir (tap no menu ou long-press).

## Fluxos

- Excluir → confirmação → `_confirmDelete` (`deletePatientCascade`) → SnackBar.
- `_patientService` é campo `final` (não instanciar no build).

## Gotchas

- `Hero tag avatar_$docId`; `withValues(alpha:)`; `onSelected` com bloco.
