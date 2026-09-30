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
| `financial` | Receitas (`clinicId`, `billingKind: package_monthly\|session`, `monthlyPeriod`, `planId`) | [[modules/financial]] |
| `expenses` | Despesas (`clinicId`, recorrentes, taxa de antecipação) | [[modules/financial]] |
| `clinical_records` | Evolução clínica | [[modules/clinical]] |
| `treatments` / `treatment_plans` | Planos (`procedures[]`) e tratamentos | [[modules/clinical]] |
| `budgets` | Orçamentos (`items[]`, `status`) | [[modules/clinical]] |
| `lab_orders` | Pedidos de laboratório (bloco próprio escopado por `clinicId`) | [[modules/clinical]] |
| `psychology_schedules` | Contratos recorrentes (`package` vs `session`) | [[modules/psychology-packages]] |
| `patients/{id}/docs` | Metadados de arquivos (binário no Cloudinary) | [[integrations/cloudinary]] |
| `patients/{id}/clinical_data/odontogram` | `teeth` + `lastUpdate` | [[modules/clinical]] |
| `anticipations` | Histórico de antecipações de recebíveis | `Requisitos.md` RN |
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

## Espelhos públicos

| Coleção | Conteúdo |
|---|---|
| `portal/{token}` | Espelho por paciente (3 sessões + top-3 atrasos + totais + Pix) |
| `portal_slots/{clinicId}` | Livres 14 dias por dentista |
| `anamnesis/{patientId}` | Escrita pública com allowlist de 14 campos |

Ver [[data-model/mirrors]] e [[data-model/security-rules]].

## TODOs

- TODO: conferir lista contra `firestore.rules` e `firestore.indexes.json` (fonte final no código, não no vault).
