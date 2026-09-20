---
title: Budget Wizard
tags:
  - nexosaude
  - brain
  - screens
name: screen-budget-wizard
description: Assistente de aprovação de orçamento que gera plano + financeiro.
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
