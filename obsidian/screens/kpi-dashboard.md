---
title: Kpi Dashboard
tags:
  - nexosaude
  - brain
  - screens
name: screen-kpi-dashboard
description: Dashboard de KPIs da clínica (item 1 do menu) — receber, inadimplência, hoje, aniversariantes.
---

# KpiDashboardScreen

`lib/screens/dashboard/kpi_dashboard_screen.dart`

## O que é

Cabeçalho (Visão geral + clínica/mês) + 4 cards + próximos vencimentos (top 5,
com badge ATRASADO e link "Ver em Cobranças") + aniversariantes (link "Ver em
Pacientes"). Largura máxima 1100 centralizada; 2×2 abaixo de 720px.
`onNavigate` recebe `_onMenuSelect` (índices: Cobranças 7, Pacientes 2).

## Quando usar

Visão do dia, cobrança prioritária (vermelho = vencido), parabéns do mês.

## Fluxos

- 3 streams: `financial` pendente, `appointments` de hoje, `patients` filtrados por `birthMonth == MM` (aniversariantes sem varrer a clínica; campo gravado no cadastro/edição + `birthMonthOf` testado).
- `birthDate` é String `DD/MM/AAAA` — parse defensivo, mês/dia inválidos ignorados.
- Sem vencimento cai no fim da lista de próximos.

## Gotchas

- Índices compostos necessários: `financial(clinicId,status)` e `appointments(clinicId,date)` — ver `firestore.indexes.json`.

## Ver também

- [[financial]] — a receber e inadimplência
- [[collections]] — "Ver em Cobranças"
- [[patient-list]] — "Ver em Pacientes" (aniversariantes)
- [[main-dashboard]] — shell que hospeda o KPI

## Redesenho Clinical Precision — novembro/2026
Apresentação em `clinical_dashboard_view.dart`, com quatro cartões, alertas de exceção, tabela de vencimentos e coluna de status/aniversariantes. Claro/escuro, coluna única no mobile e adaptação 2/4 cartões. Fontes memorizadas por clínica/dia; erros de streams bloqueiam valores parciais. Receitas `cobrado`, `parcial` e `partial` continuam pendentes; saldo não positivo é ignorado. Moeda pt-BR, nascimento Timestamp pelo PatientModel. Novo agendamento reutiliza AgendaCellFactory; lembretes navegam à régua manual. Sem telemetria real de ocupação/plantão: informação explícita, sem dados ilustrativos. Mês atual; valores de pacotes são os saldos registrados (apuração permanece em Cobranças). Roteiro e limitações: `docs/design/dashboard/TESTE.md`.
