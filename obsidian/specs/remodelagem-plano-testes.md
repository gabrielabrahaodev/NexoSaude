---
title: Plano de testes da remodelagem
tags:
  - nexosaude
  - testes
  - qa
  - remodelagem
aliases:
  - remodelagem-plano-testes
name: remodelagem-plano-testes
description: Plano de testes funcional, segurança, integração e regressão para Modo Atendimento, Portal do Paciente, Landing, Master e Assinatura.
---

# Plano de testes — Remodelagem NexoSaude

**Status:** plano de validação  
**Base de especificação:** `obsidian/specs/2026-09-19-modo-atendimento-portal-design.md` e `obsidian/specs/2026-09-19-landing-master-assinatura-design.md`  
**Objetivo:** validar os fluxos previstos nas especificações sem comprometer isolamento multicínica, privacidade, integridade financeira ou compatibilidade com o plano Firebase Spark.

## 1. Escopo

Este plano cobre:

1. Modo Atendimento para dentistas, psicólogos e owners.
2. Espelho do portal `portal/{token}` e sincronização dos dados.
3. Espelho de disponibilidade `portal_slots/{clinicId}`.
4. Portal público do paciente: consultas, confirmação, pedido de remarcação, débitos, Pix e aviso de pagamento.
5. Regras de segurança e permissões do Firestore.
6. Landing page, área interna, Master, trial e assinatura do owner.
7. Regressões em agenda, prontuário, financeiro, navegação e isolamento multicínica.

Não faz parte deste plano aprovar funcionalidades fora das especificações. Em especial, não se espera remarcação automática pelo paciente, histórico financeiro completo no portal nem envio automático/agendado de WhatsApp. O WhatsApp deve abrir via `wa.me` com texto preparado e envio manual.

## 2. Estratégia e níveis de teste

| Nível | Objetivo | Abordagem |
|---|---|---|
| Unitário | Validar regras puras e transformações de dados | Testes Dart sem Firebase sempre que possível |
| Serviço | Validar sincronização, filtros e orquestração | Mocks/fakes ou Firebase Emulator conforme suporte |
| Regras de segurança | Confirmar quem pode ler/escrever e quais campos | Firestore Emulator, usuários e clínicas de teste |
| Integração | Validar fluxos entre UI, services, espelhos e regras | Ambiente de teste isolado |
| UI/Responsividade | Verificar formulários, estados e navegação | Widget tests sem dependência real de Firebase; validação manual web/mobile |
| Regressão | Garantir que fluxos anteriores continuam funcionando | Suíte existente + cenários críticos deste documento |
| Aceitação | Confirmar os critérios funcionais do spec | Checklist com perfis representativos |

**Princípio:** testes públicos e de segurança devem verificar também acesso direto ao Firestore, sem passar pela interface. Esconder um botão não é controle de acesso.

## 3. Dados e perfis de teste

Preparar dados sintéticos, sem informações reais de pacientes.

### 3.1 Perfis

- **P1 — Superadmin:** usuário autorizado a administrar a plataforma.
- **P2 — Owner A:** proprietário com acesso às clínicas A1 e A2, conforme configuração de teste.
- **P3 — Owner B:** proprietário de outra clínica, sem acesso a A1/A2.
- **P4 — Recepção A1:** funcionário com acesso somente à clínica A1.
- **P5 — Dentista A1:** profissional associado à clínica A1.
- **P6 — Psicólogo A2:** profissional associado à clínica A2.
- **P7 — Usuário autenticado sem clínica autorizada.**
- **P8 — Usuário anônimo.**
- **P9 — Paciente com token público válido.**
- **P10 — Paciente com token antigo, inválido ou revogado.**

### 3.2 Fixtures

Criar, no ambiente de teste:

- Duas clínicas com IDs distintos e configurações distintas.
- Profissionais de odontologia e psicologia.
- Pacientes distintos em cada clínica.
- Agendamentos livres, ocupados, confirmados, cancelados e com pedido de remarcação.
- Cobranças abertas, parcialmente pagas, quitadas e canceladas.
- Tokens públicos válidos e revogados.
- Espelhos de portal e slots com dados controlados.
- Owners com diferentes quantidades de funcionários para validar o cálculo da assinatura.
- Trials válidos, expirando em até três dias e expirados.

