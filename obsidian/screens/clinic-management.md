---
title: Clinic Management
tags:
  - nexosaude
  - brain
  - screens
name: screen-clinic-management
description: CRUD de clínicas (owner) com vínculo de ownerId e nome.
---

# ClinicManagementScreen

`lib/screens/clinics/clinic_management_screen.dart`

## O que é

Lista clínicas próprias ou vinculadas; as queries precisam provar escopo nas Rules. A UI oferece apenas tipos implementados: `dental` e `psychology`. Novas unidades exigem owner ativo e herdam exatamente o `trialEndsAt` de uma unidade própria ativa.

## Quando usar

Nova clínica, renomear, trocar tipo dental/psicologia.

## Fluxos

- Criar: valida unidade fonte, grava `trialEndsAt` herdado + `blockedByAdmin:false`, depois atualiza vínculo e cria a projeção em `public_clinics/{id}`.
- Primeira clínica: volta ao dashboard para sair do modo setup (só Clínicas).
- `DropdownButtonFormField value` depreciado → `initialValue` ao tocar.
- **Gerenciar troca de verdade**: `setClinic` + rebuild do dashboard na unidade (antes era só toast).
- Excluir (owner, ícone vermelho no card): contagem + digitar o nome + cascata `ClinicDeleteService` (13 coleções com `clinicId`, anamnese/subs/docs dos pacientes, settings, slots, doc; staff só `arrayRemove`, nunca apaga usuário); apaga a atual → `clearClinic()`.

## Gotchas

- Trocar `type` da clínica muda menu, tabs e filtro de profissionais imediatamente (via `SessionManager`).
- Item liberável via `menuAccess` (default: só owner); não-owner vê só as liberadas e não cria unidade.

## Ver também

- [[main-dashboard]] — seletor que troca sem sair da tela
- [[session-multitenant]] — `setClinic` + isolamento
- [[employee-manager]] — quem pode entrar em cada unidade

- Excluir: a cascata inclui leads e projeção pública. Em clínica expirada/bloqueada, a exclusão completa pode falhar porque as Rules bloqueiam leitura/operações dessa clínica; necessário fluxo administrativo/servidor.
