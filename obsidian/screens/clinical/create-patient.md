---
title: Create Patient
tags:
  - nexosaude
  - brain
  - screens
name: screen-create-patient
description: Cadastro de paciente com clinicId da sessão.
---

# CreatePatientScreen

`lib/screens/patients/create_patient_screen.dart`

## O que é

Formulário que grava em `patients` já com o `clinicId` atual.
Psico exibe dropdown de Status Terapêutico (default Prospecto); dental grava `status='Ativo'` sem campo.

## Quando usar

Novo paciente, campos obrigatórios, duplicidade de CPF.

## Gotchas

- CPF duplicado bloqueia o cadastro na clínica atual (CPF vazio não conta).

## Atualizações

- Cadastro gera `portalToken` + espelho inicial imediato (link vale desde o cadastro). Ver [[portal-mirror]].
- Checkbox "Autorização LGPD — portal/WhatsApp" (default desmarcado): sem aceite, sem token; gerar depois registra aceite com diálogo + `via/by`. Cadastro rápido tem o mesmo checkbox.

## Ver também

- [[screens/clinical/patient-list|patient-list]] — lista para onde o cadastro volta
- [[patients]] — risco, cascata e busca
- [[portal-mirror]] — espelho que nasce do aceite
