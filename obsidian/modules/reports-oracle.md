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

## Base compartilhada de Relatórios e Livro Caixa

`calculateMonth` recebe `ReportDocument` puro para testar deduplicação, datas efetivas e totais sem conexão. `TransactionItem.details` conserva metadados reais (sem inventar recibo/prontuário/especialidade). Dedupe usa coleção+ID; IDs iguais em receitas/despesas não se anulam. Datas são defensivas; campos ausentes não viram hoje. Cancelados/substituídos excluídos.

Queries `financial`: dueDate/paymentDate/paidDate/date. `expenses`: os mesmos + createdAt legado. Limites [início, primeiro dia do próximo mês), usando os índices existentes. O filtro final também respeita microssegundos. Débito usa caixa por baixa, crédito mantém vencimento salvo antecipado por paidDate. Totais: recebidos brutos, despesas pagas; projeção desconta parciais pendentes. Não é conciliação bancária nem inclui saldo de abertura.

`getCardReceivables` consulta dois campos de data da clínica em janela de 12 meses, deduplica e valida data efetiva/tipo. `StreamCombiner.combineDocs` cancela assinaturas das queries ao sair/trocar período (coberto por teste). Histórico de antecipação só considera dados efetivamente gravados.
