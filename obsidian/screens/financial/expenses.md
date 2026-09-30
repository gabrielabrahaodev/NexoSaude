---
title: Expenses
tags:
  - nexosaude
  - brain
  - screens
name: screen-expenses
description: Despesas da clínica, incluindo recorrentes e baixa como paga.
type: screen
status: stable
updated: 2026-09-30
---

# ExpensesScreen

`lib/screens/financial/expenses_screen.dart`

## O que é

CRUD de `expenses` do mês (`ExpenseService.getByMonth`) + recorrência.

## Quando usar

Lançar despesa, repetir mensal, marcar paga.

## Gotchas

- Import não usado (`supplier_model`) e campo `_supplierService` morto — remover ao tocar.
- `if` sem chaves (`curly_braces`) nesses arquivos — padronizar ao editar.

## Ver também

- [[financial]] — receitas vs despesas no caixa
- [[screens/financial/financial-report|financial-report]] — extrato com taxas e PDF
- [[screens/reports/reports|reports]] — fechamento e antecipações
