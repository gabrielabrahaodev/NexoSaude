---
title: Correções pós-reauditoria integral — 2026-10-17
tags:
  - nexosaude
  - audit
  - security
---

# Correções pós-reauditoria integral

Branch de trabalho: `nova-audit`. Nenhum merge para `producao`, deploy ou escrita no Firestore de produção foi executado nesta rodada.

## Correções implementadas

- **XSS no Master:** a função de escape trata `& < > " '`; o número de WhatsApp deixou de ser interpolado em um handler JavaScript inline e é validado/normalizado antes de abrir `wa.me`.
- **XSS no portal do paciente:** os botões dinâmicos usam atributos `data-action` e um listener delegado; IDs, tempos e texto são escapados antes de compor o HTML.
- **Página de assinatura:** os handlers dinâmicos de Pix e aviso de pagamento também usam eventos delegados; escape HTML completo.
- **Rules do portal:** allowlist para a projeção, associação ao token atual do paciente e consentimento LGPD; as alterações anônimas continuam limitadas a status, pedido de remarcação e aviso de pagamento.
- **Integridade por tenant:** escritas operacionais com `patientId` agora verificam que o paciente existe e pertence à mesma clínica do registro.
- **Diretórios de equipe:** as Rules comparam espelhos com o estado final do perfil usando `getAfter/existsAfter`, inclusive em batches e operações do superadmin.
- **Exclusão de clínica:** o fluxo Web não enumera mais a coleção global `users`; descobre membros pelos diretórios da clínica. A cascata Web aborta antes de apagar dados se a clínica estiver bloqueada ou expirada.
- **Exclusão administrativa:** `migrate/delete-clinic.js` foi adicionado em modo read-only por padrão, exigindo `--apply` e repetição do ID em `--confirm-delete` para exclusão.
- **Provisionamento atômico:** cadastro de funcionário grava perfil e dois espelhos em um batch; conta Auth recém-criada é removida best-effort se o batch falhar. O Master provisiona owner, clínica, projeção pública e diretórios em batch; aprovar trial também é transacional no Firestore.
- **Cadastros órfãos:** o cadastro genérico de funcionário foi removido do login Flutter; a tela encaminha para o fluxo público de teste. Novos logins Google não criam perfil pendente sem fila de aprovação.
- **Papéis profissionais:** aliases legados em português/inglês são normalizados, e listas de profissionais excluem membros inativos.
- **Trial rejeitado:** a recusa mantém a conta Auth e marca o perfil `rejected`; o proprietário pode reenviar uma solicitação com a mesma conta, sem recuperar acesso operacional. A página de assinatura consulta o diretório `members` para contagem, não enumera `users`.
- **Tipos não implementados:** as Rules e formulários de trial aceitam apenas `dental` e `psychology`; `multi` foi removido porque não existe implementação funcional dessa capacidade.
- **Cascatas com arquivos remotos:** exclusões de paciente e clínica abortam antes da primeira escrita se encontrarem metadados que apontem para arquivos Cloudinary; a documentação e o script administrativo explicam a limpeza individual.
- **Cloudinary:** novos uploads unsigned ficam bloqueados no cliente; uma exclusão de documento cujo binário remoto não foi removido retorna erro e preserva a metadata. `migrate/delete-cloudinary-document.js` oferece limpeza individual, autenticada por credenciais de ambiente e com dry-run/dupla confirmação.
- **Regressões:** foram adicionados testes estáticos para as páginas HTML e testes de Rules para espelhos atômicos, portal e referências de pacientes entre tenants.

## Validação

Executar/consultar GitHub Actions no commit mais recente antes do merge. Histórico: Flutter analyzer/tests, teste Node estático das páginas HTML e matrix de Rules no emulador. CI verde não equivale a teste exploratório completo do sistema ao vivo.

## Pendências/limitações explícitas

1. **Cloudinary legado:** novos uploads usam Worker/R2 depois que o Worker e o build forem configurados; arquivos já enviados não são migrados automaticamente. O inventário read-only está disponível em `migrate/cloudinary-inventory.js`; revise o JSON antes da limpeza individual. Ainda é obrigatório desativar/restringir manualmente o preset unsigned no painel Cloudinary e verificar o access mode/entrega dos binários antigos. Não execute limpeza em massa.
2. **Trial/expiração:** a política agora falha fechada para clínicas sem `trialEndsAt` ou com data inválida, exceto os dois IDs conhecidos de clínicas de teste `MxftREXD5vjKtE7SyJIH` e `VlFVjTlNX8yqijeHyczt`, mantidos explicitamente. A exceção está refletida nas Rules, na validação Flutter e no Worker.
3. **Perfil completo em `users/{uid}`:** ainda contém PII e owners da mesma clínica podem lê-lo para administração. Separá-lo exige mapear dependências, migrar dados e revisar telas/serviços; não foi feito sem uma migração controlada.
4. **Abuso de formulários:** foram adicionados rate limits aos endpoints privados de arquivos, não aos formulários públicos de assinatura/trial. CAPTCHA/anti-bot e limitação server-side dos formulários continuam pendentes e exigem integração/configuração externa.
5. **Deploy coordenado:** Rules, Flutter e HTML seguem em `nova-audit`. Nenhum deploy, release de Rules, criação de bucket, alteração no Cloudinary ou escrita de dados de produção foi executado. Antes de promover, faça backup, rode dry-runs/backfills e auditorias, verifique dados antigos do portal contra a allowlist e teste o Worker com conta/paciente fictício.
