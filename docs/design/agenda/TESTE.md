# Agenda alternativa — Clinical Precision Dark

PR de avaliação sobre `nova-audit`, restrita à Agenda, integração de profissionais e sua navegação enquanto aberta. A expansão do conceito para outras telas depende da aprovação após os testes. Não publicar em produção para testar.

## Executar no Windows / PowerShell

Na raiz do NexoSaúde, com alterações locais já salvas em commit:

```powershell
git fetch origin
git switch feat/agenda-clinical-dark
git pull --ff-only origin feat/agenda-clinical-dark
flutter pub get
flutter run -d chrome
```

A Agenda inicia com o visual alternativo nesta branch. Para comparar com a versão anterior, encerre a execução e rode:

```powershell
flutter run -d chrome --dart-define=AGENDA_CLINICAL_DARK=false
```

## O que conferir

- Desktop 1024/1440: sidebar, filtro real de profissional, navegação entre semanas, Hoje, grade semanal, Dia e seleção do cabeçalho de um dia.
- Tablet 768: a grade continua disponível, sem a sidebar consumir espaço excessivo.
- Mobile 320/360/390/430: lista diária, faixa de dias com rolagem horizontal, botões de 48dp, navegação inferior e menu completo pelo ícone de menu.
- Alterar unidade no seletor; conferir que nomes, consultas e profissional pertencem à unidade escolhida.
- Owner/recepção: o seletor lista donos, dentistas e psicólogos ativos de `clinics/{clinicId}/members`, inclusive aliases de papel. Alterar a seleção e conferir a agenda correspondente. Profissional restrito: conferir que a filtragem existente continua ativa.
- Horário livre: abre o formulário dental ou de psicologia existente. Consulta: abre o menu atual (prontuário, editar, encaixe, finalizar, cancelar e decidir remarcação conforme o estado).
- Bloqueio: abre o desbloqueio existente; conferir bloqueios longos, consultas longas, encaixes, cancelados e domingo.
- Botão Gestão: mantém as ações existentes de agenda e inicia no dia selecionado na visualização diária.
- Falha de conexão/permissão: exibe erro. Carregamento: indicador, sem informar que o dia está vazio antes da resposta.
- Trocar para outra tela: ela mantém o visual atual. Voltar à Agenda: o visual experimental reaparece.

## Relação com as referências

Cores e hierarquia de `DESIGN.md`, `code.html`, `codemobile.html` e imagens fornecidos em 30/10/2026, implementados em Flutter. Não há WebView, CDN Tailwind ou dependências novas. A fonte segue a já disponível no projeto.

Os dados ilustrativos das imagens (pacientes, unidade, especialidade e ocupação de 65%) não são inseridos. A contagem diária usa consultas reais, exclui bloqueios e cancelados. Não se mostra percentual de ocupação sem uma definição de expediente/capacidade. Ações de mensagem, exportação e pesquisa da imagem não viram botões sem implementação.

Domingo é preservado (sete dias), além dos horários extras. Cards com duração ocupam seu intervalo; consultas sobrepostas são distribuídas em faixas. No mobile, os cards aparecem uma vez no início, sem oferecer como livre a continuação de um atendimento ou bloqueio.

## Validação automatizada

```powershell
flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos
flutter test
flutter build web --release
```

`test/clinical_agenda_view_test.dart` cobre larguras, seleção de dia, horário livre, consulta, encaixes, cancelamento, bloqueio e horário fora da janela padrão. Esses testes não substituem o teste autenticado com as clínicas reais.

### Resultado desta implementação

Validação local em Flutter 3.47.9 / Dart 3.13.7:

- 214 testes Flutter aprovados (inclui 23 testes da agenda alternativa, diretório, seletor e formulários).
- Testes específicos de layout repetidos após ajuste final; seleção de dia também atualiza o alvo da Gestão.
- Análise estática: zero erros; 228 avisos/informações no projeto.
- Build web release concluído.
- Prévia renderizada inspecionada em 390 e 1200px; teste autenticado das clínicas e aprovação visual final ficam para a avaliação do usuário.

Não houve alteração de dependências, Rules ou configuração de deploy.


## Correção de paridade funcional

A base inicial `master` ainda usava listagem geral de `users`; a base correta é `nova-audit`, com diretório mínimo de membros. A PR foi alinhada a essa base sem publicar Rules ou substituir as correções existentes de autenticação, portal e armazenamento.

- O diretório de profissionais é um stream da unidade atual. Inclui `owner`, `dentista`, `psicologo` ativos; inglês e `Psicólogo` são normalizados. Recepcionistas não entram como profissionais.
- Dono/recepção podem alternar entre profissionais. Dentista/psicólogo mantêm a própria agenda. A seleção é validada novamente quando membros/status mudam; seleção vazia não libera a agenda de todos.
- Lista vazia e erro de permissão/conexão são distintos; o seletor oferece tentar novamente. Enquanto não há profissional selecionado, criação e Gestão ficam protegidas.
- Células livres e encaixe passam o UID para o formulário correto pelo `AgendaCellFactory`. Psicologia agora preserva `dentistId` no contrato e nas sessões geradas. Agenda dental conserva o UID ao salvar e verifica ocupações por profissional.
- Consultas legadas sem responsável continuam visíveis para a gestão como na agenda original; não há migração nem atribuição automática a alguém.
- Criar uma sessão avulsa/pacote de psicologia e conferir seu aparecimento na agenda do profissional escolhido; editar/finalizar/cancelar continuam delegados aos fluxos existentes.

Os testes automatizados usam dados controlados, sem conexão com clínicas reais. Valide a leitura do diretório e os fluxos de escrita com contas de teste antes de qualquer publicação.
