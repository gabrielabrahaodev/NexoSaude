---
title: Relatório de consolidação do vault
type: spec
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - audit
---

# Relatório de consolidação — 2026-09-30

Branch: chore/vault-consolidation-2026-09-30. Base real: chore/vault-fixups-2026-09-30 (fixups ainda não mergeada em master, conforme previsto na Fase 0).

## Escopo

Ciclo completo: CHANGELOG, verificação automatizada, CI, população de TODOs, ADRs derivados.

## Resultado por fase

| Fase | Status | Artefatos |
|---|---|---|
| 1 — CHANGELOG | done | entrada dupla (fixups + consolidação, com N=9 e M=3 preenchidos) |
| 2 — verify.sh | done | 10 checagens, exit 0/1/2, log gerado |
| 3 — CI | done | vault-verify.yml válido (1 job, 3 steps, tolera WARN) + seção no AGENTS |
| 4 — Inventário TODOs | done | todo-report.md com 14 TODOs (9A, 1B, 1C, 3D) |
| 5a — TODOs código | done | 9 resolvidos com fonte citada |
| 5b — TODOs dedução | done | 1 resolvido |
| 5c — TODOs git | done | 1 resolvido (resultado negativo documentado) |
| 5d — TODOs bloqueados | done | 3 reformulados como acionáveis |
| 6 — ADRs | done | 3 criados + 1 complemento no ADR 0002 |

## Validação final

- Wikilinks quebrados: 0 de projeto (443 checados; 2 aliases válidos no Obsidian + 1 registro histórico proposital)
- TODOs restantes: 4 (3 bloqueados acionáveis + 1 residual de limites de API)
- Arquivos com frontmatter inválido: 0
- Órfãos: 0
- verify.sh final: 8 PASS, 2 WARN (TODOs e kebab-case conhecidos), 0 FAIL

## Bloqueios

- nenhum. Todas as fases tinham fonte suficiente.

## Divergências vault × código encontradas

- clinics/id/leads sem regra dedicada em firestore.rules (deny padrão; app escreve via avaliação pública)
- Allowlist do portal tem 4 chaves, sem propostasRecusadas (vault citava 5)
- anticipations sem leitores nem escritores no app e sem bloco nas rules (tabela corrigida)
- Campo formats inexistente no código do projeto (só em plugin de terceiros)
- E1 cita 51 índices; firestore.indexes.json tem 53 (drift de 2 desde a entrega)

## Ajustes assumidos sobre o especificado

- Check 4 do verify.sh com alias-awareness (aliases do frontmatter resolvem; sem isso, links válidos dariam FAIL falso)
- CI tolera exit 2 (só WARN) e falha só no exit 1 (sem isso, TODOs pendentes deixariam o CI sempre vermelho)
- Topic branches S1-S3 normalizados junto (S1/S2 stable, S3 draft) por coerência com a Fase 2 anterior

## Próximos passos sugeridos

- Dono: medir baselines (no-show e tempo de confirmação), levantar custo do Cloudinary, cadastrar WhatsApp da clínica, confirmar limites das APIs e status de S3
- Validar comando de deploy dos índices em ambiente com Firebase CLI
- Considerar links simples sem texto de exibição para sobreviverem a moves futuros
- Quebrar foundation/04-requisitos.md por seção se leitura integral pesar para agentes
