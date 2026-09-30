---
operonId: nx-e7
status: stable
priority: C
tags:
  - nexosaude
  - area/avaliacao
title: E7 — Avaliações técnicas (decisões, não código)
type: epic
updated: 2026-09-30
---

# E7 — Avaliações técnicas (decisões, não código)

**Objetivo:** registrar trilhas avaliadas e arquivadas para não reabrir sem motivo.
**Critério de aceite:** cada trilha tem veredito escrito e próximos passos definidos.

## Entregas

- Auditoria do review externo `problemas.md`: 1,5/10 aproveitável (só KPI-exceções + higiene Cloudinary); resto descartado com evidência
- Comparativo modelos locais × online + prompt de teste com régua (reprovado: citações inventadas, calibragem invertida)
- RAG + fine-tuning: recomendação RAG-local primeiro; fine-tuning provavelmente desnecessário
- n8n × Pipedream × Make × Apps Script × gateways: matriz completa; decisão **arquivar automação** (sem infra) — retomada documentada
- Servidor grátis: Oracle free validado (2 OCPUs/12 GB atuais); truque Render+cron-job analisado e preterido

## Ver também

- [[00-index]], [[foundation/01-prd|PRD]]
