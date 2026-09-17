---
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
- `lib/services/document_service.dart` — `uploadFile` (retorna url+`publicId`), `saveMetadata`, `getDocs`, `deleteDocument` (só Firestore no Spark), `purgePatientFiles` (só log, após commit)
- `lib/services/news_service.dart` — `getLatestOrthoNews` (Google Alerts + backup, cache 15min, tradução)

## Fluxos

- Cobrança usa `didChangeAppLifecycleState` (resumed + `_currentProcessingId`) para pedir confirmação ao voltar do WhatsApp.
- Docs: upload → URL segura → metadata no Firestore → lista por categoria.

## Regras / Gotchas

- `openWhatsApp` pode falhar (sem app) — sempre tratar `success == false` com SnackBar.
- `cloudName`/`uploadPreset` hardcoded (`dbbh601ay`); preset precisa ser **unsigned** no painel Cloudinary.
- Cache de notícias é em memória — restart limpa; `formats` não usado (limpeza pendente).
