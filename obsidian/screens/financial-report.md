---
title: Financial Report
tags:
  - nexosaude
  - brain
  - screens
name: screen-financial-report
description: Posição financeira — transações, taxas e PDF (TableHelper).
---

# FinancialReportScreen

`lib/screens/financial/financial_report_screen.dart`

## O que é

Extrato (`financial` + paciente via `patients`), cálculo de taxas do perfil da máquina e exportação.

## Quando usar

Fechamento, conferência de líquido, PDF.

## Gotchas

- `Table.fromTextArray` depreciado → `TableHelper.fromTextArray()`.
- Variável `anchor` não usada — remover ao tocar.

## Ver também

- [[financial]] — lançamentos e status
- [[reports-oracle]] — DRE/Livro com dedupe
- [[expenses]] — despesas no extrato
- [[reports]] — antecipações e fechamento

## Integração com Relatórios remodelado

`FinancialReportScreen(initialMonth: ...)` recebe o mês selecionado na aba Fluxo de Caixa Real; continua usando o mesmo OracleReportService e a exportação PDF existente. Relatórios gerenciais e Livro Caixa compartilham o cálculo mensal e a exclusão de cancelados/substituídos; não misturar bruto e líquido registrado ao comparar os valores.
