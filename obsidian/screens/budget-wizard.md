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

## Ver também

- [[patient-details]] — ficha de onde o wizard parte
- [[clinical]] — planos, tratamentos e orçamentos
- [[financial]] — contas geradas na aprovação

## Compatibilidade da proposta visual

Itens novos guardam `price` como subtotal final líquido da linha. `quantity`, `unitPrice`, `discountAmount`/`discountPercent` e região são metadados; o assistente continua usando price sem multiplicar novamente ou aplicar desconto outra vez. A aprovação preserva esses campos e referências dentárias explícitas no plano, mantendo o cálculo de contrato/recebíveis anterior. Condições/parcelas sugeridas na proposta não geram recebíveis até confirmar a aprovação pelo wizard.
