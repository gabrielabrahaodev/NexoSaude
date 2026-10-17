> **Snapshot histórico de 16/10/2026.** Estas observações descrevem a situação daquele commit e foram parcialmente supersedidas pela branch `nova-audit`; consulte `auditoria-integral-2026-10-17.md` para o estado atual. Não use os achados abaixo como descrição do código atual sem revalidar.

# Reavaliação integral do NexoSaúde — atualização de 16/10/2026

## Veredito executivo

**A reavaliação melhorou de forma importante o projeto, mas ainda não considero a segurança nem todos os fluxos críticos prontos para encerrar a auditoria.** Foram introduzidos escopo por clínica nas coleções operacionais, proteção contra alteração direta de `role`, validação do trial, token para confirmação, projeção pública de clínica, correções no cálculo de saldo parcial e uma matriz de testes de Firestore Rules. O CI observável executou a suíte Flutter e a matriz do emulador com sucesso no commit de código anterior à remoção do workflow.

Mesmo assim, esta revisão estática identificou **dois bloqueadores principais**: a anamnese continua publicamente legível/editável por quem conhece o ID do paciente, e a função de regra usada na criação de clínicas passa um mapa para uma verificação de conjunto, aparentemente negando a criação pelo próprio owner. Também há um bypass do controle de menu no perfil próprio, revogação incompleta do token de confirmação, onboarding sem projeção pública e um defeito no tratamento de falha do cadastro de trial.

**Recomendação:** não declarar a auditoria encerrada antes de corrigir os P0/P1 abaixo, aumentar a matriz de autorização para cobrir cada caso e executar a regressão manual dos fluxos de usuário.

## Estado do repositório e evidências

