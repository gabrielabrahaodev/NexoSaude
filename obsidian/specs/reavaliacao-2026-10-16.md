# Reavaliação do NexoSaúde — 16/10/2026

## Escopo e limites

Revisão estática do estado atual do repositório `gabrielabrahaodev/NexoSaude`, com foco transversal nos achados da auditoria anterior e nas suas integrações com regras do Firestore, telas Flutter, HTML público, assinatura/Master, testes e documentação.

- `master` e `producao` apontam atualmente para o mesmo commit: [`0234af8bd08d35f4f250f72680e704829cb5aaaf`](https://github.com/gabrielabrahaodev/NexoSaude/commit/0234af8bd08d35f4f250f72680e704829cb5aaaf).
- O marcador de versão versionado em `web/version.json` é `20261016-1413`.
- Os arquivos centrais `firestore.rules`, `lib/services/portal_mirror.dart`, `lib/screens/financial/collections_screen.dart` e `web/portal.html` têm o mesmo conteúdo em `master` e `producao`.
- **Limite importante:** esta é uma revisão estática do código acessível pelo GitHub. Não consegui executar `flutter analyze`, `flutter test`, build web nem testes com Firebase Emulator neste ambiente, porque o Flutter SDK não está disponível aqui. Também não pude confirmar diretamente o ruleset ativo no Firebase. O estado versionado do repositório não prova, por si só, qual regra está efetivamente em produção.

## Veredito executivo

**Auditoria não pode ser considerada encerrada.** Alguns bugs funcionais anteriores foram corrigidos, mas há permissões cumulativas nas rules que anulam o isolamento por clínica. A maior prioridade é substituir permissões globais baseadas apenas em `isAuthenticated()`/`isOwner()` por autorização da clínica do documento e testes de segurança antes de novo deploy.

## P0 — corrigir antes de considerar seguro

### 1. Usuário `owner` pode alterar o papel de qualquer usuário, inclusive promover a própria conta a `superadmin`

**Evidência:** [`firestore.rules`, regra de users](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L84-L106).

- `allow read: if isAuthenticated()` deixa qualquer conta autenticada ler toda a coleção `users`, incluindo e-mails, telefones, papéis e `allowedClinics`.
- `allow write: if isOwner() || isSuperAdmin()` é uma permissão ampla de create/update/delete para qualquer usuário com papel `owner`; as regras específicas `allow create` não restringem permissões concedidas por outra regra correspondente.
- `isOwner()` consulta o documento atual e verifica somente `role == 'owner'`. Um owner pode escrever seu próprio documento alterando `role` para `superadmin`; depois disso, passa a receber as permissões do superadmin.

**Impacto:** escalada de privilégio para controle da plataforma, acesso a pedidos de trial e débitos de assinatura, além de exposição e alteração global de dados de usuários.

**Correção recomendada:** bloquear alteração de `role` pelo cliente em qualquer owner; separar operações administrativas de usuários da gestão de equipe; usar custom claims ou processo de backend confiável para o papel `superadmin`; limitar `users` por clínica e permitir `get` do próprio perfil sem conceder leitura global. As regras de criação do próprio perfil devem ser a única exceção de cadastro e validar todos os campos permitidos.

### 2. Financeiro, agenda e espelho do portal têm permissões explícitas que contornam o isolamento de `clinicId`

**Evidências:** [`appointments`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L193-L216), [`portal` e `portal_slots`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L218-L245), [`financial`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L240-L245) e regra operacional genérica [`clinicScoped`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L272-L285).

- `financial/{docId}` tem `allow update: if isAuthenticated() || ...`. Qualquer usuário autenticado pode atualizar qualquer documento financeiro, sem vínculo com a clínica e sem restrição de campos. Isso permite, por exemplo, modificar valores ou status financeiro de outra clínica.
- `appointments/{appointmentId}` permite confirmar/remarcar com `(isAuthenticated() || tokenMatches())`. Qualquer usuário autenticado passa pela condição, mesmo que não tenha acesso à clínica do agendamento. A regra operacional escopada não corrige isso: permissões de regras correspondentes são cumulativas (OR).
- `portal/{token}` permite update amplo para qualquer usuário autenticado, podendo substituir campos do espelho de qualquer token conhecido.
- `anamnesis/{patientId}` também dá bypass: create/update usam `isAuthenticated() || allowlist`; delete aceita qualquer autenticado. Isso ignora a clínica do paciente e pode alterar ou remover dados sensíveis de saúde. Ver [`anamnesis`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L247-L270).

**Impacto:** alteração indevida de cobranças e atendimentos de outra clínica; corrupção de espelhos do portal; alteração ou exclusão de anamnese/prontuários sensíveis.

**Correção recomendada:** nas regras de escrita interna, exigir `clinicScoped(resource.data.clinicId)` para documentos existentes e `clinicScoped(request.resource.data.clinicId)` para novos documentos; validar também que `clinicId` não foi trocado. Separar a exceção anônima do portal com allowlist estrita e token vinculado ao documento do paciente. Para anamnese, autorizar equipe a partir da clínica do documento pai do paciente e manter a allowlist pública separada.

## P1 — fluxo de assinatura e funcionalidades públicas

### 3. O próprio owner pode contornar a trava do trial/assinatura

**Evidências:** [`firestore.rules`, clínicas](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L144-L170), [`subscription.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/services/subscription.dart#L6-L20) e [`role_check_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/auth/role_check_screen.dart#L36-L78).

- O comentário das rules diz que `trialEndsAt` e `blockedByAdmin` são de escrita exclusiva do superadmin, mas `allow update: if ownsClinic(clinicId) || isSuperAdmin() ...` dá ao owner poder de atualizar todos os campos da própria clínica.
- `allow create: if isOwner() || isSuperAdmin()` não valida `ownerId`, `trialEndsAt` nem `blockedByAdmin`.
- A lógica do app trata trial sem data como não expirado (`trialExpired(null) == false`) e a trava depende dos campos armazenados na clínica.

**Impacto:** um owner pode prolongar o trial, remover bloqueio manual ou criar documento de clínica com campos que contornam o controle de assinatura.

Além disso, `role_check_screen.dart` retorna `null` quando não consegue ler os dados da clínica (`catch (_) { return null; }`), então a checagem de bloqueio é fail-open em caso de erro. O controle de assinatura está concentrado no cliente; as regras operacionais não impõem `trialEndsAt`/`blockedByAdmin`, portanto um cliente alternativo pode tentar acessar coleções diretamente mesmo que a UI mostre a tela de bloqueio.

**Correção recomendada:** apenas `superadmin` pode criar/alterar `trialEndsAt` e `blockedByAdmin`; owner só pode atualizar uma allowlist de campos operacionais. No create, validar `ownerId == request.auth.uid` e impedir que o cliente defina campos administrativos. Tratar erro de leitura como falha fechada ou estado de indisponibilidade. Se o bloqueio de assinatura precisa ser enforceable, incorporar a condição de clínica ativa às rules operacionais ou mover essa decisão para backend confiável. Rever a política para clínicas legadas sem `trialEndsAt` e documentar uma migração explícita.

### 4. Cadastro do trial grava um campo proibido pelas rules e pode deixar contas pendentes órfãs

**Evidências:** [regra `trial_requests`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L108-L121) e [cadastro em `web/assinatura.html`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/web/assinatura.html#L127-L153).

A rule `keys().hasOnly(...)` não inclui `uid`, porém `doSignup()` envia `uid` no `trial_requests.add()`. O código cria a conta Firebase Auth e grava `users/{uid}` antes de tentar gravar a solicitação; a última operação é negada pela allowlist. O Master exige `m.uid` para aprovar o pedido.

**Impacto:** o usuário pode receber erro no pedido depois de já ter criado conta e perfil `pending_approval`; não há pedido para o Master aprovar, e a repetição do cadastro no mesmo e-mail falha.

**Correção recomendada:** alinhar as rules e o contrato do documento. Se `uid` for necessário para aprovar o trial, incluí-lo com validação forte (`request.auth.uid == request.resource.data.uid`, tipo/formatos e limites para todos os campos). Tornar o fluxo recuperável caso a segunda etapa falhe, com status claro e botão de reenviar/retomar.

### 5. A confirmação pública de consulta provavelmente falha por token diferente do token armazenado no agendamento

**Evidências:** [criação de agendamento](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/agenda/agenda_form_screen.dart#L553-L568), [modelo](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/models/appointment_model.dart#L23-L44) e [`confirmar.html`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/web/confirmar.html#L44-L78).

A tela normal constrói `AppointmentModel` sem informar `portalToken`; o campo é opcional e `toMap()` o grava como `null`. Já o link de confirmação usa o token de `patients/{patientId}` e `confirmar.html` envia esse token. A rule compara o token recebido com `resource.data.portalToken` do **documento do agendamento**. Portanto, nos agendamentos criados pelo fluxo examinado, os valores não coincidem e a confirmação anônima é negada. Links antigos sem token também não passam pelo gate novo.

**Impacto:** paciente é encaminhado ao fallback “avise pelo WhatsApp”, mesmo tendo um link novo com token.

**Correção recomendada:** optar por uma única fonte de verdade: ou gravar/propagar o token no agendamento em todos os fluxos de criação/edição, ou validar o token recebido contra o documento pai do paciente, verificando que o `patientId` do agendamento corresponde ao paciente cujo token foi validado. Não conceder um bypass geral a `isAuthenticated()`.

### 6. A avaliação pública é bloqueada pelas regras atuais

**Evidências:** [tela pública](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/public/public_evaluation_screen.dart#L71-L101) e [gravação de lead](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/public/public_evaluation_screen.dart#L118-L145); [`firestore.rules`, clínicas e fim do arquivo](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules#L144-L157).

A tela documentada como pública faz um `get` em `clinics/{clinicId}` sem exigir login, mas a regra de leitura é `allow read: if isAuthenticated()`. Sem sessão autenticada, `clinicData` não é carregado e a tela mostra “Clínica não encontrada”. Além disso, não existe uma regra explícita para `clinics/{clinicId}/leads/{leadId}`; o formulário tenta adicionar nessa subcoleção, então a gravação é negada por padrão.

**Impacto:** a porta pública de avaliação não consegue carregar a clínica e gravar leads sem autenticação.

**Correção recomendada:** criar uma projeção pública separada (`public_clinics/{id}`) só com nome e contato necessários; não liberar a leitura irrestrita do documento interno da clínica. Criar regra específica para lead anônimo com allowlist, validação de tipos/tamanhos, estado fixo e limite de campos — ou intermediar no backend.

### 7. Mais regras residuais amplas que continuam furando o isolamento

**Evidências:** [`firestore.rules`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/firestore.rules).

- `/clinics/{clinicId}` usa `allow read: if isAuthenticated()`, que permite `get` **e `list`**, apesar de o comentário falar em ausência de listagem. Um usuário autenticado pode enumerar metadados de todas as clínicas.
- `/portal_slots/{clinicId}` agora restringe `get` público e permite `list` apenas autenticado, mas qualquer usuário autenticado pode listar os horários de todas as clínicas e escrever em qualquer documento de slots.
- `/inventory` e `/suppliers` só escopam leitura quando o documento tem `clinicId`; documentos legados sem o campo ficam legíveis por qualquer conta autenticada.
- `procedures` tem exceção equivalente para itens sem `clinicId` (catálogo global documentado, mas a exceção precisa continuar sendo intencional e livre de dados particulares).
- `/clinics/{clinicId}/settings/**` permite leitura geral a qualquer autenticado; `/settings/fees` também permite leitura global; `/settings/integrations/**` usa `isOwner()` global para leitura/escrita, permitindo a qualquer owner atuar nos segredos de outras clínicas se esses documentos existirem.
- `password_reset_requests` e `news` usam `isOwner()` global, permitindo a owners de qualquer clínica consultar/alterar pedidos de reset ou escrever no catálogo global de notícias.

**Correção recomendada:** revisar toda ocorrência de `isOwner()` usada como autorização de dados específicos de clínica; separar `get` de `list`; escopar leituras e escritas por `clinicId`; migrar documentos legados sem `clinicId` ou colocá-los em coleções globais explícitas e auditadas.

## P2 — correções parciais, consistência e operação

### 8. `portal_slots`: correção parcial

Antes o `read` público permitia listar documentos. Agora há `allow get: if true` e `allow list: if isAuthenticated()`, o que bloqueia listagem anônima. Contudo, `allow write: if isAuthenticated()` continua permitindo alteração de horários de qualquer clínica por qualquer usuário autenticado. Manter `get` público se a busca de horários disponíveis exige isso, mas escopar as escritas e restringir `list`.

### 9. Espelho do portal: progresso real, com limites residuais

**Evidências:** [`portal_mirror.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/services/portal_mirror.dart#L228-L315) e [teste do espelho](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/test/portal_mirror_test.dart).

- **Corrigido:** consulta de agendamentos agora aplica `clinicId` quando existe no paciente, ordena por data e busca janela desde o mês anterior; `debtsTotal` soma `amount - paidAmount`; o teste de unidade confere uma dívida parcial de R$ 200 com R$ 80 pagos.
- **Parcial:** pacientes legados sem `clinicId` acionam o caminho sem filtro, embora as rules operacionais exijam acesso escopado; consultas podem ser negadas e o espelho ficar desatualizado.
- **Parcial:** a consulta de agendamentos usa `orderBy('date', descending: true).limit(200)` e depois o builder seleciona as próximas sessões mais antigas. Acima de 200 registros na janela, a consulta pode manter os eventos mais distantes no futuro e excluir os próximos; a direção do `orderBy` precisa corresponder ao requisito de trazer os próximos agendamentos.
- **Parcial:** a consulta financeira continua com `limit(200)` sem ordenação/paginação. Em pacientes com mais de 200 lançamentos, o conjunto considerado para `debtsTotal` pode ser incompleto.
- **Parcial:** `PortalMirrorSync.patient()` retorna `false` e imprime `debugPrint`, mas os chamadores nem sempre verificam o retorno ou mostram ao operador que o espelho falhou. A gravação principal continua funcionando, porém o portal pode ficar desatualizado.

### 10. Cobrança mensal de pacote psicológico: gate melhorado, teste de UI ainda pendente

**Evidência:** [`collections_screen.dart`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/lib/screens/financial/collections_screen.dart#L683-L740).

O caminho de erro/timeout agora exibe “Cálculo indisponível... sem cobrança” e o toque só tenta recalcular; não chama o handler que cobraria o valor cheio. Isso resolve o fallback perigoso visto antes. Ainda falta teste automatizado ou manual registrado que demonstre o gate de erro/timeout na UI e a regressão de cobrança normal.

### 11. Cloudinary: comportamento documentado em parte, `AGENTS.md` segue contraditório

`lib/services/document_service.dart` desabilita a exclusão remota e retorna `false`, deixando o binário órfão no Cloudinary para limpeza manual (decisão compatível com a ausência de Function no plano atual). Porém, a seção “Key Security Rules” de `AGENTS.md` ainda afirma que a exclusão é executada por Cloud Function/Admin SDK. A memória de projeto deve ter uma única afirmação correta para evitar decisões e deploys errados.

### 12. Documentação de testes e release está inconsistente

**Evidências:** [`README.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/README.md), [`plano de testes`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/specs/remodelagem-plano-testes.md), [`resposta à auditoria`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/specs/auditoria-2026-10-16-resposta-plano.md), [`LGPD.md`](https://github.com/gabrielabrahaodev/NexoSaude/blob/master/obsidian/LGPD.md).

- README diz que rules e índices estão publicados e verificados em 16/10; a resposta à auditoria documenta release/rollback e depois uma reversão parcial para leitura autenticada de `users`.
- `remodelagem-plano-testes.md` continua dizendo “Rules NÃO publicadas” e mantém as listas de testes, regressão e segurança sem assinar. Isso contradiz a sequência de deploys e a própria atualização da auditoria.
- A documentação manda executar `migrate/rules-inspect.js`, mas esse arquivo não está presente no tree versionado na branch atual; não há um processo reproduzível dentro do repositório para verificar o release ativo.
- `LGPD.md` descreve controles feitos, mas mantém itens importantes em aberto: contrato operador/controladora, termos/privacidade, logs de exportação, compartilhamento via Meta, proteção de logs com PII, menores e responsável, resposta a incidentes, acesso do superadmin e retenção.
- O Kanban mantém o reconsentimento de 53 pacientes com prazo vencido (06/10) em aberto, além de “validar trial ponta a ponta”.

### 13. Testes e integração contínua ainda não comprovam a segurança

Há testes Dart para funções puras e regressões como saldo parcial, pacote psicológico, subscription e espelho do portal. Na árvore versionada não encontrei testes para Firestore Rules nem configuração de Firebase Emulator, e os testes de gate visual do pacote continuam no checklist manual sem marcação. Não vi workflow GitHub Actions que execute análise/testes em cada push.

**Ação necessária:** criar suíte de rules com `@firebase/rules-unit-testing` + Firestore Emulator com matriz anon/staff de mesma clínica/staff de outra clínica/owner de outra clínica/superadmin; criar CI executando formatter, `flutter analyze`, `flutter test` e build web. Não publicar regras novas até essa matriz passar.

## O que foi corrigido desde a auditoria anterior

| Achado anterior | Estado atual no código |
|---|---|
| Isolamento básico das coleções operacionais por clínica | **Parcial:** a regra genérica agora usa `clinicScoped`; permissões explícitas amplas em `users`, `appointments`, `financial`, `portal` e `anamnesis` ainda anulam parte dessa proteção. |
| Escrita anônima em `appointments` só pelo ID | **Parcial:** a regra ganhou comparação de token, mas o ramo `isAuthenticated()` é global e o token não parece ser populado no documento do agendamento normal. |
| Query do espelho sem escopo/ordem e limite 100 | **Parcial/corrigido:** `clinicId` e data ordenada para appointments modernos, limite 200; lançamentos financeiros continuam sem ordenação/paginação e legados sem `clinicId` são problemáticos. |
| Cobrança de pacote mensal no erro de cálculo | **Corrigido no código:** erro/timeout não chama cobrança cheia; a execução do teste da UI segue pendente. |
| `debtsTotal` somava o valor original em dívida parcial | **Corrigido no código e coberto por teste unitário** (saldo restante). |
| `portal_slots` tinha `read` público | **Parcial:** listagem anônima foi restrita, mas listagem e escrita continuam amplas para qualquer autenticado. |
| Documentação dizia que uma Function apagava arquivos do Cloudinary | **Parcial:** referência do arquivo crítico foi atualizada, outra seção de `AGENTS.md` segue contraditória; exclusão remota permanece desabilitada. |
| README marcava rules/índices como pendentes | **Atualizado**, mas falta prova independente do ruleset ativo; o plano de testes contradiz o README. |
| Ausência de testes de rules e checklist manual sem execução | **Não resolvido.** |

## Plano recomendado — ordem de prioridade

1. **Conter privilégios:** remover a escrita global de owners sobre `/users`; bloquear a mudança de `role` via cliente; proteger `trialEndsAt`/`blockedByAdmin` para superadmin apenas. Revisar imediatamente todos os `allow ... if isAuthenticated()` e `isOwner()` em caminhos sensíveis.
2. **Reescrever regras por ação:** permissões clínicas precisam validar `clinicId` e campos alterados; separar caminhos públicos de caminhos autenticados. Nunca presumir que uma regra escopada posterior limita outra regra correspondente.
3. **Recuperar fluxos críticos:** alinhar `trial_requests.uid`; corrigir a ligação do token de confirmação; liberar avaliação pública por projeção pública e regra de leads segura.
4. **Criar testes de rules + Emulator e CI** antes do próximo release; rodar todos os testes e registrar evidência no plano de testes.
5. **Consertar espelho e dados legados:** backfill de `clinicId`, paginação de `financial`, estado de falha observável no UI e validação do Pix/valor restante.
6. **Harmonizar documentos:** corrigir `AGENTS.md`, atualizar o plano de testes para o release real, versionar script de inspeção sem segredos/caminhos pessoais e fechar ou reagendar o reconsentimento e os trials pendentes.
7. **Verificar produção com evidência:** executar inspeção do release de rules no projeto Firebase correto, validar o resultado no emulador e depois testar manualmente a matriz de perfis. Não inferir segurança de produção apenas pelo SHA do repositório.

## Conclusão

A remodelagem corrigiu defeitos reais de cobrança parcial e de consulta/ordenação do espelho, e introduziu a intenção de vincular confirmações ao token. Porém, **as rules atuais ainda não fornecem isolamento multi-tenant consistente**; há caminhos de escrita amplos que podem afetar financeiro, usuários, agenda, portal e anamnese, além de fluxos públicos que colidem com as rules. Trate os itens P0 como bloqueadores de segurança e não considere a auditoria concluída antes de corrigir e testar a matriz de autorização.
