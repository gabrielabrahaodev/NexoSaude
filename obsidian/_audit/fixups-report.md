---
title: Relatório de fixups do vault
type: spec
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - audit
---

# Relatório de fixups — 2026-09-30

Branch: chore/vault-fixups-2026-09-30, a partir de chore/vault-reorg-2026-09-30. Push direto ao final de cada fase.

## Fases executadas

- [x] Fase 1 — frontmatter AGENTS e CHANGELOG. Prependido via script sem tocar no corpo. Incidente: primeira tentativa perdeu os valores das tags por interferência do transporte, refeito com construção por códigos de caractere e verificado byte a byte.
- [x] Fase 2 — status dos épicos. Resultado: 9 stable, 1 draft, 1 TODO.
  - E1 até E7: 7 stable. Todos estavam Finished no Operon com entregas implementadas no corpo (código real, testes, specs concluídas).
  - Extras S1 e S2: stable (tarefas marcadas como feitas no backlog). S3: draft (estava Planned, sem evidência de conclusão).
- [x] Fase 3 — Requisitos vai para foundation/04-requisitos.md. Justificativa: catálogo de RN por módulo, par natural de 01-prd e 02-use-cases, grande demais para mesclar, preservado intacto via git mv. PSYCHOLOGY_PACKAGES vai para modules/psychology-packages-billing.md. Justificativa: detalhe de billing implementado e com decisões travadas, companheiro do resumo em modules/psychology-packages.md, nome em kebab-case. Desvio documentado: o destino sugerido era foundation/05, recusado porque o conteúdo é comportamento implementado e não intenção de produto. Links atualizados em 10 arquivos, índice com linhas novas nas tabelas de foundation e modules, zero restos na raiz.
- [x] Fase 4 — wikilink do Operon corrigido. O link era nome de arquivo hipotético em exemplo da doc de terceiros, convertido para texto de exemplo sem colchetes em _tools/operon.md. Registro histórico mantido em _audit/broken-links.md com linha de resolvido.
- [x] Fase 5 — gotcha de pipe documentado no final do AGENTS.md. Incidente: a primeira escrita fragmentou crases e pipes em quebras de linha por interferência do transporte, reparado por reconstrução via códigos de caractere e verificado byte a byte. Recomendação registrada no próprio AGENTS.

## Bloqueios

- nenhum. Todas as fases tinham informação suficiente no vault.

## TODOs deixados

- TODO: confirmar status de S3 (qualidade do atendimento). Estava Planned no Operon, marcado draft por falta de evidência de conclusão.
- Seguem válidos os 14 TODOs do relatório da reorg em _audit/reorg-report.md.

## Validação

- Wikilinks: 443 no total, 0 quebrados de projeto. Três aparentes explicados: um registro histórico proposital dentro de _audit/broken-links.md e dois aliases válidos de specs que resolvem no Obsidian.
- Arquivos com frontmatter inválido: 0. AGENTS.md e CHANGELOG.md conferidos linha a linha.
- Status fora da taxonomia draft stable deprecated em frontmatter: 0. Ocorrências restantes são campos inline do Operon no corpo das notas e texto da doc de terceiros, fora do escopo.
- Requisitos.md e PSYCHOLOGY_PACKAGES.md fora da raiz: confirmado, ambos ausentes do topo de obsidian.
- Arquivos com pipe escapado por transporte: 0 em todo o vault após as correções.
