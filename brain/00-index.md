---
name: brain-index
description: Mapa da pasta brain — um arquivo MD por módulo ou tela do OdontoControle, em formato de skill.
---

# Brain — OdontoControle

Conhecimento do projeto em formato de skills: cada arquivo cobre **um módulo** (`modules/`) ou **uma tela** (`screens/`).

## Como usar

- Vai mexer numa tela? Leia `screens/<tela>.md` primeiro.
- Vai mexer numa regra de negócio? Leia `modules/<dominio>.md` primeiro.
- Arquivos citam paths reais, collections Firestore e gotchas.

## Módulos (regras de negócio)

| Arquivo | Domínio |
|---|---|
| `modules/session-multitenant.md` | Sessão, multi-tenant, auth, capabilities |
| `modules/agenda.md` | Agendamentos, presença, atestado |
| `modules/patients.md` | Pacientes, risco, cascata |
| `modules/psychology-packages.md` | Pacotes/sessões psico, billing por presença |
| `modules/financial.md` | Financeiro, cobrança, despesas, pagamentos |
| `modules/clinical.md` | Prontuário, tratamentos, orçamentos, lab |
| `modules/operations.md` | Estoque, fornecedores, procedimentos, taxas |
| `modules/reports-oracle.md` | Relatórios e oráculo financeiro |
| `modules/comms.md` | WhatsApp, documentos, notícias |
| `modules/ui-theme.md` | Tema e widgets compartilhados |

## Telas

`agenda-manager`, `agenda-form`, `auth-login-rolecheck`, `clinic-management`,
`employee-manager`, `main-dashboard`, `public-evaluation`,
`collections`, `expenses`, `financial-report`, `clinic-lab`, `ortho-news`,
`operations-manager`, `operations-tabs`, `patient-list`, `patient-details`,
`create-patient`, `patient-tabs`, `psychology-kanban`, `budget-wizard`,
`psychology-schedule`, `reports`.

## Convenções globais (valem para tudo)

- Toda query operacional filtra por `clinicId` via `SessionManager().applyFilter()`.
- `ClinicCapabilities` centraliza decisões por `clinicType` (`dental` | `psychology`).
- Models usam `fromMap` defensivo; nunca confie no formato do Firestore.
- Status financeiro: `pending`/`pendente`, `paid`, `anticipated`, `cobrado`.
- Status atendimento: `Aguardando Confirmação`, `Finalizado`, `Cancelado`; presença em `attendanceStatus` (`Attended` | `Missed`) + `hasMedicalCertificate`.
