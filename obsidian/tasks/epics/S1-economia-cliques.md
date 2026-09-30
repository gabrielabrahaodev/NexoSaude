---
operonId: nx-s1
status: Finished
priority: A
tags:
  - nexosaude
  - area/atendimento
title: S1 — Economia de cliques
type: epic
updated: 2026-09-30
---

# S1 — Economia de cliques

**Objetivo:** tirar toques do caminho feliz do atendimento (repetir próxima sessão em 1 gesto).
**Critério de aceite:** recepcionista/profissional agenda a próxima sessão sem date picker manual; nada muda nos fluxos 1–3 (não mexer).

## Tarefas

### nx-127 — Repetir próxima semana
Botão "mesmo horário na próxima semana" na ficha (`CareVisitPanel`, seção 3): pré-preenche dia/hora/profissional (+7 dias) validando choque via `getBusySlots`; confirmação vira 1 toque. Ver [[screens/agenda/care-day|care-day]].
**Aceite:** agenda +7 dias livres agenda direto; dia cheio avisa e não agenda.
