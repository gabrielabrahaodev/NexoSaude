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
- Tabs: `treatments_tab` (agrupa por `planId`), `budgets_tab`, `clinical_record_screen`, `odontogram_screen` (`patients/{id}/clinical_data/odontogram`), `anamnesis_tab` (`anamnesis/{patientId}` — token dedicado; sem leitura pública), `patient_docs_tab`, `patient_lab_tab`

## Fluxos

- Orçamento → wizard aprova (`BudgetApprovalWizard`, lê catálogo `procedures`) → `approveBudgetWithFinancials` cria plano + contas a receber.
- Finalizar atendimento vincula ao plano/procedimento ou vira avulso.

## Regras / Gotchas

- `anamnesis` não tem leitura pública; o link WhatsApp envia `id` + token dedicado `t`, e as Rules limitam escrita a campos permitidos.
- Odontograma salva `teeth` + `lastUpdate` em `clinical_data/odontogram`.
- Abas Orçamento/Odontograma/Lab escondidas na psico via `ClinicCapabilities`.

## Ver também

- [[patient-details]] — ficha que hospeda as abas clínicas
- [[patient-tabs]] — as 9 abas (orçamento, odonto, lab, docs)
- [[budget-wizard]] — aprovação que gera plano + financeiro
- [[clinic-lab]] — pedidos de laboratório


## Laboratório independente — PR #2

Pedidos são criados somente nos kanbans geral e individual, nunca no recebimento. Se houver custo, `LabService.createOrder` cria uma despesa pendente em uma transação com o pedido, para Relatórios → A Pagar; sem custo, não cria despesa. Estorno/cancelamento de recebimentos preserva pedidos e custos de laboratório. Ver [[clinic-lab]] para vínculos, idempotência, campos novos e tratamento dos dados legados.

## Registros clínicos na variante de 03/11/2026

- `lib/screens/patients/clinical_records_view.dart` separa **Todos, Evoluções, Cancelamentos e Procedimentos**, apresenta contagens reais, ordenação e cards. Cancelamento é identificado pelo título do registro ou `attendanceStatus` explicitamente gravado; cobranças são registros administrativos, não evoluções. Procedimento exige `treatmentId` verdadeiro, sem inferência por texto.
- `lib/screens/patients/tabs/clinical_record_screen.dart` mantém o fluxo de novo/editar/excluir. Evolução geral não exige tratamento ativo; descrição é obrigatória. Edição preserva autor e data históricos e grava `editedBy`/`editedAt`, com checagem de contexto de unidade/paciente antes de salvar. Exclusão requer confirmação.
- **Ressalva de integridade:** a agenda cria o registro de cancelamento depois de alterar o agendamento, em gravações independentes; `AppointmentService.cancel` não cria evolução. Falha entre os passos pode gerar divergência entre a agenda e o prontuário. Não há garantia de assinatura clínica ou trilha imutável apenas porque um card aparece.
- **Ressalva visual:** o rótulo de seção `CONDUTA & DIAGNÓSTICO` é exibido em cards clínicos, mas o sistema não deve inferir diagnóstico do texto livre.

Revisar autorização, histórico de edições/exclusões, LGPD e cenários de falha antes de publicar. Consulte [[auditoria-codigo-2026-11-03]], [[agenda]], [[patient-tabs]] e `docs/design/patients/PRONTUARIO.md`.