Não usar produção para fixtures ou testes destrutivos.

## 4. P0 — Segurança e isolamento multicínica

### 4.1 Acesso administrativo e isolamento

| ID | Cenário | Resultado esperado | Prioridade |
|---|---|---|---|
| SEC-001 | Owner A lê dados de A1/A2 autorizadas | Leitura permitida conforme papel e regra | P0 |
| SEC-002 | Owner B tenta ler documento de A1 diretamente | Leitura negada | P0 |
| SEC-003 | Recepção A1 tenta ler/escrever documento de A2 | Negado | P0 |
| SEC-004 | Usuário sem clínica tenta consultar coleções operacionais | Negado ou sem resultados conforme regra explicitamente definida | P0 |
| SEC-005 | Usuário anônimo tenta acessar pacientes, prontuários e financeiro interno | Negado | P0 |
| SEC-006 | Cliente altera `clinicId` no payload para outra clínica | Escrita negada | P0 |
| SEC-007 | Cliente consulta sem filtro de clínica | Regras não permitem vazamento de dados; serviços seguem o padrão de filtro | P0 |
| SEC-008 | Usuário sem papel administrativo tenta alterar permissões, configuração ou dados de plataforma | Negado | P0 |

Verificar explicitamente `ownerId`, `allowedClinics`, `clinicId` e as funções auxiliares de `firestore.rules`. Confirmar a semântica real do modelo antes de fixar as expectativas finais de owners.

### 4.2 Allowlist das escritas públicas

| ID | Cenário | Resultado esperado | Prioridade |
|---|---|---|---|
| SEC-009 | Anônimo atualiza apenas campo permitido no espelho do portal | Permitido somente se atender à allowlist e às validações definidas | P0 |
| SEC-010 | Anônimo adiciona campo extra ao documento do portal | Negado |
| SEC-011 | Anônimo tenta criar ou excluir `portal/{token}` | Negado |
| SEC-012 | Anônimo tenta alterar valor de cobrança, paciente, clínica ou chave Pix | Negado |
| SEC-013 | Anônimo atualiza `appointments/{id}` para status fora de `Confirmado` e `remarcar` | Negado |
| SEC-014 | Anônimo altera campos do agendamento além do status autorizado | Negado |
| SEC-015 | Token ausente, malformado, inválido ou revogado tenta usar fluxo público | Não acessa dados privados nem consegue efetuar operações autorizadas apenas ao token válido |
| SEC-016 | Usuário tenta acessar anamnese ou dados clínicos usando somente ID previsível | Nenhum acesso além do comportamento público expressamente autorizado |

Testar a allowlist com `diff().affectedKeys().hasOnly(...)` e verificar também tipos, formato e transições permitidas. A allowlist de campos, por si só, não substitui a validação de valores e vínculos.

### 4.3 Privacidade e LGPD

- Confirmar que o espelho contém apenas as próximas três sessões, débitos em aberto e chave Pix prevista no spec.
- Confirmar ausência de histórico completo, prontuário, anamnese e dados de outros pacientes.
- Confirmar que o consentimento para exibir informação financeira por link é informado e registrado conforme a especificação.
- Confirmar que logs, erros e URLs não expõem tokens ou conteúdo clínico desnecessário.
- Confirmar que revogar o token torna o link antigo inutilizável imediatamente, inclusive após recarregar a página.
- Confirmar que a emissão de novo token não mantém o anterior válido por engano.

## 5. P1 — Modo Atendimento

### 5.1 Visão “Meu dia”

| ID | Cenário | Resultado esperado |
|---|---|---|
| ATD-001 | Dentista entra em Atendimento | Vê somente consultas do dia e do escopo autorizado |
| ATD-002 | Psicólogo entra em Atendimento | Vê somente consultas do dia e do escopo autorizado |
| ATD-003 | Profissional tem consultas em outras clínicas | Não vê consultas de clínica não selecionada/não autorizada |
| ATD-004 | Consulta pertence a outro profissional | Não aparece na visão pessoal se o filtro por profissional se aplica |
| ATD-005 | Dia sem consultas | Estado vazio claro, sem erro |
| ATD-006 | Falha de rede/carregamento | Mensagem de erro e possibilidade de tentar novamente |
| ATD-007 | Usuário troca de clínica | A tela atualiza e não conserva dados da clínica anterior |

