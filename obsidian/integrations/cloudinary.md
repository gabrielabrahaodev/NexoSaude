---
title: Integração Cloudinary
type: integration
status: draft
updated: 2026-09-30
tags:
  - nexosaude
  - integracao
  - cloudinary
---

# Integração Cloudinary

Fonte: [[modules/comms]] + `Requisitos.md` RN-62.

## O que existe no vault

- Upload unsigned para `https://api.cloudinary.com/v1_1/dbbh601ay/auto/upload` (`resource_type: auto`, preset unsigned `dbbh601ay` = `cloudName`/`uploadPreset` hardcoded).
- `lib/services/document_service.dart` — `uploadFile` (retorna url + `publicId`), `saveMetadata`, `getDocs`, `deleteDocument` (só Firestore no Spark), `purgePatientFiles` (só log, após commit).
- Metadados em `patients/{id}/docs`: `fileType` (image/document da extensão), categoria, título, uploader, `publicId`/`resourceType`.
- Fluxo: upload → URL segura → metadata no Firestore → lista por categoria.
- `validateUpload` (testado) barra tipo/vazio/+10MB antes de enviar; travar também no painel (pasta, tipos, tamanho). Preset precisa ser **unsigned** no painel.
- Exclusão apaga só metadados (Spark sem Functions; binários órfãos com limpeza manual pelo painel). Cascata: deletes em blocos de 450.

## TODOs

- TODO: custo/limite Cloudinary fora do free tier Firebase — monitorar (citado no PRD, sem números no vault).

Ver [[modules/comms]], [[screens/clinical/patient-details|patient-details]].
