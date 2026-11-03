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

`PortalMirrorSync.patient()` em todo ponto de escrita; `occupy/releaseSlot` nas mutações de agenda; `ensureWindow()` ao abrir a agenda (throttle 6h via `windowBuiltAt`, 1 leitura) — janela 14 dias com fim de semana; portal lista só dias ≥ hoje.

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
- Deploy do portal: `flutter build web` NÃO atualiza `build/web/sistema-interno/` (cópia manual) — sincronizar `web/*.html` → lá antes de `firebase deploy --only hosting`. `portal_slots` com chave sem `.` quebra o JS antigo: todo leitor deve pular chaves sem ponto.
- Deploy completo: `powershell -File tool/bump_version.ps1` → `flutter build web` → sync `sistema-interno` → `firebase deploy --only hosting`. O app avisa "Nova versão" sozinho (`version.json` + localStorage).
- Profissionais do espelho (`isPortalProfessional`, testado): papéis clínicos + owner em clínica psicológica (psicólogo atuante).

Ver [[portal-page]], [[remarcar-dialog]], [[atendimento]].

## Conferência de saldo e isolamento — 03/11/2026

Na variante clínica, `buildPortalMirror` remove sessões canceladas da lista de próximas e considera dívidas com valor em aberto: o total somado usa `amount - paidAmount`, excluindo cobranças canceladas/substituídas e quitadas. Conferir especialmente registros legados com `amount` integral e `paidAmount` parcial, e registros recentes representados por saldo remanescente + filhas. Evitar somar novamente o valor pago ou exibir Pix integral de cobrança parcialmente recebida. Esse cálculo puro não comprova a publicação do espelho nem o fluxo real do Pix.

A fonte de autorização e revogação está em `firestore.rules` e no token atual do paciente. O espelho é **consultivo**; confirmação/remarcação e slots devem ser revalidados no dado vivo. Exigir testes do emulador e do navegador antes da liberação; ver [[auditoria-codigo-2026-11-03]] e [[financial]].
