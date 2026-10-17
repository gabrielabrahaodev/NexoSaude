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
- **Cloudinary:** novos uploads unsigned ficam bloqueados no cliente; uma exclusão de documento cujo binário remoto não foi removido retorna erro e preserva a metadata. `migrate/delete-cloudinary-document.js` oferece limpeza individual, autenticada por credenciais de ambiente e com dry-run/dupla confirmação.
- **Regressões:** foram adicionados testes estáticos para as páginas HTML e testes de Rules para espelhos atômicos, portal e referências de pacientes entre tenants.

## Validação

Executar/consultar GitHub Actions no commit mais recente antes do merge. Histórico: Flutter analyzer/tests, teste Node estático das páginas HTML e matrix de Rules no emulador. CI verde não equivale a teste exploratório completo do sistema ao vivo.

## Pendências/limitações explícitas

1. **Cloudinary legado:** arquivos já enviados continuam no provedor e URLs antigas podem permanecer acessíveis por quem as conhece. O upload está bloqueado no app, mas isso não desativa o preset unsigned: desative/restrinja-o no painel Cloudinary para impedir uploads diretos de terceiros. Upload/entrega privada autenticada e remoção remota segura ainda exigem configuração externa/backend. Não existe migração automática dos binários nesta branch.
2. **Regras de trial:** por decisão do responsável, as duas clínicas de teste sem `trialEndsAt` seguem aceitas. A Rule ainda trata ausência da data como ativa; antes de ampliar o uso real, definir política de assinatura e regularizar clínicas reais sem expiração.
3. **Perfil completo em `users/{uid}`:** ainda contém PII e owners da mesma clínica podem lê-lo para administração. Uma separação integral da fonte de perfil privado exige migração e revisão de todas as telas/serviços; o diretório público já está mínimo.
4. **Abuso de formulários:** regras de forma/tamanho não substituem rate-limit/CAPTCHA confiável. Sem backend, não é possível garantir limite por IP/dispositivo; manter monitoramento e planejar endpoint confiável.
5. **Deploy coordenado:** Rules e HTML/Flutter alterados permanecem em `nova-audit`. Antes de promover, executar dry-runs de `portal-backfill-patient-id.js`, `clinic-members-backfill.js` e auditorias de espelhos; conferir dados antigos do portal contra a nova allowlist; fazer backup, merge revisado e deploy coordenado. Nenhum backfill ou deploy foi executado pela rodada de correções.
