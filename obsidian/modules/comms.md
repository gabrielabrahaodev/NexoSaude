---
title: Comms
tags:
  - nexosaude
  - brain
  - modules
name: comms-module
description: Comunicação, WhatsApp, documentos privados/legados e notícias.
---

# Comunicação / Conteúdo

## O que é

Mensagens abertas manualmente no WhatsApp, arquivos associados ao paciente e notícias. **O backend de armazenamento depende da branch e da configuração do build.** Não confundir código versionado com Worker efetivamente implantado.

## Arquivos-chave

- `lib/services/whatsapp_helper.dart` — mensagens e abertura do WhatsApp; envio e confirmação não são automáticos.
- `lib/utils/external_link.dart` — abertura de links externos após operações assíncronas, considerando bloqueadores de pop-up.
- `lib/services/document_service.dart` e `lib/screens/patients/tabs/patient_docs_tab.dart` — upload, leitura autenticada/URL temporária, metadados e exclusão.
- `workers/private-documents/` — Worker Cloudflare, rotas, validação e documentação de configuração **somente na branch de desenvolvimento**.
- `lib/services/news_service.dart` — notícias por especialidade, com cache.

## Situação por branch — 03/11/2026

| Ambiente/versionamento | Código observado |
|---|---|
| `master` / `producao` (mesmo commit `5fb7aaf`) | `DocumentService` faz upload Cloudinary; exclusão remota desabilitada, exigindo tratamento administrativo dos órfãos. |
| `feat/agenda-clinical-dark` (commit `771e300`) | `DocumentService` usa API privada R2/Worker para novos uploads, com Firebase ID token, validação de arquivo e acesso por URL assinada. |

Na variante clínica, `DocumentService.isPrivateStorageConfigured` exige `PRIVATE_FILES_API_URL` válida no build. `deploy.bat` mantém o Worker **desativado por padrão**. O opt-in futuro requer `NEXO_ENABLE_PRIVATE_STORAGE=true` **e** `PRIVATE_FILES_API_URL` configurada. Sem isso, a aba Documentação não libera novos uploads; links antigos ainda podem ser abertos conforme a URL e a permissão correspondente.

## Fluxos na variante clínica

- Novo arquivo: selecionar JPG/JPEG/PNG/WEBP/PDF (limite 10 MiB), validar conteúdo no Worker, gravar objeto privado e metadata `patients/{id}/docs/{documentId}`.
- Abrir R2: autenticar, conferir escopo de clínica/paciente, obter URL assinada temporária. Arquivo legado não R2 usa a URL armazenada.
- Excluir documento remoto: primeiro tentar remoção pelo Worker autenticado; só remover metadata após sucesso. **Cloudinary antigo não é removido pelo Worker** e demanda procedimento administrativo.
- Excluir paciente/clínica: preflight impede início da cascata se existirem arquivos remotos a limpar; batches de Firestore não garantem atomicidade global.
- WhatsApp: preparar/abrir mensagem, confirmar envio pelo operador. Registro de contato **não é baixa financeira**.

## Regras e riscos

- Não usar fallback de upload público quando o Worker estiver desativado; não afirmar que migração R2 foi publicada só porque existe o código.
- Não remover metadados de Cloudinary antigo antes de excluir o arquivo correspondente: preservar rastreabilidade.
- Testar autorização por clínica, 401/403, token revogado, assinatura expirada, arquivos maiores que 10 MiB, CORS, exclusão e falha de conexão antes de habilitar.
- Upload/exclusão não foram testados nem publicados nesta rodada documental.
- Cache de notícias em memória não equivale a cache persistente.

## Ver também

- [[auditoria-codigo-2026-11-03]] — comparação estática de branches e achados.
- [[patient-details]] — ficha com documentos do paciente.
- [[collections]] — cobrança via WhatsApp.
- [[portal-mirror]] — espelhos públicos, separados dos arquivos privados.
- `workers/private-documents/README.md` — configuração manual, somente na branch com Worker.