Verificar filtros de `clinicId`, `dentistId == uid` quando aplicável e intervalo de data do dia corrente. Testar limites de início/fim do dia e fuso horário para evitar omissão ou duplicação de consultas.

### 5.2 Ficha de atendimento

| ID | Cenário | Resultado esperado |
|---|---|---|
| ATD-008 | Profissional abre uma consulta do dia | Ficha exibe paciente e dados permitidos da consulta correta |
| ATD-009 | Registra evolução usando modelo fixo | Evolução salva via `ClinicalRecordService` no destino já utilizado pelo prontuário |
| ATD-010 | Registra texto livre | Texto é preservado e associado ao paciente/consulta corretos |
| ATD-011 | Falha ao salvar evolução | Erro explícito; não mostrar sucesso falso nem apagar texto digitado |
| ATD-012 | Cria cobrança pela ficha | Lançamento é criado via `FinancialService` com vínculo e valor corretos |
| ATD-013 | Abre Pix após gerar cobrança | Dados correspondem à cobrança criada; não cria duplicidade ao reabrir |
| ATD-014 | Agenda próxima sessão | Usa `AppointmentService.add` e valida disponibilidade |
| ATD-015 | Próxima sessão tem conflito | Operação é bloqueada ou solicita novo horário; não gera duplo agendamento |
| ATD-016 | Abre confirmação via WhatsApp | Abre `wa.me` com texto esperado; envio continua manual |
| ATD-017 | Usuário não autorizado tenta abrir ficha de outro profissional/paciente | Acesso negado conforme regra do projeto |

Validar o fluxo completo: abrir consulta → registrar evolução → criar cobrança → agendar próxima sessão. Confirmar que cada etapa grava uma única vez e que uma falha intermediária não gera lançamentos ou consultas duplicadas.

### 5.3 Tema e navegação

- Confirmar que Atendimento aparece somente para os papéis previstos.
- Confirmar que o filtro por tipo de clínica e profissional é respeitado.
- Confirmar compatibilidade com tema claro/escuro via `AppColors`.
- Verificar que a tela não cria coleções novas e não executa leituras desnecessárias de toda a coleção.
- Verificar responsividade, rolagem, teclado e estados de carregamento.

## 6. P1 — Espelho do portal do paciente

### 6.1 Token

| ID | Cenário | Resultado esperado |
|---|---|---|
| POR-001 | Criar paciente com token | Token gerado no formato de 32 caracteres definido no spec |
| POR-002 | Criar muitos tokens de teste | Tokens são únicos; nenhuma colisão é aceita silenciosamente |
| POR-003 | Revogar token | Novo token é gerado e o anterior deixa de funcionar |
| POR-004 | Token vazio ou malformado | Portal mostra erro seguro e não revela dados |
| POR-005 | Token copiado de outro paciente | Só permite visualizar o espelho associado ao token correspondente |

Verificar que o mecanismo de geração usa aleatoriedade criptograficamente adequada disponível no ambiente. A unicidade observada em um teste pequeno não prova, sozinha, segurança criptográfica.

### 6.2 Sincronização do espelho

Validar `syncPortalMirror()` para cada mutação de origem prevista:

- Criar/agendar consulta.
- Confirmar consulta.
- Cancelar consulta.
- Criar lançamento financeiro.
- Registrar baixa/pagamento.
- Cancelar lançamento.
- Aprovar remarcação.
- Revogar/renovar token, conforme o fluxo implementado.

| ID | Cenário | Resultado esperado |
|---|---|---|
| POR-006 | Criar consulta futura | Espelho reflete as próximas três sessões corretas |
| POR-007 | Alterar status da consulta | Status do espelho é atualizado |
| POR-008 | Cancelar consulta | Consulta não aparece como ativa indevidamente |
| POR-009 | Criar débito aberto | Débito aparece com vencimento e valor corretos |
| POR-010 | Registrar pagamento parcial | Saldo no espelho reflete a regra financeira real |
| POR-011 | Quitar ou cancelar débito | Débito deixa de ser apresentado como aberto conforme regra definida |
| POR-012 | Alterar dado de origem | Nenhum espelho fica com dados antigos após fluxo bem-sucedido |
| POR-013 | Ocorre falha durante sincronização | Falha é observável; não declarar consistência sem confirmação |
| POR-014 | Novo ponto de escrita que altera dados espelhados é adicionado | Teste/revisão detecta necessidade de chamar o helper de sincronização |

