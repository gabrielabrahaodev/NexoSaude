---
title: Relatório de TODOs do vault
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - audit
---

# Relatório de TODOs — 2026-09-30

Inventário inicial da Fase 4 (fora de _audit). Classificação: A código, B git, C dedução do vault, D bloqueado.

## Resumo

- Total: 14
- A (código): 9
- B (git): 1
- C (dedução): 1
- D (bloqueado): 3

## Detalhe

| # | Arquivo:linha | TODO | Classificação | Status |
|---|---|---|---|---|
| 1 | CONTEXT.md:39 | confirmar baseline de no-show e tempo por confirmação | D | pending |
| 2 | data-model/collections.md:59 | conferir lista contra firestore.rules e firestore.indexes.json | A | pending |
| 3 | data-model/indexes.md:31 | importar lista exata de firestore.indexes.json | A | pending |
| 4 | data-model/indexes.md:32 | registrar comando de deploy dos índices | A | pending |
| 5 | data-model/security-rules.md:30 | importar de firestore.rules | A | pending |
| 6 | decisions/0002-multitenant-session.md:32 | alternativas anteriores não registradas | B | pending |
| 7 | integrations/cloudinary.md:27 | custo e limite Cloudinary fora do free tier | D | pending |
| 8 | integrations/europe-pmc.md:24 | chaves e limites das APIs | A | pending |
| 9 | integrations/europe-pmc.md:25 | limpeza do campo formats morto | A | pending |
| 10 | integrations/whatsapp.md:30 | número oficial e conta comercial | D | pending |
| 11 | runbooks/deploy.md:25 | passo a passo completo de deploy | A | pending |
| 12 | runbooks/deploy.md:26 | comando de deploy de rules e índices | A | pending |
| 13 | runbooks/migracao-dados.md:25 | inventariar migrate e backfills | A | pending |
| 14 | runbooks/migracao-dados.md:26 | procedimento padrão de migração | C | pending |

## ADRs criados na Fase 6

- (preencher na Fase 6)


## Resultado Fase 5
- Resolvidos: 10 (itens 2, 3, 4, 5, 6, 9, 11, 12, 13, 14)
- Resolvido-parcial: 1 (item 8: chaves respondidas, limites viraram TODO residual em integrations/europe-pmc.md)
- Bloqueados: 3 (itens 1, 7, 10, reformulados como acionáveis)
