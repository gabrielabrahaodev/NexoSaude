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
- Diretório de equipe separado: `clinics/{clinicId}/members/{uid}` expõe apenas uid/nome/papel/status; `members_private/{uid}` contém e-mail, contato, CPF, menuAccess e vínculos, acessível apenas ao owner ativo da clínica ou superadmin. `clinic_member_directory.dart`, onboarding Web/Master e `clinic-members-backfill.js` mantêm os dois espelhos. O backfill precisa rodar de novo em dry-run e depois, sob autorização, em apply, para remover PII legada dos documentos `members` existentes.

## Antes de publicar as Rules

1. Rodar `node migrate/audit-clinic-trials.js` (read-only) e revisar cada clínica sem timestamp válido/expiração vencida; `clinicActive()` ainda trata `trialEndsAt` ausente como ativa até a regularização aprovada.\n2. Rodar `node migrate/portal-backfill-patient-id.js` e `node migrate/clinic-members-backfill.js` em dry-run, usando credencial correta; revisar contagens e arquivos a alterar.
3. Só se os dry-runs estiverem corretos e o plano de dados aprovado, executar os backfills com `--apply`. O script de membros substitui `members/{uid}` integralmente para limpar PII legada e cria/atualiza `members_private/{uid}`; o script do portal não cria tokens nem altera consentimento.
4. Verificar CI verde e revisar o diff atualizado.
5. Fazer deploy de Rules apenas com aprovação humana. Nenhum deploy foi feito por esta branch.

## Riscos que permanecem

- **Cloudinary:** upload unsigned e validação sobretudo no cliente; o binário não é removido ao apagar metadados. Exige limitar o preset no painel e/ou backend autenticado para upload/delete.
- **Trial legado:** clínica sem `trialEndsAt` permanece ativa pelas Rules até backfill aprovado com data correta. Não inventar datas nem publicar fail-closed sem regularização.
- **Rate limit/CAPTCHA:** leads, reset público e outros formulários precisam de backend para limite confiável.
- **Exclusão de clínica bloqueada/expirada:** cascata pode falhar ao ler/apagar dados operacionais, pois `clinicScoped` bloqueia acesso operacional. Precisa de fluxo administrativo/servidor.
- **PII em `users/{uid}`:** usuários comuns só podem ler o próprio perfil; owners ativos podem ler perfis completos de usuários das próprias clínicas para administração. O diretório partilhado foi reduzido a uid/nome/papel/status; `members_private` é owner/superadmin-only. Avaliar em iteração futura separar também a fonte de perfil privado `users/{uid}`.
- **Master não atômico:** gravações sequenciais podem deixar registros parciais se uma etapa falhar.
- **Remarcação:** UI ainda precisa filtrar horários do dia atual que já passaram; backend deve revalidar futuro e conflitos.
- **Cloudinary/retention LGPD:** rever DPA, aviso de privacidade, retenção, logs de acesso e processo de exclusão conforme a operação real.

## Validação

O CI automático da branch foi habilitado. Verifique o status do GitHub Actions no commit mais recente antes de merge. Esta auditoria não certifica conformidade jurídica nem verifica diretamente o estado ao vivo do Firebase/Cloudinary.
