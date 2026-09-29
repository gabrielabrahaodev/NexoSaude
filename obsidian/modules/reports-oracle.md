---
title: Reports Oracle
tags:
  - nexosaude
  - brain
  - modules
name: reports-oracle-module
description: Relatórios gerenciais, saúde financeira do paciente e snapshot mensal do oráculo.
---

# Relatórios / Oráculo

## O que é

Agregações de leitura sobre `financial`/`expenses`: tela de relatórios, saúde financeira
por paciente e snapshot mensal combinado.

## Quando usar

KPI, antecipação de parcelas, mês fechado, score do paciente.

## Arquivos-chave

- `lib/services/oracle_report_service.dart` — `getMonthOverview` → `OracleReportSnapshot` (+ `StreamCombiner`, `TransactionItem`)
- `lib/services/patient_financial_oracle.dart` — `getPatientFinancialHealth`
- `lib/screens/reports/reports_screen.dart` (`_KpiCard`, `_AnticipationCard`, `_MonthSelector`, cria `financial` de antecipação e `expenses` de rateio)

## Fluxos

- Relatórios lê `financial` + `expenses` do mês; antecipação gera conta `financial` + despesa de taxa.
- Oráculo combina streams sem escrever nada (somente leitura).

## Regras / Gotchas

- `clinics/{id}/settings/fees` alimenta os cálculos — ausência de perfil = fallback, conferir.
- Queries com `whereIn` + ordenação exigem índice composto (ver `firestore.indexes.json`).

## Atualizações (cota)

- DRE/Livro Caixa: união de queries mensais por campo de data (exato, dedupe por id) em vez da collection inteira; `combineDocs` novo. Índices em `firestore.indexes.json`. Ver [[portal-mirror]] (mesmo padrão de união).

## Ver também

- [[financial-report]] — extrato que consome a união
- [[kpi-dashboard]] — KPIs do dia
