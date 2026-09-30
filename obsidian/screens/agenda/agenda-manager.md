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

- Cache mensal deslizante (`MonthAgendaCache`): janela anterior/atual/próxima; semana em cache = zero leitura. Ver [[screens/agenda/care-day|care-day]].
- Bloqueio/desbloqueio atualiza `portal_slots` via `adjustSlots` (1 escrita). Ver [[portal-mirror]].
- Menu "Decidir remarcação" abre [[screens/agenda/remarcar-dialog|remarcar-dialog]].
