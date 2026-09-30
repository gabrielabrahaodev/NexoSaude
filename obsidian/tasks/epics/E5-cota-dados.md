---
operonId: nx-e5
status: Finished
priority: B
tags:
  - nexosaude
  - area/cota
title: E5 — Economia de cota e dados
type: epic
updated: 2026-09-30
---

# E5 — Economia de cota e dados

**Objetivo:** rotina diária abaixo de 5% das cotas do Spark, com folga para picos.
**Critério de aceite:** ~3,5k leituras/dia e ~300 escritas/dia estimadas; nenhum backfill recorrente.

## Entregas

- KPI por `birthMonth` (aniversariantes sem varrer 379 pacientes; `birthMonthOf` testado)
- Persistência Firestore ativa (streams custam deltas; limpeza no logout web com reload)
- Bug `terminated` no logout diagnosticado e corrigido (reload ressuscita o singleton) + E2E Playwright login→logout→login com 0 erros
- Migração delta: 10 pacientes + 58 agendamentos, contagens batidas, nada existente sobrescrito
- Projeto antigo desligado reversível (rules deny-all + hosting off, dados intactos)
- Scripts guardados: `migrate/rules-release.js` (deploy de rules via REST), `portal-rebuild-scoped.js`

## Ver também

- [[screens/reports/kpi-dashboard|kpi-dashboard]], [[portal-mirror]], [[foundation/01-prd|PRD]]
