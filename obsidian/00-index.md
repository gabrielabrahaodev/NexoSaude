---
title: 00 Index
tags:
  - nexosaude
  - brain
name: brain-index
description: Mapa do vault obsidian — um arquivo por módulo, tela, fluxo, decisão, integração ou documento do NexoSaúde.
type: spec
status: stable
updated: 2026-09-30
---

# Obsidian — NexoSaúde

Conhecimento do projeto: cada arquivo cobre **um módulo** (`modules/`), **uma tela** (`screens/<domínio>/`), um **fluxo** (`flows/`), uma **decisão** (`decisions/`), uma **integração** (`integrations/`), um **runbook** (`runbooks/`).

## Comece aqui

- [[AGENTS]] — guia de navegação para agentes de IA (fonte de verdade, convenções).
- [[CONTEXT]] — o NexoSaúde em 1 página.
- [[glossary]] — termos do domínio em 1 linha cada.
- [[CHANGELOG]] — histórico do vault.

## Foundation (intenção do produto)

| Arquivo | Conteúdo |
|---|---|
| [[foundation/01-prd|01-prd]] | Produto, histórias, riscos |
| [[foundation/02-use-cases|02-use-cases]] | Catálogo UC com atores |
| [[foundation/03-sequence-diagrams|03-sequence-diagrams]] | Fluxos em sequência |
| [[foundation/04-requisitos|04-requisitos]] | RN por módulo com referências de código |

## Módulos (como funciona hoje)

| Arquivo | Domínio |
|---|---|
| [[modules/session-multitenant|session-multitenant]] | Sessão, multi-tenant, auth, capabilities, menu access |
| [[modules/agenda|agenda]] | Agendamentos, presença, atestado, bloqueios por intervalo |
| [[modules/patients|patients]] | Pacientes, risco, cascata, LGPD do portal |
| [[modules/psychology-packages|psychology-packages]] | Pacotes/sessões psico, billing por presença |
| [[modules/financial|financial]] | Financeiro, cobrança, despesas, pagamentos |
| [[modules/clinical|clinical]] | Prontuário, tratamentos, orçamentos, lab |
| [[modules/operations|operations]] | Estoque, fornecedores, procedimentos, taxas |
| [[modules/reports-oracle|reports-oracle]] | Relatórios e oráculo financeiro |
| [[modules/comms|comms]] | WhatsApp, documentos, notícias |
| [[modules/ui-theme|ui-theme]] | Tema e widgets compartilhados |
| [[modules/ui-consistency|ui-consistency]] | Helpers puros testados (moeda, data, toast, slots) |
| [[modules/pix-brcode|pix-brcode]] | Redirecionamento → [[integrations/pix-brcode|pix-brcode]] |
| [[modules/portal-mirror|portal-mirror]] | Espelhos `portal/` + `portal_slots/` |
| [[modules/psychology-packages-billing|psychology-packages-billing]] | Detalhe do billing mensal por presença (implementado) |

## Telas (por domínio)

