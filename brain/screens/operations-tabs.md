---
name: screen-operations-tabs
description: Abas de gestão — estoque, fornecedores, procedimentos, taxas de cartão e configurações (tema + acesso).
---

# Operations Tabs

`lib/screens/operations/tabs/` — `inventory_tab`, `suppliers_tab`, `procedures_tab`, `card_fees_tab`, `settings_tab`

## O que é

- **Inventory**: `inventory_service` + `product_service` (alerta `getLowStockStream`).
- **Suppliers**: `supplier_service`; flag "dentista da equipe" (comissionado).
- **Procedures**: catálogo global `procedures` + tipo comissão (%/fixo) + custo/mensalidade.
- **CardFees**: `MachineProfile` + `InstallmentRangeRow`; perfis em `clinics/{id}/settings/fees/profiles`.
- **Settings**: `ThemeController` (claro/escuro por usuário em `user_prefs` + fallback do aparelho) + controle de acesso (`UserService.watchClinicUsers/updateMenuAccess`, campo `menuAccess`; owner edita, owner ignora).

## Quando usar

Cadastro operacional, taxa nova, parcela de máquina, tema, acesso ao menu.

## Gotchas

- `Radio/Switch activeColor` e `groupValue` depreciados nas 4 tabs antigas — migrar ao tocar.
- Tema escuro: superfícies/textos de appbar migram p/ `AppColors`/tema; residuais intencionais: botões coloridos com texto branco, swatches da legenda do odonto, cards tintados (verde/laranja), chips de filtro.
