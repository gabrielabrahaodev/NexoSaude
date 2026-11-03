---
title: Patients
tags:
  - nexosaude
  - brain
  - modules
name: patients-module
description: Cadastro de pacientes, perfil de risco por assiduidade e exclusão em cascata.
---

# Pacientes

## O que é

CRUD de `patients` + risco (taxa de faltas) + exclusão em cascata de todos os dados do paciente.

## Quando usar

Busca/cadastro de paciente, `Hero` de avatar, exclusão, assiduidade.

## Arquivos-chave

- `lib/services/patient_service.dart` — `getAllStream`, `getByIdStream`, `getPatientRiskProfile`, `deletePatientCascade`
- `lib/models/patient_model.dart` — parsing defensivo (`parseAddress`, `parseBirthDate`: String ou Map/Timestamp)

## Fluxos

- Risco: últimos 20 `appointments`; `Missed` conta, **`Missed` com atestado não conta**; `Cancelado` pelo paciente conta. Níveis: red (≥30% ou ≥3), yellow (≥10%), green.
- Cascata (`_cascadeCollections`): appointments, budgets, treatments, treatment_plans, financial, clinical_records, lab_orders, psychology_schedules + `patients/{id}/clinical_data`, `patients/{id}/docs`, `anamnesis/{patientId}`, espelho de portal e paciente. São **lotes sequenciais de até 450 operações**, não uma única transação para toda a exclusão. Antes do primeiro lote, há preflight de metadata remota; presença de arquivo remoto exige limpeza administrativa/autenticada antes de prosseguir. `purgePatientFiles` não equivale a `destroy` Cloudinary automático.

## Regras / Gotchas

- O limite de 500 writes por batch motiva blocos de 450; falha após um bloco bem-sucedido pode deixar exclusão parcial. Registrar backup, relatório e reconciliação antes de tentar em dados reais.
- `Hero tag` usa `avatar_$docId` (nunca nome — nomes repetem e quebram a animação).
- Busca filtra nome/CPF/telefone localmente após o stream por `clinicId`.

## Ver também

- [[patient-list]] — lista + busca + exclusão
- [[patient-details]] — ficha completa
- [[create-patient]] — cadastro com aceite LGPD
- [[patient-tabs]] — as abas da ficha

## Nota da auditoria — 03/11/2026

Na branch `feat/agenda-clinical-dark`, o preflight de exclusão do paciente verifica metadata de Cloudinary legado **e** de arquivos R2. A remoção de metadata sem remoção prévia do binário é bloqueada pelo fluxo de documentos. A cascata de clínica também preserva vínculos de profissionais de outras unidades, mas só deverá ser usada depois de verificar estado de trial/permissões e arquivo remoto. **Não foi testada uma exclusão real nesta revisão.** Ver [[auditoria-codigo-2026-11-03]], [[comms]], [[clinic-management]].
