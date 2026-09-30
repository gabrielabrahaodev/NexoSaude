---
title: ADR 0006 — Throttle da janela de slots do portal
type: adr
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - adr
  - portal
  - cota
---

# ADR 0006 — Throttle da janela de slots do portal

<!-- fonte: lib/services/portal_mirror.dart:454-471,523-534 -->

## Contexto

A janela de 14 dias de horários livres precisa de manutenção contínua (completar dias futuros, apagar passados) e não há backend para agendar isso.

## Decisão

A rotina ensureWindow roda no login do app com throttle de 6 horas via campo windowBuiltAt (uma leitura para decidir). O rebuild completa os dias faltantes, apaga dias passados, pula metadados e ignora chaves sem ponto (compatibilidade com formato antigo). Entre rebuilds, mutações de agenda ajustam só o dia afetado.

## Consequências

- No máximo um rebuild a cada 6 horas por clínica, independente de quantos logins.
- Janela sempre cobre 14 dias sem varredura a cada abertura de tela.
- Mudança de grade exige rebuild manual, documentado no runbook de migração.

## Alternativas

- Rebuild a cada abertura: descartado pelo custo de leituras e escritas.
- Agendamento por servidor: impossível no plano Spark.

Ver [[decisions/0001-firestore-mirror]], [[data-model/mirrors]], [[glossary]].
