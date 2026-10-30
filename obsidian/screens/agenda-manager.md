---
title: Agenda Manager
tags:
  - nexosaude
  - brain
  - screens
name: screen-agenda-manager
description: Grade semanal de agendamentos com finalização (Realizado/Falta/Atestado), encaixe e cancelamento.
---

# AgendaManagerScreen

`lib/screens/agenda/agenda_manager_screen.dart` (+ `agenda_cell_factory.dart`)

## O que é

Grade semanal (6 dias × slots 30min) lendo `appointments` via `getByDateRange`.
Filtro por dentista; dentista só vê o próprio.

## Quando usar

Ver/editar/cancelar/finalizar atendimento; célula vazia cria; long-press exclui.

## Fluxos

- Célula vazia → `AgendaCellFactory.openForm` (psico: form de pacote; dental: `AgendaForm` com pré-preenchimento).
- Ocupada → bottom sheet: editar, encaixe (máx 2), ver prontuário, finalizar, cancelar (soft) ou excluir (hard, `delete`).
- Finalizar → dialog Realizado (exige descrição; dental tem dropdown de plano/procedimento, **psico não — usa o vínculo do pacote automaticamente**) / Não Compareceu (motivo + **Apresentou Atestado**); grava `attendanceStatus`, `hasMedicalCertificate` e lança `clinical_records`.

## Gotchas

- `value` de `DropdownButtonFormField` depreciado → `initialValue`; `Radio groupValue/onChanged` → `RadioGroup`.
- Slots derivam de `durationMinutes` (30min base); bloqueios e cancelados têm render próprio (cenários A/B/C em `_buildCell`).
- Nome na célula (`_buildCellLabel`): até 2 linhas + `FittedBox.scaleDown` como rede (linha da grade tem 32px fixos; celular estreito não estoura).
- Carregamento: `AgendaSkeleton` (shimmer, `screens/agenda/agenda_skeleton.dart`) enquanto `waiting`; erro explícito, sem loader infinito. Shimmer compartilhado em `widgets/shimmer_box.dart` (também usado pelo `BillingSkeleton`).
- Filtro de dentista é assíncrono (`_checkRoleAndFetchDentists`): a grade segura no skeleton enquanto `_isLoadingDentists` p/ não exibir tudo sem filtro e trocar depois.
- Filtro de profissional: campo fino em largura total (`isDense`, padding vertical 4).

## Atualizações (web-designer + portal)

- Cache mensal deslizante (`MonthAgendaCache`): janela anterior/atual/próxima; semana em cache = zero leitura. Ver [[care-day]].
- Bloqueio/desbloqueio atualiza `portal_slots` via `adjustSlots` (1 escrita). Ver [[portal-mirror]].
- Menu "Decidir remarcação" abre [[remarcar-dialog]].

## Alternativa visual para avaliação (30/10/2026)

- Branch `feat/agenda-clinical-dark`: `clinical_agenda_view.dart` recebe a lista do mesmo cache, já filtrada por profissional, e delega ações à agenda existente.
- Tema escuro local à Agenda; desktop semanal/diário, mobile diário abaixo de 768px com faixa de sete dias e navegação inferior no shell. Não modifica a preferência global de tema.
- `--dart-define=AGENDA_CLINICAL_DARK=false` restaura a apresentação anterior para comparação.
- Contagem exclui cancelados/bloqueios; sem percentual fictício de ocupação. Os estados e intervalos dos dados continuam visíveis.
- Teste manual e limites: `docs/design/agenda/TESTE.md`. Expandir o visual para o restante do sistema somente após avaliação do usuário.
