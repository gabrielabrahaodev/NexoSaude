---
name: screen-main-dashboard
description: Shell principal — sidebar responsiva, seletor de clínica, menu por papel e tipo.
---

# MainWebDashboard

`lib/screens/dashboard/main_web_dashboard.dart`

## O que é

Layout + navegação (índices 0–11 em `_screens`, fixos). Mobile (<900px) usa drawer; desktop usa sidebar
(compacta <1100px). Telas com `ValueKey(_currentClinicId)` para rebuild na troca.

## Quando usar

Adicionar nova tela ao menu, guard por papel/tipo, seletor de clínica.

## Mapa (índice → tela) + ordem do menu por tipo

Índices: 0 Dashboard · 1 Agenda · 2 Pacientes · 3 Laboratório · 4 Financeiro · 5 Relatórios ·
6 Notícias · 7 Cobranças · 8 Clínicas (owner) · 9 Funcionários (owner) ·
10 Gestão (owner/recep) · 11 Fluxo Terapêutico (psico). Abre no Dashboard (`_selectedIndex = 0`).

- Dental: ordem dos índices (Fluxo fora).
- Psico: 0, 1, 2, 7, 11, 4, 5, 6 (+ 8/9/10 por role); **3 Laboratório oculto**.
- Troca de clínica reseta p/ 0 se a tela atual sumiu do menu do novo tipo.

## Gotchas

- Novas telas: entrar em `_screens` **e** nos dois ramos do menu (dental/psico) com guard.
- Menu usa `ClinicCapabilities.ofType(_currentClinicType).isPsychology`.
- `withOpacity` aqui já migrado para `withValues`.
