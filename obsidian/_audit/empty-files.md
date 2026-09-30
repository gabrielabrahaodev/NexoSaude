---
title: Arquivos vazios ou inacessíveis
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - audit
---

# Arquivos vazios ou inacessíveis (auditoria 2026-09-30)

Levantamento da FASE 0 (`chore/vault-reorg-2026-09-30`).

## Vazios (0 bytes)

- `obsidian/Sem título.canvas` — 0 bytes, canvas sem conteúdo. Não inventado conteúdo; manter até decisão de arquivar/remover.

## Inacessíveis (erro de leitura)

- Nenhum (todos os demais arquivos abriram para leitura em 2026-09-30).

## Observações de encoding

- `obsidian/Operon/Kanban NexoSaúde.md`, `obsidian/Operon/Tasks/E4 - Acesso e Multiclínica.md`, `obsidian/Operon/Tasks/E7 - Avaliações Técnicas.md` exibem mojibake no console Windows (`NexoSaúde`), mas o conteúdo em disco é UTF-8 válido e legível. Não editar bytes, apenas mover com `git mv`.
- Vários `modules/*.md` e `screens/*.md` contêm mojibake herdado no corpo (ex.: (trechos com mojibake herdado no corpo), preservado como está. Correção ortográfica fora do escopo desta reorg.
