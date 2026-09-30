---
title: NexoSaúde em 1 página
type: spec
status: stable
updated: 2026-09-30
tags:
  - nexosaude
  - contexto
---

# CONTEXT.md — NexoSaúde em 1 página

## O que é

O **NexoSaúde** (Controle de Clínicas) é um web app único (Flutter Web + Firebase) que une agenda semanal/mensal, prontuário, cobrança Pix/cartão, confirmação via WhatsApp, Modo Atendimento para o profissional e Portal público do paciente (confirma/remarca, vê atrasos, avisa pagamento).
Serve clínicas de **odontologia e psicologia** que hoje operam agenda, prontuário, cobrança e confirmações em ferramentas desconectadas, com alta inadimplência, no-show e retrabalho da recepção.

## Público-alvo

- **Owner (Dra.)**: dona de 1+ clínicas, decide financeiro e acessos.
- **Recepcionista**: agenda, confirma, cobra no balcão; volume alto.
- **Dentista / Psicólogo**: atende, registra evolução, recebe.
- **Paciente-portal**: só tem o link; confirma/remarca, vê atrasos, paga Pix.
- **Superadmin (dono da plataforma)**: gerencia owners, trials e débitos (Master).

## Stack

- **Flutter Web** (release em `/sistema-interno/`, páginas públicas `anamnese.html`, `confirmar.html`, `portal.html` na raiz do hosting) + **Firebase** (Auth, Firestore, Hosting).
- **Plano Spark (sem Cloud Functions)**: toda automação é clique no app, escrita pública com allowlist ou script `migrate/` com Admin SDK.
- Fluxos: telas → services (`AppointmentService`, `FinancialService`, `ClinicalRecordService`, `PortalMirrorSync`, `RemarcacaoService`, `MonthAgendaCache`) → Firestore.
- Projeto Firebase: **`nexosaude`** (`https://nexosaude.web.app/sistema-interno/`).

## Detalhes

Ver [[foundation/01-prd]] para PRD completo (personas, user stories US-01..US-12, arquitetura, riscos e roadmap até v1.4).

## TODOs

- TODO: confirmar baseline de no-show e tempo por confirmação (success criteria do PRD citam medição antes do dia 0).
