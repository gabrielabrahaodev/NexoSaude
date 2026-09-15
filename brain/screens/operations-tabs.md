---
name: screen-operations-tabs
description: Abas de gestão — estoque, fornecedores, procedimentos e taxas de cartão.
---

# Operations Tabs

`lib/screens/operations/tabs/` — `inventory_tab`, `suppliers_tab`, `procedures_tab`, `card_fees_tab`

## O que é

- **Inventory**: `inventory_service` + `product_service` (alerta `getLowStockStream`).
- **Suppliers**: `supplier_service`; flag "dentista da equipe" (comissionado).
- **Procedures**: catálogo global `procedures` + tipo comissão (%/fixo) + custo/mensalidade.
- **CardFees**: `MachineProfile` + `InstallmentRangeRow`; perfis em `clinics/{id}/settings/fees/profiles`.

## Quando usar

Cadastro operacional, taxa nova, parcela de máquina.

## Gotchas

- `Radio/Switch activeColor` e `groupValue` depreciados nas 4 tabs — migrar ao tocar.
- `_createNewProfile` morto no card_fees.
