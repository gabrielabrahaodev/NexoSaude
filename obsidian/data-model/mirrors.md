---
title: Espelhos do portal
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - data-model
  - portal
---

# Espelhos do portal (`portal/{token}` e `portal_slots`)

Consolidação da fonte [[modules/portal-mirror]] (ver lá para sync, gotchas e deploys).

## `portal/{token}`

- 1 doc por paciente; token de 32 chars revogável; `get` público (doc opaco).
- Conteúdo mínimo: próximas 3 sessões + top-3 atrasos + totais + Pix + `propostasRecusadas` + `clinicId` (nada de histórico).
- Escrita só pelo app via `PortalMirrorSync.patient()`; `.set(..., merge: true)` nunca destrói campos do portal.
- Cadastro gera token + espelho; revogar apaga; excluir paciente apaga junto (cascata).

## `portal_slots/{clinicId}`

- Livres dos próximos 14 dias por dentista (`{dentistId: {data: ["HH:mm"]}}`); zero dado de paciente.
- Manutenção atômica: agendar/bloquear = `arrayRemove`; cancelar/desbloquear = `arrayUnion`.
- `ensureWindow()` completa a janela e apaga dias passados (throttle 6h via `windowBuiltAt`).

## Regra de ouro

Aceite sempre revalida no vivo (`getBusySlots`). Espelho é consultivo; deriva mostra slot errado, nunca causa double-booking.

Ver [[modules/portal-mirror]], [[screens/portal/portal-page|portal-page]], [[decisions/0001-firestore-mirror]].
