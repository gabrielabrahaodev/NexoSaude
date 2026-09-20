---
name: hub-atendimento
description: Índice do Modo Atendimento + Portal (navegação do cluster).
title: Atendimento (hub)
tags:
  - nexosaude
  - brain
  - hub
  - atendimento
---

# Atendimento (hub)

Índice do cluster Modo Atendimento + Portal do paciente.

- [[care-day]] — Meu dia: só hoje, filtro por profissional, selo Pago.
- [[remarcar-dialog]] — decisão única aprovar/recusar (agenda + Meu dia).
- [[portal-mirror]] — espelhos `portal/` + `portal_slots/` e sync best-effort.
- [[portal-page]] — `portal.html`: sessões, atrasos, Pix, painel de remarcação.
- [[ui-consistency]] — `AppColors`, `StatusChip`, helpers com teste.
- [[agenda-manager]] — agenda semanal, cache mensal, bloqueios (alimenta slots).
- [[collections]] — selo "Avisei que paguei" e baixa.
- [[patient-details]] — link do portal (gerar/copiar/revogar) na aba Cadastro.

Especificação viva em [[PRD]] e `docs/superpowers/specs/`.
