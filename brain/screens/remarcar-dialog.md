---
name: screen-remarcar-dialog
description: Diálogo único de decisão da remarcação (agenda + Meu dia).
title: Diálogo Decidir Remarcação
tags:
  - nexosaude
  - brain
  - screens
  - atendimento
---

# Diálogo Decidir Remarcação

`lib/screens/care/remarcar_dialog.dart` + `lib/services/remarcacao_service.dart`

## O que é

Diálogo único usado pela agenda e pelo [[care-day]]: mostra a data proposta; **Aprovar** revalida choque (`getBusySlots`), move a data, confirma e sincroniza espelhos; **Recusar e avisar** volta pra `Aguardando Confirmação`, registra nas recusadas e abre `wa.me` com texto de `refuseText` (testado).

## Quando usar

Selo "Decidir remarcação" (agenda) ou card destacado (Meu dia).

## Gotchas

> [!warning]
> Recusa restaura `Aguardando Confirmação` (padrão do agendamento), nunca string inventada — o portal decide por conceito.

Ver [[portal-mirror]], [[portal-page]], [[atendimento]].
