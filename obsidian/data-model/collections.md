---
title: Coleções Firestore
type: spec
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - data-model
  - firestore
---

# Coleções Firestore

Agregado das coleções mencionadas em `modules/`. Fonte: [[modules/financial]], [[modules/portal-mirror]], [[modules/clinical]], [[modules/agenda]], `foundation/01-prd.md` §4 (Integration Points), `Requisitos.md` RN-58.

## Operacionais (toda query filtra por `clinicId` via `SessionManager().applyFilter()`)

| Coleção | Conteúdo | Fonte |
|---|---|---|
| `appointments` | Agendamentos (`clinicId`, `patientId`, `dentistId`, `status`, `attendanceStatus`, `hasMedicalCertificate`, `scheduleId/planId`, `monthlyPeriod`, `durationMinutes`) | [[modules/agenda]] |
| `patients` | Cadastro (`clinicId`, endereço/birthDate com parsing defensivo) | [[modules/patients]] |
| `financial` | Receitas (`clinicId`, `billingKind: package_monthly ou session`, `monthlyPeriod`, `planId`) | [[modules/financial]] |
| `expenses` | Despesas (`clinicId`, recorrentes, taxa de antecipação) | [[modules/financial]] |
| `clinical_records` | Evolução clínica | [[modules/clinical]] |
| `treatments` / `treatment_plans` | Planos (`procedures[]`) e tratamentos | [[modules/clinical]] |
| `budgets` | Orçamentos (`items[]`, `status`) | [[modules/clinical]] |
| `lab_orders` | Pedidos de laboratório (bloco próprio escopado por `clinicId`) | [[modules/clinical]] |
| `psychology_schedules` | Contratos recorrentes (`package` vs `session`) | [[modules/psychology-packages]] |
| `patients/{id}/docs` | Metadados de arquivos (binário no Cloudinary) | [[integrations/cloudinary]] |
| `patients/{id}/clinical_data/odontogram` | `teeth` + `lastUpdate` | [[modules/clinical]] |
| `anticipations` | Sem leitores/escritores no app; blocos removidos das rules, acesso negado por padrão | firestore.rules:261-268 |
| `suppliers` / `inventory` | Fornecedores e estoque (leitores legados sem filtro) | [[modules/operations]] |

## Globais / plataforma (sem `clinicId`)

| Coleção | Conteúdo |
|---|---|
| `procedures` | Catálogo global de procedimentos |
| `news` | Notícias de ortodontia (cache) |
| `clinics` | Metadados (`name`, `type`, `ownerId`) |
| `users` | `role`, `allowedClinics`, `menuAccess` |
| `clinics/{id}/settings/fees` | Perfis de taxas de máquina + `anticipation_rate` |
| `platform_debits` | Débitos da plataforma por owner (Master) |
| `password_reset_requests` | Pedidos de reset (create público, resto owner) |
| `trial_requests` | Autoprovisionamento aprovado via Master |
| `platform_config` | Assinatura da plataforma (basePrice, extraPrice, pixKey), só superadmin escreve | firestore.rules:128-133 |
| `user_prefs` | Preferências por usuário (ex. tema), próprio ou owner | firestore.rules:84-88 |

## Espelhos públicos

| Coleção | Conteúdo |
|---|---|
| `portal/{token}` | Espelho por paciente (3 sessões + top-3 atrasos + totais + Pix) |
| `portal_slots/{clinicId}` | Livres 14 dias por dentista |
| `clinics/{id}/leads` | Leads da avaliação pública; DIVERGÊNCIA: sem regra dedicada nas rules, cai no deny padrão | lib/screens/public/public_evaluation_screen.dart |
| `anamnesis/{patientId}` | Escrita pública com allowlist de 14 campos |

Ver [[data-model/mirrors]] e [[data-model/security-rules]].

## TODOs

- Verificado contra o código em 2026-09-30: coleções com uso em lib (via collection) e matches em firestore.rules conferem com as tabelas acima, com os ajustes desta revisão (anticipations, platform_config, user_prefs, leads). Grupos de firestore.indexes.json: appointments, financial, treatment_plans, expenses, lab_orders, patients, budgets, users, inventory, docs, clinical_records, clinics, suppliers, procedures.
<!-- fonte: firestore.rules:50-291; firestore.indexes.json; grep collection( em lib -->
