---
title: Reports
tags:
  - nexosaude
  - brain
  - screens
name: screen-reports
description: Relatórios gerenciais com KPIs, antecipações e lançamentos manuais.
---

# ReportsScreen

`lib/screens/reports/reports_screen.dart`

## O que é

KPIs (`_KpiCard`), seletor de mês, antecipação de parcelas (`_AnticipationCard`,
`_AnticipationParcel`) e cards expansíveis de despesa; grava `financial`/`expenses`
e lê `clinics/{id}/settings/fees`.

## Quando usar

Fechamento mensal, antecipar recebível, despesa manual.

## Gotchas

- `_endOfMonth` morto; casts e `multiple_underscores` pendentes de limpeza.
- Catch vazio em um bloco — tratar ou logar ao tocar.

## Ver também

- [[reports-oracle]] — DRE/Livro com dedupe
- [[screens/financial/financial-report|financial-report]] — extrato com taxas e PDF
- [[screens/reports/kpi-dashboard|kpi-dashboard]] — KPIs do dia
- [[screens/financial/expenses|expenses]] — despesas manuais