Criar testes unitários de fixtures → espelho esperado. Manter uma lista explícita dos pontos de escrita que precisam sincronizar o portal e revisá-la quando novos fluxos forem implementados.

## 7. P1 — Espelho de disponibilidade e remarcação

### 7.1 Janela de slots

| ID | Cenário | Resultado esperado |
|---|---|---|
| SLOT-001 | Executar `ensureSlotsWindow()` | Janela contém os 14 dias previstos, sem datas passadas |
| SLOT-002 | Entrar no app com janela incompleta | Dias faltantes são completados |
| SLOT-003 | Executar rebuild após alteração da grade | Espelho reflete a grade atual |
| SLOT-004 | Agendar ou bloquear horário | Slot é removido do espelho |
| SLOT-005 | Cancelar ou desbloquear horário | Slot livre é restaurado sem duplicação |
| SLOT-006 | Dois clientes tentam propor o mesmo slot | O espelho pode ficar momentaneamente desatualizado, mas a aprovação revalida a fonte viva |
| SLOT-007 | Horário fora da janela de 14 dias | Não pode ser proposto no portal |
| SLOT-008 | Slot não pertence ao profissional/clínica esperados | Proposta é recusada |

Verificar os limites da grade v1 (08:30–20:00, intervalos de 30 minutos) conforme a especificação e os dados reais. Testar início/fim da janela e mudanças de data.

### 7.2 Solicitar, aprovar e recusar remarcação

| ID | Cenário | Resultado esperado |
|---|---|---|
| REM-001 | Paciente escolhe horário livre exibido | Pedido é registrado como pendência, sem remarcação automática |
| REM-002 | Paciente tenta propor horário ocupado na fonte viva | Aprovação é bloqueada após revalidação |
| REM-003 | Recepção/profissional aprova horário ainda livre | Agendamento e espelho são atualizados corretamente |
| REM-004 | Recepção/profissional recusa proposta | Paciente recebe orientação pelo fluxo previsto e proposta é marcada como recusada |
| REM-005 | Proposta recusada pelo paciente A | Some das opções de A, mas continua disponível para outros pacientes |
| REM-006 | Usuário sem permissão tenta aprovar pedido | Operação negada |
| REM-007 | Aprovação repetida ou clique duplicado | Não cria duas consultas nem corrompe o espelho |
| REM-008 | Pedido antigo aponta para sessão inexistente/cancelada | Erro controlado; não altera outra sessão |

O espelho de slots é consultivo. A verificação final deve consultar a disponibilidade viva por meio do fluxo autoritativo (`getBusySlots` ou equivalente) imediatamente antes de aprovar.

## 8. P1 — Confirmação e aviso de pagamento no portal

| ID | Cenário | Resultado esperado |
|---|---|---|
| PUB-001 | Paciente confirma consulta válida | Somente status autorizado é atualizado |
| PUB-002 | Paciente pede remarcação | Pedido vira pendência; horário não muda automaticamente |
| PUB-003 | Paciente informa que pagou | Gera aviso/pendência, não baixa a cobrança |
| PUB-004 | Paciente envia aviso repetidamente | Não causa baixa duplicada nem corrupção de estado |
| PUB-005 | Paciente tenta alterar valor ou situação financeira | Escrita negada |
| PUB-006 | Paciente acessa token revogado | Nenhum dado do portal é exibido |
| PUB-007 | Página recarrega após confirmação | Exibe o estado persistido real |
| PUB-008 | Falha de rede durante ação | Mensagem apropriada; UI não apresenta confirmação falsa |
| PUB-009 | Portal não tem sessões ou débitos | Estado vazio claro, sem falha de renderização |

Confirmar que o texto público não promete pagamento confirmado quando houve apenas aviso do paciente. A baixa definitiva continua no app interno.

## 9. P1 — Landing, Master, trial e assinatura

### 9.1 Landing e rota interna

