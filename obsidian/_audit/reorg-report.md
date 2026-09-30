---
title: Relatório da reorganização do vault
type: spec
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - audit
---

# Relatório da reorganização do vault (2026-09-30)

Branch: `chore/vault-reorg-2026-09-30`. Estratégia: 10 fases, 1 commit por fase, `git mv` sempre, zero deleções de conteúdo.

## Contagem de arquivos

- Antes: 67 arquivos no vault sem contar `.obsidian` (115 contando `.obsidian`)
- Depois: 93 arquivos no vault sem contar `.obsidian` (141 contando `.obsidian`)
- Saldo: nenhum arquivo perdido, 26 arquivos novos criados
- Pasta `obsidian/Kanban` vazia e não rastreada foi removida do disco

## Arquivos movidos com git mv

Foundation, saindo da raiz para subpasta nova:

- `PRD.md` virou `foundation/01-prd.md`
- `CASOS_DE_USO.md` virou `foundation/02-use-cases.md`
- `DIAGRAMAS_DE_SEQUENCIA.md` virou `foundation/03-sequence-diagrams.md`

Fluxo:

- `Maps/atendimento.md` virou `flows/atendimento.md`, pasta `Maps` removida

Tasks, desmembrando `Operon` (pasta `Operon` removida):

- `Operon/Kanban NexoSaúde.md` virou `tasks/kanban.md`
- `Operon/LEIAME Kanban.md` virou `tasks/leiame.md`
- `Operon/Tables/Tarefas.table` virou `tasks/tarefas.table`
- `Operon/operon.md` virou `_tools/operon.md` (doc do plugin, não é conteúdo do projeto)
- Sete épicos `Operon/Tasks/E*.md` viraram `tasks/epics/E1-plataforma-assinatura.md` até `E7-avaliacoes-tecnicas.md`
- Extras preservados além do alvo: `S1`, `S2`, `S3` viraram `tasks/epics/S1-economia-cliques.md`, `S2-tempo-janelas.md`, `S3-qualidade-atendimento.md`, e `Sprint - Backlog.md` virou `tasks/epics/sprint-backlog.md`

Screens, 29 arquivos para 8 subpastas por domínio:

- `auth` com 1 arquivo: auth-login-rolecheck
- `agenda` com 4 arquivos: agenda-form, agenda-manager, remarcar-dialog, care-day
- `clinical` com 9 arquivos: patient-list, patient-details, patient-tabs, create-patient, budget-wizard, clinic-lab, psychology-kanban, psychology-schedule, ortho-news
- `financial` com 3 arquivos: collections, expenses, financial-report
- `operations` com 4 arquivos: operations-manager, operations-tabs, employee-manager, clinic-management
- `portal` com 2 arquivos: portal-page, public-evaluation
- `admin` com 3 arquivos: landing-page, master-screen, assinatura-page
- `reports` com 3 arquivos: reports, kpi-dashboard, main-dashboard
- Nenhum arquivo ficou sem classificar na raiz de `screens`

Conteúdo movido com redirecionamento:

- `modules/pix-brcode.md` teve o corpo transferido para `integrations/pix-brcode.md` e virou ponteiro com link

## Arquivos criados

Meta-documentação na raiz:

- `AGENTS.md`, `CONTEXT.md`, `glossary.md`, `CHANGELOG.md`

Pastas novas de conteúdo, preenchidas com o que já existia no vault:

- `data-model/collections.md`, `data-model/indexes.md`, `data-model/security-rules.md`, `data-model/mirrors.md`
- `integrations/whatsapp.md`, `integrations/cloudinary.md`, `integrations/pix-brcode.md`, `integrations/europe-pmc.md`
- `runbooks/deploy.md`, `runbooks/migracao-dados.md`

Decisões arquiteturais:

- `decisions/0001-firestore-mirror.md`, `decisions/0002-multitenant-session.md`, `decisions/0003-sem-cloud-functions.md`

Templates:

- `_templates/module.md`, `_templates/screen.md`, `_templates/spec.md`, `_templates/adr.md`, `_templates/flow.md`
- Atalhos previstos na arquitetura: `modules/_module-template.md`, `specs/_spec-template.md` (apontam para os canônicos, sem duplicar)

