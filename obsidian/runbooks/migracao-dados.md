---
title: Migração de dados
type: runbook
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - runbook
  - migracao
---

# Migração de dados

Fragmentos que existem no vault (fonte: [[modules/portal-mirror]], `foundation/01-prd.md` §4). Sem runbook completo hoje.

## O que existe no vault

- Backfills citados: `slots-backfill.js`, `portal-backfill.js` (mesma regra `isPortalProfessional` do app).
- Rebuild de espelhos só em cadastro/revogação/backfill; derivas tratadas por helper único + aceite que revalida no vivo.
- Scripts `migrate/` com Admin SDK (citados no PRD como via de automação no Spark).
- 6 contas migradas com hash; senhas redefinidas via `reset-senha.bat` (PRD §4).

## TODOs

- TODO: inventariar scripts `migrate/` e backfills (não descritos no vault).
- TODO: escrever procedimento padrão (backup, ordem, verificação).

Ver [[modules/portal-mirror]], [[data-model/mirrors]].
