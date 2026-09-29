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
