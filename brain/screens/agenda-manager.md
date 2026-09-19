---
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
- Carregamento: `AgendaSkeleton` (shimmer, `screens/agenda/agenda_skeleton.dart`) enquanto `waiting`; erro explícito, sem loader infinito. Shimmer compartilhado em `widgets/shimmer_box.dart` (também usado pelo `BillingSkeleton`).
- Filtro de dentista é assíncrono (`_checkRoleAndFetchDentists`): a grade segura no skeleton enquanto `_isLoadingDentists` p/ não exibir tudo sem filtro e trocar depois.
