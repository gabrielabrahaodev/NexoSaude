---
name: screen-main-dashboard
description: Shell principal — sidebar responsiva, seletor de clínica, menu por papel e tipo.
---

# MainWebDashboard

`lib/screens/dashboard/main_web_dashboard.dart`

## O que é

Layout + navegação (índices 0–12). Mobile (<900px) usa drawer; desktop usa sidebar
(compacta <1100px). Telas com `ValueKey(_currentClinicId)` para rebuild na troca.

## Quando usar

Adicionar nova tela ao menu, guard por papel/tipo, seletor de clínica.

## Mapa (índice → tela)

0 Agenda · 1 Pacientes · 2 Laboratório · 3 Financeiro · 4 Relatórios ·
5 Notícias · 6 Cobranças · 7 Clínicas (owner) · 8 Funcionários (owner) ·
9 Gestão (owner/recep) · 10 Fluxo Terapêutico (psico).

## Gotchas

- Novas telas: entrar em `_screens` **e** `_buildMenuContent` com guard.
- Itens 11/12 via `ClinicCapabilities.canShowTherapeuticFlow/canUseMonthlyPackages`.
- `withOpacity` aqui já migrado para `withValues`.