- Repositório: [`gabrielabrahaodev/NexoSaude`](https://github.com/gabrielabrahaodev/NexoSaude).
- HEAD consultado: `e5f73e0ce3d6483681e3e93825df5b1790ad8bf1` — `docs: sem CI automatico (validacao manual documentada)`, em 16/10/2026 20:57:22 UTC.
- No momento da consulta, `master` e `producao` apontavam para o mesmo SHA. `web/version.json` informava `20261016-1751`.
- `firestore.rules` no repositório tem blob SHA `a7fe008bfc9c4a13188cf6a5f0a5d901e90729fd`.
- O README registra o ruleset ativo como `f50ad0ac` e afirma que rules/índices foram publicados. **Não consegui consultar o release diretamente pela API do Firebase nesta execução**; portanto, o identificador ao vivo continua sendo uma declaração documentada, não uma verificação independente feita por esta auditoria.
- GitHub Actions executou `flutter analyze` e `flutter test`, e a matriz Firestore Emulator, com conclusão `success` no commit `1fc6aea1372be0cb2d828e64bd77e48df46cd9cf`: [execução CI 38965482220](https://github.com/gabrielabrahaodev/NexoSaude/actions/runs/38965482220) e [execução CI 38965478229](https://github.com/gabrielabrahaodev/NexoSaude/actions/runs/38965478229). A execução do analisador usa `--no-fatal-warnings --no-fatal-infos`: isso comprova ausência de erros bloqueantes, não zero avisos/infos.
- Depois dessas execuções, o commit [`ac1d696e`](https://github.com/gabrielabrahaodev/NexoSaude/commit/ac1d696e669ba2ce8e90e8bee6012d9072dbf934) removeu `.github/workflows/ci.yml`; o HEAD atual não tem workflow em `.github/`. Os testes passaram no código atual imediatamente antes dessa remoção, mas o repositório ficou sem proteção automática contra regressões futuras.
- O plano de testes continua com os cenários manuais de regressão e pós-deploy desmarcados. CI verde não comprova os fluxos visuais no navegador nem a publicação real do Hosting/Rules.

## Achados priorizados

### P0 — Anamnese pública: dados de saúde e gravação sem token dedicado

**Arquivos:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L460-L483), [`web/anamnese.html`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/web/anamnese.html#L127-L224), [`anamnesis_tab.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/patients/tabs/anamnesis_tab.dart#L170-L184) e [`test/rules/matrix.test.js`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/test/rules/matrix.test.js).

- `allow get: if true` em `anamnesis/{patientId}` deixa o documento inteiro legível sem autenticação quando alguém conhece o ID. O documento pode conter medicações, alergias, condições, gravidez, hábitos e observações clínicas.
- A própria página HTML busca esse documento pelo `id` da URL e pré-preenche dados existentes. O link não usa um token público separado, expirável ou revogável.
- A regra de `create` anônimo aceita qualquer documento cujo conjunto de campos esteja na allowlist; não valida tipos/tamanhos em todos os campos nem exige prova de posse de um token vinculado ao paciente. A regra de `update` também permite alterações anônimas restritas aos mesmos nomes de campo se o ID for conhecido.
- O teste atual chega a afirmar como sucesso uma criação anônima de anamnese e não testa a confidencialidade do `get` público. Assim, a matriz pode ficar verde sem demonstrar isolamento de dados sensíveis.

**Correção recomendada:** retirar a leitura pública do documento clínico interno. Usar um endpoint/backend confiável ou um documento público separado, com token aleatório dedicado, escopo mínimo, validade/revogação e validação estrita de campos/tipos; a página não deve ler o prontuário completo para fazer prefill. Criar testes para anônimo sem token, token inválido/revogado, leitura indevida e alteração do documento de outro paciente. Não basta ocultar o ID na interface.

### P1 — Criação de clínica pelo owner parece negada pelas Rules

**Arquivos:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L118-L122) e [`clinic_management_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/clinics/clinic_management_screen.dart#L143-L182).

`_noClinicAdminKeys(affected)` chama `affected.hasAny(...)`, que faz sentido quando `affected` é um conjunto de chaves. Na regra de criação de clínica, porém, o argumento passado é `request.resource.data` — o mapa inteiro — em vez de `request.resource.data.keys()` (ou uma lista/conjunto de chaves). Os exemplos oficiais do Firebase usam `request.resource.data.keys().hasAny(...)` para verificar chaves na criação ([documentação Firebase](https://firebase.google.com/docs/firestore/security/rules-fields)). A condição pode falhar em tempo de avaliação e negar a criação pelo owner.

O fluxo real `_saveClinic()` do app depende dessa permissão. A matriz atual testa atualização de clínica por owner, mas **não testa a criação de uma clínica pelo owner**, razão pela qual esse problema pode coexistir com 14/14 testes verdes.

**Correção recomendada:** separar validadores para criação e atualização; no create, verificar `request.resource.data.keys()` e exigir os campos permitidos/obrigatórios; no update, usar `diff().affectedKeys()`. Adicionar teste de emulador para owner criando sua própria clínica sem campos administrativos, owner tentando definir `trialEndsAt` e superadmin criando a clínica aprovada. Testar também o fluxo de ponta a ponta pelo app.

### P1 — Funcionário pode autoatribuir permissões `menuAccess`

**Arquivo:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L200-L212) e helper `_clinicOpAllowed` em [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L321-L330).

`_selfProfileUpdate()` inclui `menuAccess` entre os campos que o próprio usuário pode alterar. Esse mesmo mapa é usado em `_clinicOpAllowed()` para autorizar mudanças nos campos `pixKey`, `gradeConfig` e `whatsappNumber` da clínica. Logo, um funcionário pode tentar alterar seu próprio `users/{uid}.menuAccess` diretamente no Firestore para marcar `g_pix`, `g_grade` e/ou `g_clinica` como `true` e, em seguida, obter uma permissão que deveria ser controlada pelo owner da clínica. Além disso, o ramo de atualização operacional de `clinics` usa `hasClinicAccess(clinicId) && _clinicOpAllowed()` sem testar `clinicActive(clinicId)`, então esse caminho também não herda a trava de trial/bloqueio aplicada em `clinicScoped()`.

**Correção recomendada:** remover `menuAccess` de `_selfProfileUpdate`; somente o gestor autorizado pode modificar permissões de menu. Acrescentar testes negativos em que um staff tenta alterar o próprio `menuAccess` e depois atualizar `clinics/{id}.pixKey`/`gradeConfig`/`whatsappNumber`; e teste positivo do owner da clínica gerenciando o acesso do staff.

### P1 — O login ignora `status` e permite que cadastro pendente chegue ao dashboard

**Arquivos:** [`role_check_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/auth/role_check_screen.dart#L23-L102), [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L55-L88) e [`login_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/auth/login_screen.dart#L112-L171).

O fluxo de signup de trial cria `users/{uid}` com `role: 'owner'`, `status: 'pending_approval'` e `allowedClinics: []`. Porém, `_checkRole()` valida apenas a existência do documento e de `role`; não barra `pending_approval` nem verifica um estado ativo do usuário antes de chamar `MainWebDashboard`. Para owner sem clínica, a verificação de trial também não é executada porque `clinicId == null`. O menu tende a limitar a tela de onboarding, mas a conta já está dentro do app e as regras ainda permitem listas autenticadas globais de `users` e `clinics`. Além disso, `hasClinicAccess()` verifica `allowedClinics`, mas não valida `status` do perfil; um estado pendente/inativo não é, por si só, um bloqueio server-side.

**Correção recomendada:** definir estados permitidos e bloqueios explícitos no login e nas Rules. Um perfil pendente deve cair numa tela de “aguardando aprovação”, sem acesso ao dashboard nem às listas globais; um usuário inativo deve perder acesso operacional independentemente de o `allowedClinics` antigo continuar preenchido. Acrescentar testes para owner pendente sem clínica e funcionário desativado com `allowedClinics` preenchido.

### P1 — Revogar o portal não invalida todos os links antigos de confirmação

**Arquivos:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L390-L420) e [`patient_details_tab.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/patients/tabs/patient_details_tab.dart#L101-L145).

A regra `apptTokenOk()` aceita a confirmação quando o token recebido corresponde ao `resource.data.portalToken` já gravado no agendamento (`ownTok`), sem exigir que o token continue sendo o token atual em `patients/{patientId}.portalToken`. A rotina de revogação limpa o token do paciente e apaga o espelho `portal/{token}`, mas não limpa o token persistido nos documentos de `appointments`. Portanto, um link antigo que contenha o token persistido no agendamento ainda pode passar pela primeira condição e permitir confirmar/remarcar aquela consulta.

**Correção recomendada:** validar sempre contra o token atual do paciente (e conferir vínculo `patientId`), ou manter tokens de confirmação individuais por agendamento com revogação explícita. A revogação deve invalidar também as permissões de confirmação; não confiar num token antigo copiado dentro do agendamento. Teste obrigatório: gerar link, revogar consentimento, tentar confirmar e remarcar usando o link antigo — ambos devem ser negados.

### P1 — Cadastro de trial: a limpeza de conta órfã tem erro de escopo JavaScript

**Arquivo:** [`web/assinatura.html`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/web/assinatura.html#L127-L163).

`const uid = cred.user.uid` está declarado dentro do bloco `try`, mas o `catch` tenta ler `uid` para apagar o documento de usuário e a conta Auth. Essa variável não existe no escopo do `catch`; a referência gera `ReferenceError`, que é engolido pelo `catch` interno (`catch (_) {}`). Assim, quando a escrita de `trial_requests` falha depois da criação de Auth/perfil, a limpeza comentada no código não é executada como esperado. Isso pode deixar a conta pendente/órfã e impedir nova tentativa com o mesmo e-mail.

**Correção recomendada:** declarar `let uid = null` antes do `try` e atribuí-lo após criar Auth, ou usar uma referência previamente guardada com controle explícito; testar falha artificial no write de `trial_requests`, confirmar remoção do perfil/conta e permitir recuperação sem trocar de e-mail.

### P1 — Projeção `public_clinics` não é criada em todos os caminhos de onboarding

**Arquivos:** [`clinic_management_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/clinics/clinic_management_screen.dart#L174-L182), [`web/master.html`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/web/master.html#L204-L221) e [`master_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/master/master_screen.dart#L225-L262).

A projeção `public_clinics/{id}` é gravada pelo fluxo `_saveClinic()` do app. Os fluxos de aprovação de trial e criação de owner no Master criam `clinics/{id}` e `users/{uid}`, mas não criam a projeção pública. A avaliação online lê exclusivamente `public_clinics/{id}` e grava os leads em sua subcoleção. Assim, clínicas criadas pelo onboarding habitual do Master podem existir e operar sem que a avaliação pública encontre seus dados. Também não há sincronização demonstrada da projeção quando nome/WhatsApp são atualizados no documento interno da clínica.

**Correção recomendada:** encapsular criação/atualização de clínica em uma operação única que mantenha `clinics` e `public_clinics` consistentes; alternativamente, provisionar a projeção no backend e sincronizar alterações. Adicionar teste para cada caminho de criação: aprovação de trial via web Master, Novo owner via web Master, Master Flutter e criação pelo owner.

### P1 — Leitura global de `users` revela dados de outros usuários

**Arquivo:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L138-L142).

`allow list: if isAuthenticated()` permite a qualquer usuário autenticado enumerar documentos de `users`, incluindo e-mail, telefone/WhatsApp, papel, status e `allowedClinics`, de acordo com os campos armazenados. O comentário da regra reconhece esse residual para preservar dropdowns e fluxos atuais; o teste também espera que o staff consiga listar a coleção inteira. IDs imprevisíveis não evitam a enumeração que a permissão `list` autoriza.

Há um padrão semelhante em `clinics/{clinicId}`, com `allow get, list: if isAuthenticated()` para todas as clínicas, expondo metadados (inclusive campos de contato/configuração armazenados nesse documento) a qualquer conta autenticada. Outro residual é `password_reset_requests`: pedidos anônimos sem `clinicId` podem ser lidos/alterados/apagados por qualquer usuário com papel `owner`, porque a regra trata a ausência do campo como acesso global. Mesmo sendo descritos como transitórios, os e-mails de reset de outros clientes não devem ficar acessíveis a qualquer owner.

**Correção recomendada:** substituir listas globais por diretório mínimo de equipe por clínica, com somente os campos necessários para dropdowns, e escopar leituras de clínicas. Adicionar teste negativo: staff da clínica A não deve enumerar perfis e metadados da clínica B.

### P1 — Pedidos globais de reset de senha não estão isolados; listagem da equipe não prova escopo

**Arquivos:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L277-L293), [`login_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/auth/login_screen.dart#L112-L171), [`employee_manager_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/employees/employee_manager_screen.dart#L466-L545) e [`reset-password.js`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/migrate/reset-password.js).

- O pedido “Esqueci a senha?” criado no login não inclui `clinicId`. A Rule permite que **qualquer owner** leia/atualize/apague documentos sem esse campo.
- O script administrativo grava a senha temporária em texto puro no próprio pedido (`tempPassword`), e a tela de Funcionários a exibe. O escopo global do pedido é perigoso: uma credencial temporária não pode ficar acessível a owners de outros clientes.
- Ao mesmo tempo, a consulta do widget em `employee_manager_screen.dart` lista `password_reset_requests` ordenando por `createdAt`, sem `where('clinicId', isEqualTo: ...)`. Como as Rules restringem registros com `clinicId` às respectivas clínicas e o Firestore não filtra resultados pela Rule, a consulta global não consegue demonstrar que todos os documentos retornados são acessíveis e tende a ser negada quando há registros de outras clínicas. Isso pode fazer a fila de reset parar de carregar quando o SaaS tem mais de uma clínica.

**Correção recomendada:** separar a fila global de login (somente superadmin/back-end confiável) da fila interna de funcionários (filtrada por `clinicId` da sessão). Nunca salvar senha temporária em documento legível pelo cliente; preferir processo de reset controlado e entrega pelo canal verificado. Acrescentar testes de permissão e um teste com dois tenants e um pedido global.

### P1/P2 — `trialEndsAt` ausente continua significando acesso ativo

**Arquivo:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L70-L88); coerente com o fallback em `subscription.dart` e `role_check_screen.dart`.

`clinicActive()` trata `trialEndsAt == null` como clínica ativa. A documentação chama isso de exceção para dados legados e unidades adicionais, e o Kanban ainda mantém o backfill como pendente (`nx-172`). Isso faz com que clínicas sem data de expiração permaneçam sem uma trava de trial no servidor até que os dados sejam migrados. Além disso, ao consertar o create de clínica do owner, o fluxo `_saveClinic()` precisa definir explicitamente a política de trial/assinatura para novas unidades — não deve criar um registro sem `trialEndsAt` e transformá-lo em ativo indefinidamente por omissão.

**Correção recomendada:** inventariar documentos legados sem `trialEndsAt`, definir política explícita para assinatura por owner/unidade, executar backfill controlado e fazer a regra distinguir legado autorizado de nova clínica criada sem prazo.

### P2 — Saldo do portal pode ficar incompleto sem avisar o paciente

**Arquivos:** [`portal_mirror.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/services/portal_mirror.dart#L284-L329) e [`web/portal.html`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/web/portal.html#L247-L253).

O espelho limita a consulta financeira a 500 documentos, sinaliza `debtsTruncated` quando atinge o teto e soma apenas os documentos retornados. A interface HTML exibe `debtsTotal`, mas não consulta nem mostra `debtsTruncated`. Em pacientes com 500 ou mais lançamentos, o total apresentado pode estar incompleto e parecer definitivo.

**Correção recomendada:** fazer a interface exibir um aviso claro quando `debtsTruncated == true` e, se o saldo tiver de ser exato, substituir o teto silencioso por paginação/agrupamento confiável ou cálculo no backend. Adicionar teste de renderização para o caso truncado.

### P2 — Leads públicos sem proteção de abuso suficiente

**Arquivo:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L347-L359).

A regra anônima de lead limita o número de respostas e restringe o nome dos campos, status e score, mas não limita tamanho/conteúdo de cada resposta nem oferece rate limiting. Isso pode permitir spam ou documentos excessivamente grandes, com custos e ruído no funil comercial.

**Correção recomendada:** validar tamanho máximo de cada resposta e tamanho total dos dados; considerar backend/limite de frequência ou CAPTCHA/antiabuso conforme a arquitetura atual. Preservar leitura de leads somente para a equipe da clínica.

### P2 — Documentação e checklist ainda se contradizem

**Arquivos:** [`README.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/README.md), [`obsidian/specs/auditoria-2026-10-16-resposta-plano.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/specs/auditoria-2026-10-16-resposta-plano.md), [`obsidian/specs/remodelagem-plano-testes.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/specs/remodelagem-plano-testes.md), [`obsidian/specs/reavaliacao-2026-10-16.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/specs/reavaliacao-2026-10-16.md), [`obsidian/LGPD.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/LGPD.md) e [`obsidian/Operon/Kanban NexoSaúde.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/Operon/Kanban%20NexoSa%C3%BAde.md).

- O relatório `reavaliacao-2026-10-16.md` ainda descreve o estado antigo (`0234af8`, versão `20261016-1413`) e termina dizendo que as rules ainda têm permissões amplas anteriores; precisa ser substituído ou claramente marcado como fotografia histórica.
- `auditoria-2026-10-16-resposta-plano.md` contém um bloco que diz que as rules novas não foram publicadas e, mais adiante, uma tabela de reavaliação dizendo que `f50ad0ac` foi publicado. A contradição pode levar a uma decisão errada de deploy.
- O plano de testes diz que as regras novas não foram publicadas, apesar de README/commit posterior documentar o release; sua seção manual pós-deploy/regressão segue sem assinatura.
- `LGPD.md` ainda lista como exceções globais alguns controles já reescritos nas Rules atuais (p. ex., inventory/suppliers) e mantém sugestões legais/operacionais importantes abertas. Evitar a expressão geral “conforme à LGPD” enquanto os controles operacionais/contratuais e a avaliação jurídica não estiverem fechados.
- O Kanban ainda marca a matriz/release como pendente embora o release esteja documentado e a matriz tenha passado num CI anterior; distinguir “automatizado executado”, “publicado”, “verificado ao vivo” e “validado manualmente”.

**Correção recomendada:** registrar um único estado atual com SHA, versão web, ruleset, índices, links de execuções e resultado dos testes manuais; manter relatórios antigos como históricos, sem deixar conclusões antigas parecendo atuais.

### P2 — Remoção do CI automático reduz a proteção contra regressões

A matriz de 14 casos e a suite Flutter passaram em duas execuções de CI no commit `1fc6aea`. Em seguida, o workflow foi removido no commit `ac1d696`, e o HEAD atual não tem `.github/workflows/`. A validação manual pode ser uma decisão operacional deliberada, mas significa que novos pushes não voltam a executar os testes automaticamente.

**Correção recomendada:** manter ao menos um workflow manual (`workflow_dispatch`) que rode o analyze, a suite Flutter e a matriz do emulador, ou restaurar o CI automático em pushes/PRs. A publicação das Rules deve depender de uma evidência recente e reproduzível da matriz.

### P2 — Higiene do repositório

O tree contém `node_modules/` versionado (incluindo `.package-lock.json` e o pacote `cors`) e `.firebase/hosting.cHVibGlj.cache`. O `.gitignore` ignora `.firebase/` e `migrate/node_modules/`, mas não possui regra para o `node_modules/` da raiz; o cache de Hosting, por sua vez, parece já estar rastreado. A quantidade observada é pequena, e não encontrei arquivo de service account/chave privada nos caminhos versionados retornados pela árvore consultada; ainda assim, dependências instaladas e cache de deploy não deveriam ser fonte de verdade.

**Correção recomendada:** remover esses artefatos do índice do Git, preservar `package-lock.json` quando aplicável e documentar claramente onde o pacote Node é usado (o `package.json` raiz observado declara `cors`, mas não declara script de aplicação).

### P2 — Cloudinary continua gerando arquivos órfãos

O comportamento está coerentemente documentado em `document_service.dart` e `AGENTS.md`: no plano Spark, a exclusão remota está desabilitada e apagar o documento remove apenas metadados do Firestore, deixando os binários no Cloudinary para limpeza manual. Não é uma contradição atual de código, mas é risco de retenção/custo e precisa continuar explícito na política de retenção e no processo operacional.

## O que melhorou e permanece bom

- Coleções operacionais principais usam `clinicScoped()` para reads/writes, com `clinicActive()` aplicado no caminho genérico e despesas/laboratório.
- O papel `role` não pode ser alterado livremente pelo próprio perfil; gestão de equipe separa o caminho de self-profile do de team-management.
- Acesso de owner a `trialEndsAt`, `blockedByAdmin` e `ownerId` é bloqueado no update; o Master usa `superadmin` para administração.
- `role_check_screen.dart` repropaga erro de leitura da trava e leva à tela de indisponibilidade, em vez de liberar acesso ao cair num `catch` que retorna sucesso.
- A criação do pedido de trial agora inclui `uid` nas Rules e valida o vínculo com `request.auth.uid`.
- A confirmação/remarcação de consulta exige token ou escopo interno, em vez de aceitar qualquer usuário autenticado. O problema residual é a revogação não invalidar tokens antigos armazenados nos agendamentos.
- A avaliação lê uma projeção pública pequena em vez de ler o documento interno `clinics`; o problema residual é não criar/sincronizar essa projeção em todos os fluxos de onboarding e atualização.
- O cálculo financeiro de pacote mensal em erro/timeout não chama a cobrança pelo valor cheio; a UI avisa que o cálculo está indisponível e apenas tenta recalcular. Há teste do widget para esse gate.
- `portal_mirror.dart` calcula o saldo restante da dívida parcial, ordena agendamentos ascendentemente e torna falhas do rebuild observáveis em vários chamadores; o teto financeiro de 500, porém, ainda não é comunicado na interface web.
- A suíte de regras no emulador foi executada em CI e reportada como verde; o principal gap é cobertura insuficiente, não ausência total de infraestrutura de testes.

## Ordem de correção proposta

1. **Imediato — saúde/privacidade:** fechar `get` e writes públicos da anamnese atrás de token dedicado revogável/backend; acrescentar testes de acesso indevido.
2. **Imediato — autorização:** corrigir `_noClinicAdminKeys` no create e remover `menuAccess` de self-update; adicionar testes que reproduzem ambas as falhas.
3. **Imediato — revogação:** invalidar tokens antigos de confirmação de forma verificável e testar links após revogação.
4. **Alta — onboarding:** provisionar e sincronizar `public_clinics` em todos os criadores de clínica e consertar a limpeza do signup de trial; testar falhas parciais e recuperação.
5. **Alta — dados multi-tenant e reset:** reduzir a enumeração de `users`/`clinics`, isolar completamente a fila de reset e não persistir senhas temporárias legíveis pelo cliente; planejar backfill de `trialEndsAt` e `clinicId` com cuidado, antes de tornar o gate mais estrito.
6. **Média — financeiro/abuso:** expor `debtsTruncated` no portal e limitar payload/frequência de leads públicos.
7. **Média — engenharia de release:** restaurar CI, completar os cenários manuais de agenda, portal, avaliação, trial e pacote psicológico; atualizar os documentos e o Kanban para refletirem evidências separadas de teste, deploy e verificação ao vivo.
8. **Média — manutenção:** retirar cache/node_modules do Git e definir o processo de limpeza/retensão dos binários Cloudinary órfãos.

## Limites da avaliação

Esta foi uma auditoria estática dos arquivos versionados e dos resultados acessíveis no GitHub. Não executei um novo build local, não acessei dados reais de pacientes e não consultei diretamente o estado vivo do Firebase nesta execução. As duas execuções de CI referidas estão vinculadas ao commit listado acima; a interface manual no navegador ainda não está marcada como validada no plano de testes. O relatório não deve ser interpretado como certificação jurídica de conformidade com a LGPD.
