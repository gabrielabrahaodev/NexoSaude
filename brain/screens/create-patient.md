---
name: screen-create-patient
description: Cadastro de paciente com clinicId da sessão.
---

# CreatePatientScreen

`lib/screens/patients/create_patient_screen.dart`

## O que é

Formulário que grava em `patients` já com o `clinicId` atual.
Psico exibe dropdown de Status Terapêutico (default Prospecto); dental grava `status='Ativo'` sem campo.

## Quando usar

Novo paciente, campos obrigatórios, duplicidade de CPF.

## Gotchas

- Variável `cpfQuery` não usada — remover ou implementar checagem de duplicado.