**auth/**: [[screens/auth/auth-login-rolecheck|auth-login-rolecheck]].

**agenda/**: [[screens/agenda/agenda-manager|agenda-manager]], [[screens/agenda/agenda-form|agenda-form]], [[screens/agenda/care-day|care-day]], [[screens/agenda/remarcar-dialog|remarcar-dialog]].

**clinical/**: [[screens/clinical/patient-list|patient-list]], [[screens/clinical/patient-details|patient-details]], [[screens/clinical/patient-tabs|patient-tabs]], [[screens/clinical/create-patient|create-patient]], [[screens/clinical/budget-wizard|budget-wizard]], [[screens/clinical/clinic-lab|clinic-lab]], [[screens/clinical/psychology-kanban|psychology-kanban]], [[screens/clinical/psychology-schedule|psychology-schedule]], [[screens/clinical/ortho-news|ortho-news]].

**financial/**: [[screens/financial/collections|collections]], [[screens/financial/expenses|expenses]], [[screens/financial/financial-report|financial-report]].

**operations/**: [[screens/operations/operations-manager|operations-manager]], [[screens/operations/operations-tabs|operations-tabs]], [[screens/operations/employee-manager|employee-manager]], [[screens/operations/clinic-management|clinic-management]].

**portal/**: [[screens/portal/portal-page|portal-page]], [[screens/portal/public-evaluation|public-evaluation]].

**admin/**: [[screens/admin/landing-page|landing-page]], [[screens/admin/master-screen|master-screen]], [[screens/admin/assinatura-page|assinatura-page]].

**reports/**: [[screens/reports/reports|reports]], [[screens/reports/kpi-dashboard|kpi-dashboard]], [[screens/reports/main-dashboard|main-dashboard]].

## Fluxos

- [[flows/atendimento|atendimento]] — Modo Atendimento + portal + remarcação (fio condutor).

## Data-model

- [[data-model/collections|collections]] — coleções Firestore.
- [[data-model/indexes|indexes]] — índices compostos.
- [[data-model/security-rules|security-rules]] — resumo das rules (+ TODO importar `firestore.rules`).
- [[data-model/mirrors|mirrors]] — `portal/{token}` + `portal_slots`.

## Decisões (ADRs)

- [[decisions/0001-firestore-mirror|0001-firestore-mirror]] — espelhos para leitura barata no Spark.
- [[decisions/0002-multitenant-session|0002-multitenant-session]] — `SessionManager` + `allowedClinics` + `applyFilter`.
- [[decisions/0003-sem-cloud-functions|0003-sem-cloud-functions]] — plano Spark, sem backend.

## Integrações

- [[integrations/whatsapp|whatsapp]], [[integrations/cloudinary|cloudinary]], [[integrations/pix-brcode|pix-brcode]], [[integrations/europe-pmc|europe-pmc]].

## Runbooks

- [[runbooks/deploy|deploy]] (fragmentos + TODOs), [[runbooks/migracao-dados|migracao-dados]] (fragmentos + TODOs).

## Specs

- [[specs/2026-09-19-modo-atendimento-portal-design|spec atendimento-portal]] — Modo Atendimento + Portal (decisão b).
- [[specs/2026-09-19-landing-master-assinatura-design|spec landing-master]] — Landing + master + assinatura (trial e cobrança por usuário).

## Tasks

- Board e guia: [[tasks/kanban|kanban]] (como montar em [[tasks/leiame|leiame]]).
- Backlog: [[tasks/epics/sprint-backlog|sprint-backlog]].
- Sprints de velocidade: [[tasks/epics/S1-economia-cliques|S1-economia-cliques]], [[tasks/epics/S2-tempo-janelas|S2-tempo-janelas]], [[tasks/epics/S3-qualidade-atendimento|S3-qualidade-atendimento]].
- Épicos entregues: [[tasks/epics/E1-plataforma-assinatura|E1-plataforma-assinatura]], [[tasks/epics/E2-portal-lgpd|E2-portal-lgpd]], [[tasks/epics/E3-atendimento-agenda|E3-atendimento-agenda]], [[tasks/epics/E4-acesso-multiclinica|E4-acesso-multiclinica]], [[tasks/epics/E5-cota-dados|E5-cota-dados]], [[tasks/epics/E6-docs-vault|E6-docs-vault]], [[tasks/epics/E7-avaliacoes-tecnicas|E7-avaliacoes-tecnicas]].

## Documentos realocados da raiz (2026-09-30)

- [[foundation/04-requisitos|Requisitos]] — RN por módulo com referências de código.
- [[modules/psychology-packages-billing|PSYCHOLOGY_PACKAGES]] — billing psico por presença.

## Templates e ferramentas

- Templates: [[_templates/module|module]], [[_templates/screen|screen]], [[_templates/spec|spec]], [[_templates/adr|adr]], [[_templates/flow|flow]] (atalhos em [[modules/_module-template|_module-template]] e [[specs/_spec-template|_spec-template]]).
- Ferramenta: [[_tools/operon|operon]] (doc do plugin, não é conteúdo do projeto).
- Auditoria: [[_audit/empty-files|empty-files]], [[_audit/reorg-report|reorg-report]].

## Convenções globais (valem para tudo)

- Toda query operacional filtra por `clinicId` via `SessionManager().applyFilter()`.
- `ClinicCapabilities` centraliza decisões por `clinicType` (`dental` | `psychology`).
- Visibilidade de menu/telas/abas: `MenuAccess` (`menuAccess` por usuário + defaults por papel) — sem `if (role)` hardcoded no menu.
- Models usam `fromMap` defensivo; nunca confie no formato do Firestore.
- Status financeiro: `pending`/`pendente`, `paid`, `anticipated`, `cobrado`.
- Status atendimento: `Aguardando Confirmação`, `Finalizado`, `Cancelado`; presença em `attendanceStatus` (`Attended` | `Missed`) + `hasMedicalCertificate`.
- Plano Spark: sem Functions — tudo é clique no app, escrita pública com allowlist ou script `migrate/` com Admin SDK.
