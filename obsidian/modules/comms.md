---
title: Comms
tags:
  - nexosaude
  - brain
  - modules
name: comms-module
description: Comunicação e conteúdo — WhatsApp, upload de documentos (Cloudinary) e notícias de ortodontia.
---

# Comunicação / Conteúdo

## O que é

Abertura de WhatsApp com mensagem, upload de arquivos do paciente e feed de notícias.

## Quando usar

Cobrança, documentação do paciente, feed de notícias.

## Arquivos-chave

- `lib/services/whatsapp_helper.dart` — `getMessage` (rotativa), `openWhatsApp`
- `lib/utils/external_link.dart` — `openBlankTab` + `openWhatsAppSafe`/`openLinkSafe`: aba em branco no gesto p/ o bloqueador de pop-up não matar (usar em TODO abrir externo após `await`)
- `lib/services/document_service.dart` — `uploadFile` (retorna url+`publicId`), `saveMetadata`, `getDocs`, `deleteDocument` (só Firestore no Spark), `purgePatientFiles` (só log, após commit)
- `lib/services/news_service.dart` — `getLatestOrthoNews(clinicType)` (Europe PMC + Semantic Scholar por tema, traduzido, cache 60min)

## Fluxos

- Cobrança usa `didChangeAppLifecycleState` (resumed + `_currentProcessingId`) para pedir confirmação ao voltar do WhatsApp.
- Docs: upload → URL segura → metadata no Firestore → lista por categoria.

## Regras / Gotchas

- `openWhatsApp` pode falhar (sem app) — sempre tratar `success == false` com SnackBar.
- `cloudName`/`uploadPreset` hardcoded (`dbbh601ay`); preset precisa ser **unsigned** no painel Cloudinary. `validateUpload` (testado) barra tipo/vazio/+10MB antes de enviar; travar também no painel (pasta, tipos, tamanho).
- Cache de notícias é em memória — restart limpa; `formats` não usado (limpeza pendente).

## Ver também

- [[screens/financial/collections|collections]] — cobrança via WhatsApp (principal consumidor)
- [[screens/clinical/ortho-news|ortho-news]] — feed que usa o cache + tradução
- [[screens/clinical/patient-details|patient-details]] — docs do paciente + link do portal
- [[screens/portal/public-evaluation|public-evaluation]] — redireciona para o WhatsApp da clínica

> [!note] Conteúdo detalhado por integração
> Ver [[integrations/whatsapp]], [[integrations/cloudinary]], [[integrations/europe-pmc]].
