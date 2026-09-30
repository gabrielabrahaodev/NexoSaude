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

Diálogo único usado pela agenda e pelo [[screens/agenda/care-day|care-day]]: mostra a data proposta; **Aceitar agendamento** revalida choque (`getBusySlots`) e expiração (`propostaExpirada`, testada; passado → "Recuse e peça outra data"), move a data, confirma, sincroniza espelhos (portal reflete o horário) e pergunta se envia WhatsApp (`confirmText`: "seu reagendamento foi confirmado..." + link do portal com token, testado); **Recusar e avisar** volta pra `Aguardando Confirmação`, registra nas recusadas e abre `wa.me` com texto de `refuseText` (testado).
Portal (`portal.html#abrirRemarcar`) lista só dias ≥ hoje — slot vencido não é oferecido.
Sem "Confirmar Presença (Manual)" em evento `remarcar` (aceitar já confirma); header da sheet rotula "Atual X → Proposto Y".
Célula laranja: grade da agenda (`event_repeat`, fundo 10%) + card do Meu dia (borda, fundo, chip).

## Quando usar

Selo "Decidir remarcação" (agenda) ou card destacado (Meu dia).

## Gotchas

> [!warning]
> Recusa restaura `Aguardando Confirmação` (padrão do agendamento), nunca string inventada — o portal decide por conceito.

Ver [[portal-mirror]], [[screens/portal/portal-page|portal-page]], [[flows/atendimento|atendimento]].
