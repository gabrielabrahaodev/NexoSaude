---
title: Operations
tags:
  - nexosaude
  - brain
  - modules
name: operations-module
description: Gestão operacional — estoque, fornecedores, catálogo de procedimentos e taxas de cartão/máquina.
type: module
status: stable
updated: 2026-09-30
---

# Operações / Gestão

## O que é

Cadastros de apoio: produtos/estoque, fornecedores (inclui dentista comissionado),
catálogo global `procedures` e perfis de taxas em `clinics/{id}/settings/fees/profiles`.

## Quando usar

Estoque baixo, fornecedor, procedimento, antecipação de cartão.

## Arquivos-chave

- `lib/services/inventory_service.dart` (`adjustQuantity`), `product_service.dart` (`getLowStockStream`), `supplier_service.dart`, `procedure_service.dart`
- Tabs: `inventory_tab`, `suppliers_tab`, `procedures_tab`, `card_fees_tab` (`MachineProfile`, `InstallmentRangeRow`)
- `lib/screens/employees/employee_manager_screen.dart` (cria `users` + `allowedClinics`), `clinic_management_screen.dart` (cria `clinics`)

## Fluxos

- Taxa/antecipação: perfis por clínica em `settings/fees/profiles`; `patient_financial_tab` lê o perfil para calcular líquido.
- Funcionário novo: Auth + doc `users` com role e `allowedClinics`.

## Regras / Gotchas

- `procedures` é catálogo **global** (sem `clinicId`); resto filtra por clínica.
- `SwitchListTile activeColor` e `Radio groupValue` depreciados no Flutter atual — migrar para `activeThumbColor`/`RadioGroup` ao tocar.

## Ver também

- [[screens/operations/operations-manager|operations-manager]] — shell com as abas
- [[screens/operations/operations-tabs|operations-tabs]] — as 5 abas (inclui Config)
- [[screens/operations/employee-manager|employee-manager]] — cria `users` + vínculo `allowedClinics`
