---
title: Patient Details
tags:
  - nexosaude
  - brain
  - screens
name: screen-patient-details
description: Ficha do paciente com tabs dinâmicas por tipo de clínica.
---

# PatientDetailsScreen

`lib/screens/patients/patient_details_screen.dart`

## O que é

`TabBar` cujo tamanho vem de `ClinicCapabilities.patientTabCount` (dental 9, psicologia 6).

## Quando usar

Adicionar/remover aba, mudar visibilidade por tipo.

## Fluxos

- Abas condicionais: `canShowBudgets/Odontogram/Lab`; `_buildVisualTab` cai em placeholder fora da dental.

## Gotchas

- `TabBar` e `TabBarView` precisam ter os mesmos `if`s na mesma ordem — divergência quebra o índice.

## Atualizações

- Aba Cadastro: seção Portal em máquina de estados — sem aceite não há link nem cópia; gerar exige diálogo LGPD (grava `accepted/at/via/by`); revogar mata espelho + limpa token + `accepted:false`/`revokedAt`. Data do aceite exibida no cartão. Excluir paciente apaga o espelho na cascata. Ver [[portal-page]], [[portal-mirror]].

## Variante Clinical Dark — PR #2

`clinical_patient_screen.dart` compõe a ficha com menu global/unidade, identificação real, CPF mascarado, selo LGPD somente com `lgpdPortalConsent.accepted == true`, abas por `ClinicCapabilities`, indicadores, contexto e conteúdo em uma rolagem vertical. Abertura pela lista inicia em Cadastro para todas as especialidades; deep-links continuam respeitando `initialTab` (inclusive Prontuário e Pagamentos), e psicologia mantém seis abas.

Odontograma exibe somente o mapa dental. Planos em execução aparecem exclusivamente em Tratamentos; livro caixa e cobranças, exclusivamente em Pagamentos. Novo tratamento conduz ao fluxo existente de Orçamentos. Receber pagamento leva às cobranças reais para escolher o lançamento; nenhum valor do HTML é usado. A tabela preserva famílias de parcelamento e opções de estorno/cancelamento, sem oferecer recibo inexistente. Custos e repasses continuam acessíveis após as cobranças.

A rota reutiliza o shell do dashboard com conteúdo de detalhe; troca de menu ou unidade encerra a exibição da ficha antiga. Leitura inicial de paciente e todos os indicadores usam escopo da clínica. Consultas/streams dos indicadores são preparados uma vez na montagem. Os valores da referência e percentuais de assiduidade não são inseridos como dados reais.

Componentes puros em `clinical_patient_view.dart` permitem verificar identidade, ações financeiras, tratamento e odontograma sem Firebase. A flag `AGENDA_CLINICAL_DARK=false` mantém a ficha anterior para comparação.

## Cadastro e Tratamentos conforme referências corrigidas

Cadastro usa cinco cartões: Dados Pessoais e Documentação & Conformidade na coluna esquerda; Localização & Endereço, Contato de Emergência e Preferências de Atendimento na direita. No mobile empilha os cartões. Editar Dados habilita campos; Salvar Alterações grava um patch de cadastro, preserva endereço legado e metadados de mapas e não altera consentimento, token, clínica ou dados clínicos/financeiros. Novos campos são opcionais: nome social, profissão, e-mail, sexo, estado civil, emissor do RG, CNS, endereço estruturado, emergência e preferências.

Buscar CEP consulta ViaCEP sob clique; falhas deixam preenchimento manual disponível. Respostas atrasadas após cancelamento, alteração do CEP ou troca da unidade são descartadas. O indicador de CPF válido é validação local dos dígitos; não representa consulta à Receita Federal. O termo em PDF só abre quando há uma URL HTTPS registrada em `lgpdConsentDocumentUrl`. O ícone de link na caixa LGPD abre os controles de consentimento do portal já existentes.

Tratamentos usa o título, botão Novo Tratamento, margem à direita, valores em BRL com vírgula, progresso à direita e botões Receber Parcela / Ver Dentes Vinculados / Encerrar Tratamento da referência. Dentes vinculados são apenas referências explícitas existentes no plano/itens; sem referência, o diálogo informa ausência de vínculo e oferece abrir o odontograma. Não deduz vínculos pelo nome do procedimento.

## Foco e leitura contínua do cadastro

`PatientDetailsTab` mantém a assinatura do documento preparada em `initState`, reutilizando o stream durante os rebuilds de digitação. Só troca a assinatura quando muda o paciente ou a fonte de dados. Atualizações recebidas enquanto edita não substituem o rascunho; cancelar recarrega o último snapshot. Teste de regressão digita letra a letra em 390/1200px e confere foco, posição do cursor e uma única assinatura, além de receber uma atualização remota durante a edição.


## Temas claro e escuro — PR #2

A apresentação clínica respeita `ThemeController`/`AppColors.isDark`, incluindo Agenda, Atendimento, menu e ficha do paciente. O seletor de sol/lua fica abaixo de Sair no rodapé do menu lateral (desktop e drawer mobile); usa a mesma preferência de Gestão → Configurações → Aparência e sincroniza por usuário. Superfícies, textos, campos, destaques e botões têm cores para ambos os modos. Trocar o tema não troca a aba nem recria o formulário ou a leitura do paciente. O logo original é preservado.

O odontograma colore apenas as faces registradas, destaca o número FDI e enquadra restaurações e procedimentos de raiz conforme a referência. A raiz usa preenchimento tonal e o dente extraído recebe um X. A legenda compartilha a mesma paleta dos dentes; tons no modo claro priorizam contraste. Não há procedimentos ou dentes de exemplo adicionados aos dados reais.


Pela lista do dashboard, a ficha usa `embedded: true` e callback `onBack`: retorna apenas o conteúdo do painel e não cria `MainWebDashboard`. `PatientWorkspace` mantém o shell existente e a lista; o botão Voltar retorna à mesma busca. O modo independente permanece para deep-links externos.


## Visibilidade dos resumos por aba — 31/10/2026

Resumo de contexto (`PatientSmartContextCard`) somente em Cadastro. Os quatro indicadores de assiduidade/a receber/recebido/custo operacional (`_metrics`) somente em Pagamentos. As demais abas não montam esses blocos nem reservam o espaço deles. Identificação e navegação permanecem compartilhadas. A regra também vale para o layout anterior (`AGENDA_CLINICAL_DARK=false`), com contexto na primeira aba e resumo na última, sem depender dos índices específicos de odontologia/psicologia. Dados, cálculos e ações são preservados.

- Prontuário (03/11/2026): visual ClinicalRecordsView com filtros e contagens reais por categoria, ordenação e cards de evolução/cancelamento/administrativo. Cancelamento legado mostra operador, nunca dentista responsável. Editar preserva autor/data, grava editedBy/editedAt; sem anexos/orçamentos ilustrativos. Detalhes e validação pendente em docs/design/patients/PRONTUARIO.md.
