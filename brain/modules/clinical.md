---
title: Clinical
tags:
  - nexosaude
  - brain
  - modules
name: clinical-module
description: Prontuário, tratamentos, orçamentos, odontograma e laboratório do paciente.
---

# Clínico

## O que é

Evolução clínica (`clinical_records`), planos/tratamentos, orçamentos e pedidos de laboratório.

## Quando usar

Finalizar atendimento, aprovar orçamento, odontograma, anamnese, docs, lab.

## Arquivos-chave

- `lib/services/clinical_record_service.dart` — CRUD de `clinical_records`
- `lib/services/treatment_service.dart` — `getPlansStream`, `approveBudgetWithFinancials`, `createFromBudget`, `closePlan`
- `lib/services/budget_service.dart`, `lib/services/lab_service.dart` (`createOrder`, `updateStatus`, `addInteraction`)
- Tabs: `treatments_tab` (agrupa por `planId`), `budgets_tab`, `clinical_record_screen`, `odontogram_screen` (`patients/{id}/clinical_data/odontogram`), `anamnesis_tab` (`anamnesis/{patientId}` — escrita pública), `patient_docs_tab`, `patient_lab_tab`

## Fluxos

- Orçamento → wizard aprova (`BudgetApprovalWizard`, lê catálogo `procedures`) → `approveBudgetWithFinancials` cria plano + contas a receber.
- Finalizar atendimento vincula ao plano/procedimento ou vira avulso.

## Regras / Gotchas

- `anamnesis` tem escrita pública (link WhatsApp) — não mover para collection restrita sem ajustar rules.
- Odontograma salva `teeth` + `lastUpdate` em `clinical_data/odontogram`.
- Abas Orçamento/Odontograma/Lab escondidas na psico via `ClinicCapabilities`.
