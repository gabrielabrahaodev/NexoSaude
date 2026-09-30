---
name: screen-portal-page
description: portal.html público (sessões, atrasos, Pix, remarcação).
title: Página do Portal (portal.html)
tags:
  - nexosaude
  - brain
  - screens
  - portal
---

# Página do Portal (portal.html)

`web/portal.html` → deploy em `/sistema-interno/portal.html?t=TOKEN`

## O que é

HTML estático + Firebase compat (sem build): sessões com pílulas de status, painel dias/horários do profissional, atrasos com toggle Pix, "Avisei que paguei" por débito.

## Quando usar

Link do paciente (c recentemente gerado na aba Cadastro). Condicão de botões por conceito (`podeConfirmar`), não string exata.

## Fluxos

- Confirmar → `appointments` (`Confirmado`) + `statusSessao` em mapa por sessão.
- Remarcar → `remarcar` + data/token + pedido no espelho → [[remarcar-dialog]] interno.
- Defesa local: filtra atrasos e ordena mesmo com espelho antigo.

## Gotchas

> [!warning]
> `statusSessao` em mapa — objeto único fazia confirmações se alternarem. Sync com merge preserva campos do portal.

Ver [[portal-mirror]], [[flows/atendimento|atendimento]].
