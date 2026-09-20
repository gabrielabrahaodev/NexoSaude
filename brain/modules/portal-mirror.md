---
name: module-portal-mirror
description: Espelhos portal/{token} e portal_slots/{clinicId} + sync best-effort.
title: Espelhos do Portal
tags:
  - nexosaude
  - brain
  - modules
  - portal
---

# Espelhos do Portal

`lib/services/portal_mirror.dart` (+ `sync`, `slots-backfill.js`, `portal-backfill.js`)

## O que é

Sem Functions, o portal lê espelhos: `portal/{token}` (3 sessões + top-3 atrasos + totais + Pix + recusadas + `clinicId`) e `portal_slots/{clinicId}` (livres 14 dias por dentista, `arrayUnion/Remove` atômicos).

## Quando usar

`PortalMirrorSync.patient()` em todo ponto de escrita; `occupy/releaseSlot` nas mutações de agenda; `ensureWindow()` no login (owner/recepção).

## Fluxos

- Cadastro gera token + espelho inicial; revogar apaga o espelho; excluir paciente apaga junto (cascata).
- `.set(..., merge: true)` — sync nunca destrói campos escritos pelo portal.

## Gotchas

> [!danger]
> Regra de ouro: aceite sempre revalida no vivo (`getBusySlots`). Espelho é consultivo; deriva mostra slot errado, nunca causa double-booking real.

Ver [[portal-page]], [[remarcar-dialog]], [[atendimento]].