Auditoria:

- `_audit/empty-files.md`, `_audit/broken-links.md`, este `_audit/reorg-report.md`
- `archive/.gitkeep`

## Arquivos vazios e inacessíveis

- `Sem título.canvas` com 0 bytes, pré-existente, conteúdo não inventado, ver `_audit/empty-files.md`
- `archive/.gitkeep` com 0 bytes de propósito, placeholder do git, não é problema
- Nenhum arquivo inacessível para leitura

## Wikilinks atualizados

- Links para fundação: forma nova com caminho e texto, exemplo `foundation/01-prd` com texto `PRD`, 16 arquivos tocados
- Link `atendimento` virou caminho para `flows`, 9 arquivos tocados
- Links de épicos e sprints e board viraram caminhos para `tasks`, 4 arquivos tocados
- Links de telas viraram caminhos para `screens` por domínio, 53 arquivos tocados em 142 ocorrências
- Validação final em 437 links: zero quebrado de projeto. Restam 1 exemplo interno da doc de terceiros em `_tools/operon.md` registrado em `_audit/broken-links.md`, 3 links por alias de spec válidos no Obsidian, e a autorreferência a este relatório já resolvida

## TODOs deixados, 14 no total

- Em `CONTEXT.md`: confirmar baseline de no-show e tempo por confirmação
- Em `data-model/collections.md`: conferir lista contra rules e indexes do código
- Em `data-model/indexes.md`: importar lista exata de `firestore.indexes.json`, registrar comando de deploy
- Em `data-model/security-rules.md`: importar de `firestore.rules`
- Em `decisions/0002-multitenant-session.md`: documentar alternativas anteriores se houve
- Em `integrations/whatsapp.md`: número oficial da clínica e conta comercial
- Em `integrations/cloudinary.md`: monitorar custo e limite fora do free tier
- Em `integrations/europe-pmc.md`: chaves e limites das APIs, limpeza do campo `formats`
- Em `runbooks/deploy.md`: passo a passo completo e comando de deploy de rules e índices
- Em `runbooks/migracao-dados.md`: inventariar scripts `migrate` e backfills, procedimento padrão

## Exceções e decisões assumidas

- `AGENTS.md` e `CHANGELOG.md` ficaram exatamente com o conteúdo especificado, sem frontmatter, por precedência do mandato sobre a regra de frontmatter universal
- Épicos em `tasks/epics` mantiveram `status: Finished` original do Operon por regra de mesclagem sem sobrescrever, fora do enum draft stable deprecated
- `tasks/kanban.md` aparece no git como delete mais add em vez de rename, porque os links internos foram atualizados junto, conteúdo preservado
- `Requisitos.md` e `PSYCHOLOGY_PACKAGES.md` ficaram na raiz como documentos legado preservados, fora da árvore alvo, mapeados no índice
- Arquivos em `data-model` usam `type: spec`, por falta de tipo próprio no enum do `AGENTS.md`
- `tasks/kanban.md` usa `type: epic`, `tasks/leiame.md` usa `type: spec`
- Frontmatter de `tasks/kanban.md` mesclado sem quebrar a chave `kanban-plugin: board`
- Correção de transporte: o índice reescrito chegou ao disco com 85 barras invertidas antes de pipes em links com texto, mais 1 em tabela de `data-model`, tudo corrigido e zerado na verificação final. Recomendação: após qualquer escrita com pipe no conteúdo, rodar a busca por barra invertida mais pipe

## Critérios de aceite, checagem final

- Branch criada: sim
- Contagem não diminuiu, 67 foi para 93: sim
- Frontmatter com title type status updated em todo md do escopo: sim, ver exceções acima
- Existem `AGENTS.md`, `CONTEXT.md`, `glossary.md`, `CHANGELOG.md`: sim
- Existem `data-model`, `decisions`, `flows`, `integrations`, `runbooks`, `tasks`, `_templates`, `_audit`, `archive`: sim
- `Operon` não existe mais: sim, virou `tasks` mais `_tools`
- `Maps` não existe mais: sim, virou `flows`
- Nenhum wikilink de projeto quebrado: sim
- Este relatório existe e está preenchido: sim
- Nenhum conteúdo original deletado: sim, só movido
