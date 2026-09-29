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


## Atualizações (cota)

- Sync por deltas (upsertSession/removeSession/upsertDebt, testados): 2 leituras + 1 escrita; rebuild só em cadastro/revogação/backfill; slots sem varredura no login. Ver [[pix-brcode]].

## Gotchas

> [!danger]
> Regra de ouro: aceite sempre revalida no vivo (`getBusySlots`). Espelho é consultivo; deriva mostra slot errado, nunca causa double-booking real.

- Form psico grava em batch fora do `AppointmentService`: `_generateAppointments` e `_cancelSchedule` fazem rebuild via `PortalMirrorSync.patient()` (sem isso o portal não recebe psicologia).
- Rebuild exclui `Cancelado` das próximas (igual ao delta `removeSession`); query com limit 100 p/ cobrir pacote anual (~52 sessões).
- Profissionais do espelho (`isPortalProfessional`, testado): papéis clínicos + owner em clínica psicológica (psicólogo atuante). Backfill `slots-backfill.js` com a mesma regra. Rebuild do `ensureWindow` expande `durationMinutes` (blocos por intervalo).
- Sem autocura LGPD: sync nunca cria token sem `accepted==true`; backfill full de portais bloqueado por padrão (sweep 09/2026: 415 espelhos apagados).
- Profissionais do espelho (`isPortalProfessional`, testado): papéis clínicos + owner em clínica psicológica (psicólogo atuante).

Ver [[portal-page]], [[remarcar-dialog]], [[atendimento]].
