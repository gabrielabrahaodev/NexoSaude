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
- [[financial-report]] — extrato com taxas e PDF
- [[kpi-dashboard]] — KPIs do dia
- [[expenses]] — despesas manuais

## Remodelagem Clinical Precision — PR #2

- `ClinicalReportsView` é apresentação sem Firebase, adaptativa claro/escuro. Quatro abas locais: DRE Agrupado, Fluxo Real, Contas a Pagar e Recebíveis/Antecipações. Busca e categoria não alteram os totais gerais. Estado de aba/busca permanece na troca de tema/mês.
- Os indicadores e tabelas compartilham `OracleReportService.getMonthOverview` com o Livro Caixa. Consultas mensais limitadas por clínica e data; stream reutilizado até mudar mês/atualizar. Não exibir dados anteriores como mês novo durante espera/erro.
- Contas de laboratório são `expenses` pendentes e participam da projeção; baixa confirmada grava data/status/paidAmount em transação, conferindo clínica, cancelamento e valores atuais. Pagamento do paciente continua sem pedido de laboratório.
- Novo Lançamento cria receita avulsa; cobrança de paciente permanece em Pagamentos. Formulário manual valida BRL, descrição e categoria; ID estável e bloqueio enquanto salva. Gerenciar despesas/recorrências mantém a tela anterior acessível.
- Exportar DRE = CSV do período, incluindo status e bruto/líquido separado. Fluxo Real abre Livro Caixa/PDF com initialMonth. Não há conciliação bancária nem fechamento formal: usar apenas dados registrados.
- Recebíveis futuros usam janela de 12 meses; antecipação mantém simulação/confirmação existentes. Débito, substituído, cancelado e antecipado não elegíveis.
- Roteiro: `docs/design/reports/TESTE.md`. Testes: `clinical_reports_view_test.dart` e `reports_aggregation_test.dart`.
