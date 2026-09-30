# AGENTS.md — Guia de navegação do vault para agentes de IA

## Por onde começar
1. Leia `CONTEXT.md` (1 página, o que é o NexoSaúde).
2. Leia `00-index.md` (mapa geral).
3. Consulte `glossary.md` para termos do domínio.
4. Só então vá para `modules/`, `screens/` ou `flows/` conforme a tarefa.

## Fonte de verdade (ordem de precedência)
| Nível | Pasta/Arquivo | O que representa |
|---|---|---|
| 1 | `foundation/01-prd.md` | Intenção do produto |
| 2 | `foundation/02-use-cases.md` | Comportamento esperado |
| 3 | `modules/*` | Como funciona hoje (implementado) |
| 4 | `data-model/*` | Estrutura de dados |
| 5 | `decisions/*` (ADRs) | Decisões arquiteturais |
| 6 | `specs/*` | Propostas (ainda não implementadas) |
| 7 | `archive/*` | Histórico (não usar como referência) |

**Regra:** se a mesma afirmação aparece em dois níveis, o de menor número vence.
O outro arquivo deve ter um `Ver também:` em vez de repetir.

## Convenções
- Nomes de arquivo: `kebab-case.md`, sem espaços, sem caps.
- Frontmatter obrigatório: `title`, `type`, `status`, `updated`.
- `type` ∈ {module, screen, spec, adr, flow, runbook, integration, epic}.
- `status` ∈ {draft, stable, deprecated}.
- Todo arquivo de código mencionado deve ter caminho completo (ex.: `lib/features/agenda/agenda_screen.dart`).

## O que NÃO fazer
- Não editar `archive/`.
- Não duplicar conteúdo entre níveis — linke.
- Não inventar campos de Firestore ou nomes de arquivo `.dart`.
