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

- [[atendimento]] — Modo Atendimento + portal + remarcação (fio condutor).

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

[[agenda-manager]], [[agenda-form]], [[auth-login-rolecheck]], [[care-day]],
[[clinic-lab]], [[clinic-management]], [[collections]], [[create-patient]],
[[employee-manager]], [[expenses]], [[financial-report]], [[kpi-dashboard]],
[[landing-page]], [[assinatura-page]], [[master-screen]], [[main-dashboard]],
[[operations-manager]], [[operations-tabs]], [[ortho-news]], [[patient-list]],
[[patient-details]], [[patient-tabs]], [[portal-page]], [[psychology-kanban]],
[[psychology-schedule]], [[public-evaluation]], [[budget-wizard]],
[[remarcar-dialog]], [[reports]].

## Gestão (Operon)

- Backlog e board: [[Sprint - Backlog]] (como montar em [[LEIAME Kanban]])
- Sprints de velocidade: [[S1 - Economia de cliques]], [[S2 - Tempo entre janelas]], [[S3 - Qualidade do atendimento]]
- Épicos entregues: [[E1 - Plataforma e Assinatura]], [[E2 - Portal e LGPD]], [[E3 - Atendimento e Agenda]], [[E4 - Acesso e Multiclínica]], [[E5 - Cota e Dados]], [[E6 - Docs e Vault]], [[E7 - Avaliações Técnicas]]

## Convenções globais (valem para tudo)

- Toda query operacional filtra por `clinicId` via `SessionManager().applyFilter()`.
- `ClinicCapabilities` centraliza decisões por `clinicType` (`dental` | `psychology`).
- Visibilidade de menu/telas/abas: `MenuAccess` (`menuAccess` por usuário + defaults por papel) — sem `if (role)` hardcoded no menu.
- Models usam `fromMap` defensivo; nunca confie no formato do Firestore.
- Status financeiro: `pending`/`pendente`, `paid`, `anticipated`, `cobrado`.
- Status atendimento: `Aguardando Confirmação`, `Finalizado`, `Cancelado`; presença em `attendanceStatus` (`Attended` | `Missed`) + `hasMedicalCertificate`.
- Plano Spark: sem Functions — tudo é clique no app, escrita pública com allowlist ou script `migrate/` com Admin SDK.
