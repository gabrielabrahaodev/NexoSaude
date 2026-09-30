---
title: 00 Index
tags:
  - nexosaude
  - brain
name: brain-index
description: Mapa do vault obsidian — um arquivo por módulo, tela, mapa ou documento do NexoSaúde.
---

# Obsidian — NexoSaúde

Conhecimento do projeto: cada arquivo cobre **um módulo** (`modules/`), **uma tela** (`screens/`), um **mapa** (`Maps/`), uma **spec** (`specs/`) ou um **documento** (raiz).

## Como usar

- Vai mexer numa tela? Leia `screens/<tela>.md` primeiro.
- Vai mexer numa regra de negócio? Leia `modules/<dominio>.md` primeiro.
- Arquivos citam paths reais, collections Firestore e gotchas; links entre notas conectam o grafo.

## Documentos

| Arquivo | Conteúdo |
|---|---|
| [[foundation/01-prd|PRD]] | Produto, histórias, riscos |
| [[Requisitos]] | RN por módulo com referências de código |
| [[foundation/02-use-cases|CASOS_DE_USO]] | Catálogo UC com atores |
| [[foundation/03-sequence-diagrams|DIAGRAMAS_DE_SEQUENCIA]] | Fluxos em sequência |
| [[PSYCHOLOGY_PACKAGES]] | Billing psico por presença |

## Specs

- [[spec-atendimento-portal]] — Modo Atendimento + Portal (decisão b).
- [[spec-landing-master]] — Landing + master + assinatura (trial e cobrança por usuário).

## Mapas

- [[flows/atendimento|atendimento]] — Modo Atendimento + portal + remarcação (fio condutor).

## Módulos (regras de negócio)

| Arquivo | Domínio |
|---|---|
| [[session-multitenant]] | Sessão, multi-tenant, auth, capabilities, menu access |
| [[agenda]] | Agendamentos, presença, atestado, bloqueios por intervalo |
| [[patients]] | Pacientes, risco, cascata, LGPD do portal |
| [[psychology-packages]] | Pacotes/sessões psico, billing por presença |
| [[financial]] | Financeiro, cobrança, despesas, pagamentos |
| [[clinical]] | Prontuário, tratamentos, orçamentos, lab |
| [[operations]] | Estoque, fornecedores, procedimentos, taxas |
| [[reports-oracle]] | Relatórios e oráculo financeiro |
| [[comms]] | WhatsApp, documentos, notícias |
| [[ui-theme]] | Tema e widgets compartilhados |
| [[ui-consistency]] | Helpers puros testados (moeda, data, toast, slots) |
| [[pix-brcode]] | Pix BR Code estático local |
| [[portal-mirror]] | Espelhos `portal/` + `portal_slots/` |

## Telas

[[screens/agenda/agenda-manager|agenda-manager]], [[screens/agenda/agenda-form|agenda-form]], [[screens/auth/auth-login-rolecheck|auth-login-rolecheck]], [[screens/agenda/care-day|care-day]],
[[screens/clinical/clinic-lab|clinic-lab]], [[screens/operations/clinic-management|clinic-management]], [[screens/financial/collections|collections]], [[screens/clinical/create-patient|create-patient]],
[[screens/operations/employee-manager|employee-manager]], [[screens/financial/expenses|expenses]], [[screens/financial/financial-report|financial-report]], [[screens/reports/kpi-dashboard|kpi-dashboard]],
[[screens/admin/landing-page|landing-page]], [[screens/admin/assinatura-page|assinatura-page]], [[screens/admin/master-screen|master-screen]], [[screens/reports/main-dashboard|main-dashboard]],
[[screens/operations/operations-manager|operations-manager]], [[screens/operations/operations-tabs|operations-tabs]], [[screens/clinical/ortho-news|ortho-news]], [[screens/clinical/patient-list|patient-list]],
[[screens/clinical/patient-details|patient-details]], [[screens/clinical/patient-tabs|patient-tabs]], [[screens/portal/portal-page|portal-page]], [[screens/clinical/psychology-kanban|psychology-kanban]],
[[screens/clinical/psychology-schedule|psychology-schedule]], [[screens/portal/public-evaluation|public-evaluation]], [[screens/clinical/budget-wizard|budget-wizard]],
[[screens/agenda/remarcar-dialog|remarcar-dialog]], [[screens/reports/reports|reports]].

## Gestão (Operon)

- Backlog e board: [[tasks/epics/sprint-backlog|Sprint - Backlog]] (como montar em [[tasks/leiame|LEIAME Kanban]])
- Sprints de velocidade: [[tasks/epics/S1-economia-cliques|S1 - Economia de cliques]], [[tasks/epics/S2-tempo-janelas|S2 - Tempo entre janelas]], [[tasks/epics/S3-qualidade-atendimento|S3 - Qualidade do atendimento]]
- Épicos entregues: [[tasks/epics/E1-plataforma-assinatura|E1 - Plataforma e Assinatura]], [[tasks/epics/E2-portal-lgpd|E2 - Portal e LGPD]], [[tasks/epics/E3-atendimento-agenda|E3 - Atendimento e Agenda]], [[tasks/epics/E4-acesso-multiclinica|E4 - Acesso e Multiclínica]], [[tasks/epics/E5-cota-dados|E5 - Cota e Dados]], [[tasks/epics/E6-docs-vault|E6 - Docs e Vault]], [[tasks/epics/E7-avaliacoes-tecnicas|E7 - Avaliações Técnicas]]

## Convenções globais (valem para tudo)

- Toda query operacional filtra por `clinicId` via `SessionManager().applyFilter()`.
- `ClinicCapabilities` centraliza decisões por `clinicType` (`dental` | `psychology`).
- Visibilidade de menu/telas/abas: `MenuAccess` (`menuAccess` por usuário + defaults por papel) — sem `if (role)` hardcoded no menu.
- Models usam `fromMap` defensivo; nunca confie no formato do Firestore.
- Status financeiro: `pending`/`pendente`, `paid`, `anticipated`, `cobrado`.
- Status atendimento: `Aguardando Confirmação`, `Finalizado`, `Cancelado`; presença em `attendanceStatus` (`Attended` | `Missed`) + `hasMedicalCertificate`.
- Plano Spark: sem Functions — tudo é clique no app, escrita pública com allowlist ou script `migrate/` com Admin SDK.
