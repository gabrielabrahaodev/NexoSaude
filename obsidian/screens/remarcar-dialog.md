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

Diálogo único usado pela agenda e pelo [[care-day]]: mostra a data proposta; **Aceitar agendamento** revalida choque (`getBusySlots`), move a data, confirma, sincroniza espelhos (portal reflete o horário) e pergunta se envia WhatsApp de confirmação (`confirmText`, testado); **Recusar e avisar** volta pra `Aguardando Confirmação`, registra nas recusadas e abre `wa.me` com texto de `refuseText` (testado).
Célula laranja: grade da agenda (`event_repeat`, fundo 10%) + card do Meu dia (borda, fundo, chip).

## Quando usar

Selo "Decidir remarcação" (agenda) ou card destacado (Meu dia).

## Gotchas

> [!warning]
> Recusa restaura `Aguardando Confirmação` (padrão do agendamento), nunca string inventada — o portal decide por conceito.

Ver [[portal-mirror]], [[portal-page]], [[atendimento]].
