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

## Ver também

- [[patient-details]] — ficha que abre daqui
- [[create-patient]] — cadastro via FAB
- [[patients]] — risco, cascata e busca
- [[kpi-dashboard]] — "Ver em Pacientes"


## Abertura no dashboard — PR #2

No layout clínico, o shell fornece `onOpenPatient` por `PatientWorkspace`: clicar no paciente troca somente o conteúdo da direita. Não cria rota nem dashboard adicional. A lista fica montada, preservando busca e estado ao voltar. Troca de clínica remonta o workspace pela chave e remove o paciente anterior. O uso isolado da lista e a flag legada mantêm a rota anterior como fallback.
