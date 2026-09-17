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

0 Dashboard · 1 Agenda · 2 Pacientes · 3 Laboratório · 4 Financeiro · 5 Relatórios ·
6 Notícias · 7 Cobranças · 8 Clínicas (owner) · 9 Funcionários (owner) ·
10 Gestão (owner/recep) · 11 Fluxo Terapêutico (psico). Abre no Dashboard (`_selectedIndex = 0`).

## Gotchas

- Novas telas: entrar em `_screens` **e** `_buildMenuContent` com guard.
- Itens 11/12 via `ClinicCapabilities.canShowTherapeuticFlow/canUseMonthlyPackages`.
- `withOpacity` aqui já migrado para `withValues`.
