---
title: ADR 0005 — Conflitos de escrita nos espelhos do portal
type: adr
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - adr
  - portal
---

# ADR 0005 — Conflitos de escrita nos espelhos do portal

<!-- fonte: lib/services/portal_mirror.dart:302,332,386-388,438-446 -->

## Contexto

O app e o portal público escrevem nos mesmos documentos (portal por token e portal_slots) sem backend para arbitrar. Uma escrita do app nunca pode apagar um pedido do paciente, e dois agendamentos concorrentes nunca podem reservar o mesmo slot.

## Decisão

Toda escrita do app usa merge que preserva os campos do portal. Sincronização por deltas (upsert e remove cirúrgicos, nunca rebuild fora de cadastro, revogação ou backfill). Slots livres via operações atômicas de adição e remoção de array. Regra de ouro: o aceite sempre revalida no dado vivo, então deriva de espelho mostra slot errado mas nunca causa double-booking real.

## Consequências

- Pedidos do portal (confirmação, remarcação, aviso de pagamento) sobrevivem a qualquer sync do app.
- Concorrência em slots resolvida pelo próprio Firestore via transform atômico.
- Rebuilds raros mantêm o custo de escrita baixo.

## Alternativas

- Transação a cada escrita: descartado pelo custo de leituras no Spark.
- Trava distribuída: impossível sem backend.

Ver [[decisions/0001-firestore-mirror]], [[modules/portal-mirror]], [[data-model/mirrors]].
