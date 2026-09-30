---
title: Main Dashboard
tags:
  - nexosaude
  - brain
  - screens
name: screen-main-dashboard
description: Shell principal — sidebar responsiva, seletor de clínica, menu por papel e tipo.
---

# MainWebDashboard

`lib/screens/dashboard/main_web_dashboard.dart`

## O que é

Layout + navegação (índices 0–13 em `_screens`, fixos). Mobile (<900px) usa drawer; desktop usa sidebar
(rail 900–1099, cheia 1100+). Telas com `ValueKey(_currentClinicId)` para rebuild na troca.

## Quando usar

Adicionar nova tela ao menu, guard por papel/tipo, seletor de clínica.

## Mapa (índice → tela) + ordem do menu por tipo

Índices: 0 Dashboard • 1 Agenda • 2 Pacientes • 3 Laboratório • 4 Financeiro • 5 Relatórios •
6 Notícias • 7 Cobranças • 8 Clínicas • 9 Funcionários •
10 Gestão • 11 Fluxo Terapêutico (psico) • 12 Atendimento • 13 Master.
Ordem visual: Agenda, Pacientes, Dashboard…; abre na Agenda (`_selectedIndex = 1`).

- Dental: Agenda, Pacientes, Dashboard, Atendimento, Laboratório, Financeiro, Relatórios, Notícias, Cobranças.
- Psico: Agenda, Pacientes, Dashboard, Atendimento, Cobranças, Fluxo, Financeiro, Relatórios, Notícias (**3 Laboratório oculto**).
- Troca de clínica reseta p/ 0 se a tela atual sumiu do menu do novo tipo.

## Gotchas

- Novas telas: entrar em `_screens` **e** nos dois ramos do menu (dental/psico) com guard.
- Menu usa `ClinicCapabilities.ofType(_currentClinicType).isPsychology`.
- Visibilidade 100% via `MenuAccess` (`_canShow`): sem `if (role)` hardcoded — DONO/MASTER/GESTÃO passam pelo mapa com defaults por papel (ver `test/menu_access_test.dart`).
- Seletor de clínica: owner OU `allowedClinics.length > 1` (ex.: recepção em 2 clínicas); some sozinho com 1 só. Staff lista por `documentId whereIn` (máx 10, sem índice novo).
- Administração (Clínicas/Funcionários/Master/Gestão/**Exportar**) em `ExpansionTile` que inicia **fechado** (rail compacto: ícones avulsos); ao expandir, o scroll acompanha (`_menuScroll`). Exportar (índice 14, chave `exportar` owner-only) baixa backup JSON/CSV.
- Rodapé em linha única: card do usuário (avatar + nome + papel • clínica) + botão sair quadrado ao lado; `role_check` grava `name/email` na sessão.
- PWA: `_checkAppVersion` compara `version.json` publicado com localStorage a cada troca de menu (1 aviso por sessão) e oferece "Atualizar agora" (`tool/bump_version.ps1` carimba no deploy via `deploy.bat`).
- `withOpacity` aqui já migrado para `withValues`.

## Ver também

- [[session-multitenant]] — sessão, clínica e capacidades
- [[screens/auth/auth-login-rolecheck|auth-login-rolecheck]] — quem chega aqui
- [[screens/agenda/agenda-manager|agenda-manager]] — tela inicial do app
- [[screens/operations/operations-manager|operations-manager]] — Gestão com abas filtradas
