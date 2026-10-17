---
title: Auditoria integral — implementação nova-audit
tags:
  - nexosaude
  - audit
  - security
---

# Auditoria integral — branch `nova-audit`

Data: 2026-10-17. Base: commit anterior à auditoria `5fb7aaf`.

## Alterações implementadas

- Firestore Rules: remove listagens globais comuns de `users` e `clinics`; diretório de equipe usa `clinics/{clinicId}/members` com leitura por tenant.
- Criação de unidade via owner exige usuário ativo e herda trial de clínica ativa **do mesmo proprietário**; owner não pode escolher data maior nem omitir a data.
- Atualização de `clinicId` em inventário, fornecedores, procedimentos, despesas e pedidos de laboratório não permite transferência entre tenants.
- Exclusões operacionais usam `clinicId` do documento existente sem depender de `request.resource` em DELETE.
- Aviso de pagamento anônimo exige token atual do paciente vinculado ao lançamento.
- Portal: espelho grava `patientId`; leitura/escrita anônimas exigem token igual ao atual e aceite LGPD. Revogação limpa primeiro o token fonte.
- WhatsApp salvo na Gestão atualiza também a projeção pública.
- Cascata de exclusão inclui leads e projeção em `public_clinics`.
- UI mostra apenas tipos implementados (`dental`, `psychology`).
- CI executa analyzer, testes Flutter e matriz Firestore Rules em push/PR.
- Diretório de membros: telas de equipe/profissionais listam um espelho mínimo por clínica; onboarding novo grava esse espelho, e `clinic-members-backfill.js` migra vínculos existentes.

## Antes de publicar as Rules

1. Rodar `node migrate/portal-backfill-patient-id.js` e `node migrate/clinic-members-backfill.js` em dry-run, usando credencial correta; revisar contagens e arquivos a alterar.
2. Só se os dry-runs estiverem corretos, executar os dois scripts com `--apply`. Eles corrigem espelhos existentes; não criam tokens nem alteram consentimento.
3. Verificar CI verde e revisar o diff.
4. Fazer deploy de Rules apenas com aprovação humana. Nenhum deploy foi feito por esta branch.

## Riscos que permanecem

- **Cloudinary:** upload unsigned e validação sobretudo no cliente; o binário não é removido ao apagar metadados. Exige limitar o preset no painel e/ou backend autenticado para upload/delete.
- **Trial legado:** clínica sem `trialEndsAt` permanece ativa pelas Rules até backfill aprovado com data correta. Não inventar datas nem publicar fail-closed sem regularização.
- **Rate limit/CAPTCHA:** leads, reset público e outros formulários precisam de backend para limite confiável.
- **Exclusão de clínica bloqueada/expirada:** cascata pode falhar ao ler/apagar dados operacionais, pois `clinicScoped` bloqueia acesso operacional. Precisa de fluxo administrativo/servidor.
- **PII em `users/{uid}`:** Rules restringem quais documentos podem ser listados, mas não campos dentro do documento. Migrar para perfil mínimo compartilhável + perfil privado segue necessário.
- **Master não atômico:** gravações sequenciais podem deixar registros parciais se uma etapa falhar.
- **Remarcação:** UI ainda precisa filtrar horários do dia atual que já passaram; backend deve revalidar futuro e conflitos.
- **Cloudinary/retention LGPD:** rever DPA, aviso de privacidade, retenção, logs de acesso e processo de exclusão conforme a operação real.

## Validação

O CI automático da branch foi habilitado. Verifique o status do GitHub Actions no commit mais recente antes de merge. Esta auditoria não certifica conformidade jurídica nem verifica diretamente o estado ao vivo do Firebase/Cloudinary.