| ID | Cenário | Resultado esperado |
|---|---|---|
| LND-001 | Acessar `/` | Landing é exibida; não redireciona para o site externo aposentado |
| LND-002 | Clicar em “Testar 7 dias grátis” | Exibe o fluxo v1 previsto, sem auto-cadastro não especificado |
| LND-003 | Clicar em “Entrar” | Navega para `/sistema-interno/` |
| LND-004 | Acessar rota interna diretamente | Aplicação interna continua carregando |
| LND-005 | Navegar/recarregar rotas | Hosting não quebra landing nem SPA |

### 9.2 Master e permissões

| ID | Cenário | Resultado esperado |
|---|---|---|
| MAS-001 | Usuário `superadmin` entra no app | Menu Master disponível |
| MAS-002 | Owner/recepção/profissional acessa Master por URL ou Firestore direto | Acesso negado |
| MAS-003 | Master lista owners | Lista e detalhes correspondem aos dados autorizados |
| MAS-004 | Master bloqueia clínica | `blockedByAdmin` persiste e bloqueia acesso conforme regra |
| MAS-005 | Master libera clínica | Bloqueio manual é removido e acesso volta se não houver outra restrição |
| MAS-006 | Master gera mensalidade | Débito é criado com owner, valor e vencimento corretos |
| MAS-007 | Master dá baixa em débito | Status e valores são atualizados de forma consistente |
| MAS-008 | Master dispensa débito | Dispensa fica registrada sem confundir com pagamento |
| MAS-009 | Trial expira em até três dias | Clínica aparece na lista de alerta correspondente |
| MAS-010 | Trial expirado | Clínica aparece como expirada e login é bloqueado conforme especificação |

### 9.3 Trial e bloqueio de login

- Trial válido permite entrada.
- Trial expirado bloqueia entrada e apresenta mensagem explicativa.
- Bloqueio manual impede entrada mesmo com trial vigente.
- Remover bloqueio manual não reativa automaticamente um trial expirado.
- Usuário sem permissão não consegue alterar `trialEndsAt` nem `blockedByAdmin`.
- Testar limites de data, horário e fuso, incluindo expiração exatamente no instante de corte.
- A aplicação não deve depender apenas de esconder telas: verificar o acesso aos dados e operações protegidas.

### 9.4 Cálculo de assinatura

Regra do spec: `40 + 15 × (n − 1)`, em que `n` é a quantidade de staff das clínicas do owner; o owner não conta.

Casos mínimos:

| ID | Quantidade de staff (n) | Valor esperado pela fórmula | Observação |
|---|---:|---:|---|
| ASS-001 | 1 | R$ 40,00 | Caso base |
| ASS-002 | 2 | R$ 55,00 | Um staff adicional |
| ASS-003 | 5 | R$ 100,00 | Quatro adicionais |
| ASS-004 | 0 | A confirmar | A fórmula documentada pressupõe n ≥ 1; definir comportamento para zero antes de implementar |
| ASS-005 | Owner + 2 staff | R$ 55,00 | Owner não entra na contagem |
| ASS-006 | Staff distribuídos em várias clínicas do mesmo owner | Contar conforme escopo do owner, sem duplicar usuários |
| ASS-007 | Staff de outro owner | Não entra no cálculo |
| ASS-008 | Mensalidade gerada | Vencimento conforme regra do spec (30 dias) e débito sem duplicidade indevida |

A regra de arredondamento, o tratamento de usuário desativado/pendente e a definição exata de “staff das clínicas dele” devem ser confirmados no código e na regra de negócio. Registrar a decisão no resultado dos testes.

### 9.5 Pagamento de assinatura

- Owner consulta somente seus próprios débitos.
- Owner pode registrar `avisoPagamento` nos limites permitidos.
- O aviso não representa baixa definitiva.
- Superadmin visualiza o aviso e realiza a baixa administrativa.
- Owner não consegue alterar valor, vencimento, status final ou débitos de outro owner.
- `platform_config/geral` tem leitura e escrita conforme permissões definidas no spec.
- Valores e chave Pix exibidos vêm da configuração autorizada, não de dados controlados pelo cliente.

## 10. Regressão dos fluxos existentes

Antes da entrega, executar regressão dos seguintes fluxos:

