---
title: Patients
tags:
  - nexosaude
  - brain
  - modules
name: patients-module
description: Cadastro de pacientes, perfil de risco por assiduidade e exclusão em cascata.
---

# Pacientes

## O que é

CRUD de `patients` + risco (taxa de faltas) + exclusão em cascata de todos os dados do paciente.

## Quando usar

Busca/cadastro de paciente, `Hero` de avatar, exclusão, assiduidade.

## Arquivos-chave

- `lib/services/patient_service.dart` — `getAllStream`, `getByIdStream`, `getPatientRiskProfile`, `deletePatientCascade`
- `lib/models/patient_model.dart` — parsing defensivo (`parseAddress`, `parseBirthDate`: String ou Map/Timestamp)

## Fluxos

- Risco: últimos 20 `appointments`; `Missed` conta, **`Missed` com atestado não conta**; `Cancelado` pelo paciente conta. Níveis: red (≥30% ou ≥3), yellow (≥10%), green.
- Cascata (`_cascadeCollections`): appointments, budgets, treatments, treatment_plans, financial, clinical_records, lab_orders, psychology_schedules + subcoleções (odontogram, anamnesis, **docs**) + o próprio paciente, num batch só. `docs` tem `purgePatientFiles` (destroy Cloudinary) antes do batch.

## Regras / Gotchas

- Batch Firestore limita ~500 writes — cascata de paciente gigante pode estourar; monitorar.
- `Hero tag` usa `avatar_$docId` (nunca nome — nomes repetem e quebram a animação).
- Busca filtra nome/CPF/telefone localmente após o stream por `clinicId`.
