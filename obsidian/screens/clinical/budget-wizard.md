---
title: Budget Wizard
tags:
  - nexosaude
  - brain
  - screens
name: screen-budget-wizard
description: Assistente de aprovação de orçamento que gera plano + financeiro.
type: screen
status: stable
updated: 2026-09-30
---

# BudgetApprovalWizard

`lib/screens/patients/wizards/budget_approval_wizard.dart`

## O que é

Lê itens do orçamento × catálogo `procedures`, confirma valores e chama
`TreatmentService.approveBudgetWithFinancials`.

## Quando usar

Aprovar orçamento, gerar plano e contas.

## Gotchas

- Import `session_manager` e campo `_userService` não usados — remover ao tocar.

## Ver também

- [[screens/clinical/patient-details|patient-details]] — ficha de onde o wizard parte
- [[clinical]] — planos, tratamentos e orçamentos
- [[financial]] — contas geradas na aprovação
