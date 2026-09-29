---
title: Patient Tabs
tags:
  - nexosaude
  - brain
  - screens
name: screen-patient-tabs
description: Abas da ficha do paciente — cadastro, anamnese, orçamentos, tratamentos, prontuário, odonto, lab, docs, financeiro.
---

# Patient Tabs

`lib/screens/patients/tabs/` (9 arquivos)

## O que é

- **patient_details_tab**: edição do cadastro (`patients/{id}`).
- **anamnesis_tab**: doc único `anamnesis/{patientId}` (+ espelho em `patients`); switches de hábitos.
- **budgets_tab**: `budgets` do paciente (`_treatmentService` morto — remover).
- **treatments_tab**: agrupa por `planId`; parâmetro `sum` sombreia tipo — renomear para `total`.
- **clinical_record_screen** (`ClinicalRecordTab`): lista `clinical_records`.
- **odontogram_screen**: `patients/{id}/clinical_data/odontogram` (`teeth` + `lastUpdate`); `scale` depreciado.
- **patient_lab_tab**: `lab_orders` do paciente; catch vazio.
- **patient_docs_tab**: `DocumentService.getDocs` por categoria; `if` sem chaves.
- **patient_financial_tab**: extrato + taxas do perfil + gera `financial`/`expenses`/`lab_orders`; filtros de valor mín/máx, procedimento (título/categoria) e ordenação (registro, vencimento ↑↓; nulos por último); totais sempre na lista cheia; tem `dead_code` e casts desnecessários — limpar ao tocar.

## Quando usar

Qualquer evolução da ficha do paciente.

## Gotchas

- Quase todas usam `value:` de dropdown depreciado → `initialValue`.

## Ver também

- [[patient-details]] — shell da ficha com as tabs
- [[clinical]] — conteúdo clínico das abas