- Login e resolução de papel/clínica.
- Troca de clínica e atualização de tela.
- Agenda: criar, editar, confirmar e cancelar.
- Pacientes: cadastro, busca e ficha.
- Prontuário e evolução clínica.
- Cobranças: criação, baixa, cancelamento e saldo.
- Psicologia: sessões avulsas e pacotes, presença, falta com atestado e cobrança mensal conforme regras existentes.
- Menu por tipo de clínica e `menuAccess`.
- Tema claro/escuro onde já suportado.
- Landing e rota `/sistema-interno/`.
- Páginas públicas existentes de confirmação e anamnese.
- Isolamento multicínica em leituras e escritas.

Mudanças na remodelagem não podem quebrar as regras já estabelecidas para cobrança de pacotes de psicologia, cancelamento de contrato ou consultas por clínica.

## 11. Testes de responsividade e acessibilidade

Para Modo Atendimento, portal e landing:

- Testar larguras de 320, 360, 390 e 430 px e uma largura desktop.
- Verificar ausência de overflow horizontal.
- Verificar formulários com teclado virtual aberto.
- Verificar mensagens longas, estados vazios e erros de rede.
- Confirmar contraste, rótulos acessíveis, foco e áreas de toque.
- Confirmar que informações financeiras e clínicas não ficam visíveis em componentes destinados a perfis não autorizados.
- Testar navegação por teclado na web quando aplicável.

Registrar manualmente os dispositivos/navegadores realmente usados. Não afirmar compatibilidade com uma plataforma que não foi testada.

## 12. Automação recomendada

1. **Unitários Dart:** token, montagem do espelho, cálculo financeiro, cálculo de assinatura, helpers de slots e regras de transformação.
2. **Firestore Emulator:** matriz de leitura/escrita por papel, clínica, token e allowlist.
3. **Serviços:** sincronização do espelho e chamadas dos services nos pontos de mutação.
4. **Widget tests:** estados de carregamento, vazio, sucesso e erro; não depender de Firebase real se o padrão do repositório não suportar isso.
5. **Smoke tests web:** landing, rota interna e páginas públicas.
6. **Checklist manual:** confirmação/remarcação no portal, fluxo completo de atendimento, responsividade e permissões.

Evitar testes que dependam de dados reais, relógio não controlado, rede externa ou estado compartilhado. Fixar relógio e fixtures quando necessário.

## 13. Critérios de saída

A remodelagem pode ser considerada pronta para revisão quando:

- Todos os testes P0 de segurança passam.
- Nenhum perfil consegue atravessar o isolamento entre clínicas.
- As escritas públicas estão restritas por allowlist e validação de valores/transições.
- Revogação de token invalida o link antigo.
- A sincronização do portal cobre todos os pontos de escrita documentados.
- A aprovação de remarcação revalida a disponibilidade viva.
- Aviso de pagamento não equivale a baixa financeira.
- O Modo Atendimento completa evolução, cobrança e próxima sessão sem duplicações.
- Landing, Master, trial e assinatura cumprem os critérios dos specs.
- Regressões críticas foram executadas.
- `flutter analyze` não apresenta erros introduzidos pela entrega.
- Pendências, limitações do ambiente e riscos residuais estão registrados.

Falha em teste P0 bloqueia a liberação. Falhas não críticas devem ser documentadas com impacto, responsável/próximo passo e decisão explícita de aceite.

## 14. Comandos de validação

Executar no ambiente de desenvolvimento, conforme ferramentas disponíveis:

```bash
flutter pub get
flutter analyze
flutter test
```

Executar os testes do Firebase Emulator usando a configuração e os scripts já existentes no repositório. Não inventar um comando de Emulator sem verificar `firebase.json`, dependências e scripts atuais.

Antes de qualquer deploy, revisar as regras e os índices propostos, verificar o diff e obter autorização explícita. Este plano não autoriza deploy em produção.

## 15. Evidências e relatório de execução

O relatório final deve registrar:

- ID de cada teste executado e status: passou, falhou, bloqueado ou não executado.
- Ambiente, perfil e fixture usados.
- Evidência do resultado sem incluir dados pessoais reais.
- Defeitos encontrados e links para issues/commits quando houver.
- Comandos executados e saída resumida.
- Testes pendentes e justificativa.
- Riscos residuais e decisão sobre bloqueio da entrega.

Não marcar como aprovado um teste apenas porque a tela carregou. Para segurança, a evidência deve demonstrar tanto o acesso legítimo quanto a negação do acesso indevido.
