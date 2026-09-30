---
title: ADR 0001 — Espelhos Firestore para o portal
type: adr
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - adr
  - portal
---

# ADR 0001 — Espelhos Firestore para o portal

Fonte: [[modules/portal-mirror]].

## Contexto

O portal do paciente é uma página pública sem login; as rules do Firestore não enxergam o token da URL, então `patients/` e `financial/` seguem fechados. Sem backend (plano Spark), o portal precisa ler dados baratos (cota de 50 mil leituras/dia) com 1 doc por acesso.

## Decisão

Espelhar dados em `portal/{token}` (3 sessões + top-3 atrasos + totais + Pix + recusadas + `clinicId`) e `portal_slots/{clinicId}` (livres 14 dias por dentista), sincronizados por `PortalMirrorSync.patient()` nos pontos de escrita, com `ensureWindow()` no login.

## Consequências

- Portal lê 1 doc por acesso (cota irrisória); slots compartilhados sem dado de paciente.
- Risco de deriva: escrita esquecida mente no portal; mitigado por helper único + aceite que sempre revalida no vivo (`getBusySlots`) + backfills (`slots-backfill.js`, `portal-backfill.js`).
- Form psico grava em batch fora do `AppointmentService` e precisa de rebuild explícito.

## Alternativas

- Ler collections reais com rules por token: descartado — rules não enxergam token de URL.
- Cloud Functions para sync: descartado — plano Spark não tem backend (ver [[decisions/0003-sem-cloud-functions]]).
