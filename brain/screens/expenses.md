---
title: Expenses
tags:
  - nexosaude
  - brain
  - screens
name: screen-expenses
description: Despesas da clínica, incluindo recorrentes e baixa como paga.
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
