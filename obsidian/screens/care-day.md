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

Rotina do profissional; remarcação do portal se decide só na [[agenda-manager]] (aqui o card é normal).

## Fluxos

- Tile → modal com a ficha (`CareVisitPanel`: evolução + baixa de existente + próxima) em 92% da tela — sem nova tela; `CareVisitScreen` virou casca fina (compat).
- Cobrança recebe SOMENTE lançamento existente (criado em Pagamentos); nova sessão com seletor de profissional (padrão = atual) + só horários livres (`getBusySlots` por dentista) com revalidação no agendar.
- Próxima sessão sugerida (+7 dias, `repeatNextWeek` + `isSlotFree`, recarrega ao trocar profissional); botão "Repetir próxima semana" agenda direto.
- Presença em massa: checkbox nas rows `Aguardando Confirmação` (`needsConfirmation`, puro e testado) + barra "Confirmar presença (N)"; falha parcial avisa quais faltaram; seleção obsoleta é podada.
- Cards translúcidos (surface 72–92% + borda/sombra na cor do status) com `StatusChip`; dentistas carregados de `users` por `allowedClinics` (mapa id→nome).

## Gotchas

> [!warning]
> Filtro de dentista é client-side de propósito (evita índice triplo). Query do dia já é limitada.
