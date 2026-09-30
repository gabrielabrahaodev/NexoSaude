---
title: Links quebrados conhecidos
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - audit
---

# Links quebrados conhecidos (2026-09-30)

## Pré-existente (não causado pela reorg)

- Em `_tools/operon.md` (documentação de terceiros do plugin Operon, exemplo interno): `[[Draft migration guide]]` não resolve para nenhuma nota do vault. Era exemplo na doc original, anterior à reorg. Nenhuma ação tomada (arquivo de terceiros preservado intacto, só frontmatter adicionado e move).

## Aliases válidos (não quebrados, validados manualmente)

- `[[spec-atendimento-portal]]` e `[[spec-landing-master]]` resolvem via `aliases:` no frontmatter dos specs correspondentes. Validadores por nome de arquivo puro os marcam como quebrados por engano; no Obsidian funcionam.

## Referência futura (resolvida nesta branch)

- `[[_audit/reorg-report]]` citado no índice antes do relatório existir; resolvido com a criação deste relatório em `_audit/reorg-report.md`.
- [resolvido em 2026-09-30] exemplo convertido para codigo inline em [[_tools/operon]] (era nome de arquivo hipotetico na doc de terceiros)
