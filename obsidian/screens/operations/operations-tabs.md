---
title: Operations Tabs
tags:
  - nexosaude
  - brain
  - screens
name: screen-operations-tabs
description: Abas de gestão — estoque, fornecedores, procedimentos, taxas de cartão e configurações (tema + acesso).
type: screen
status: stable
updated: 2026-09-30
---

# Operations Tabs

`lib/screens/operations/tabs/` — `inventory_tab`, `suppliers_tab`, `procedures_tab`, `card_fees_tab`, `settings_tab`

## O que é

- **Inventory**: `inventory_service` + `product_service` (alerta `getLowStockStream`).
- **Suppliers**: `supplier_service`; flag "dentista da equipe" (comissionado).
- **Procedures**: catálogo global `procedures` + tipo comissão (%/fixo) + custo/mensalidade.
- **CardFees**: `MachineProfile` + `InstallmentRangeRow`; perfis em `clinics/{id}/settings/fees/profiles`.
- **Settings**: `ThemeController` (claro/escuro por usuário em `user_prefs` + fallback do aparelho) + controle de acesso por item E por aba/seção (`menuAccess` + sub-chaves `g_*`; owner edita, owner ignora).

## Quando usar

Cadastro operacional, taxa nova, parcela de máquina, tema, acesso ao menu.

## Gotchas

- `Radio/Switch activeColor` e `groupValue` depreciados nas 4 tabs antigas — migrar ao tocar.
- Tema escuro: superfícies/textos de appbar migram p/ `AppColors`/tema; residuais intencionais: botões coloridos com texto branco, swatches da legenda do odonto, cards tintados (verde/laranja), chips de filtro.

## Atualizações

- Aba Configurações: card Pix da clínica (`pixKey`, flag `g_pix`) + "Minha conta" (troca de senha, todo holder de Gestão) + "Dados da clínica" (WhatsApp canônico E.164 p/ Evolution/n8n futuro, flag `g_clinica`). Ver [[screens/clinical/patient-details|patient-details]] (link do portal).
- Abas da Gestão filtradas por chave (`g_proc/g_estoque/g_forn/g_cart/g_config`, 1 leitura do mapa no abrir); seções Pix/Grade/Acesso/Dados por `g_pix/g_grade/g_acesso/g_clinica` (defaults: só owner). Rules `clinics` liberam `pixKey/gradeConfig/whatsappNumber` com a flag.
- Editor com grupo "Abas e seções da Gestão" (9 sub-chaves); efetivo usa `defaultFor` por papel.

## Ver também

- [[screens/operations/operations-manager|operations-manager]] — shell que filtra as abas
- [[operations]] — cadastros de apoio
- [[screens/operations/employee-manager|employee-manager]] — quem o editor habilita
