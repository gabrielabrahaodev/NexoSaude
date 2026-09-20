---
name: screen-care-day
description: Meu dia do Modo Atendimento (só hoje, filtro por profissional).
title: Care Day (Meu dia)
tags:
  - nexosaude
  - brain
  - screens
  - atendimento
---

# Care Day (Meu dia)

`lib/screens/care/care_day_screen.dart` (+ `care_visit_screen.dart`, `remarcar_dialog.dart`)

## O que é

"Meu dia" do [[atendimento]]: só hoje da clínica; dentista/psicólogo vê só `dentistId == uid`; recepção vê todos + nome do profissional. Sem Bloqueado/Cancelado. Selo Pago via 1 query extra do dia.

## Quando usar

Rotina do profissional; pendência `remarcar` abre [[remarcar-dialog]] em vez da ficha.

## Fluxos

- Tile → `CareVisitScreen` (evolução + cobrança + próxima) ou diálogo de remarcação.
- Dentistas carregados de `users` por `allowedClinics` (mapa id→nome).

## Gotchas

> [!warning]
> Filtro de dentista é client-side de propósito (evita índice triplo). Query do dia já é limitada.
