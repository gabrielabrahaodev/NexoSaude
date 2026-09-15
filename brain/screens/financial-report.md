---
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
