---
title: Clinic Lab
tags:
  - nexosaude
  - brain
  - screens
name: screen-clinic-lab
description: Gestão de pedidos de laboratório da clínica (protéticos).
---

# ClinicLabScreen

`lib/screens/lab/clinic_lab_screen.dart`

## O que é

Kanban/lista de `lab_orders` (`LabService`: `getByClinic`, `updateStatus`, `addInteraction`).

## Quando usar

Enviar caso ao laboratório, acompanhar estágio, interagir.

## Gotchas

- `debugPrint` em catch com objeto — interpolar (`"$e"`).
- Dropdowns com `value` depreciado → `initialValue`.

## Ver também

- [[clinical]] — pedidos e interações de laboratório
- [[patient-details]] — aba Lab por paciente
- [[patient-tabs]] — as abas da ficha
