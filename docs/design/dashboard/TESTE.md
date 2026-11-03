# Dashboard Clinical Precision

Referência: screen(7).png e code(5).html. Quatro indicadores, exceções, vencimentos e coluna de unidade/aniversariantes. Cores adaptadas aos temas claro e escuro; menu/logo compartilhados preservados.

## Conferência autenticada
- Abrir Dashboard em duas clínicas autorizadas, odontologia e psicologia. Não exibir dados da unidade anterior. Não alterar documentos durante leitura.
- Conferir saldo mensal e atraso com financial: amount menos paidAmount, apenas receitas pendentes/parciais/cobradas, excluindo quitadas. O painel exibe saldo registrado; a apuração de presença dos pacotes permanece na régua de Cobranças.
- Conferir cinco vencimentos mais antigos (sem data ao final), aniversariantes cadastrados e agendamentos confirmados de hoje. Exceções: vencidos há sete dias, não confirmados e agendamentos confirmados com dívida.
- Novo agendamento abre o formulário correto por especialidade. Detalhes abre Relatórios; Cobranças/lembretes abre a régua manual (não dispara mensagens); Pacientes e Agenda abrem os módulos correspondentes.
- Conferir 320, 390, 768, 1040 e 1440 px nos dois temas. Falha de leitura deve exibir erro, nunca números zerados de sucesso.

## Dados ausentes da referência
Não há telemetria de consultórios, plantão de profissionais, servidor online, taxa histórica de inadimplência/crescimento nem gatilho automático de aniversários. Não são exibidos números simulados para esses campos. O painel de unidade informa ausência de ocupação e oferece Agenda. A competência é o mês atual; atalhos de período/busca globais ilustrativos não foram adicionados ao shell compartilhado.

## Validação nesta revisão
Testes de widget adicionados para temas, responsividade e ações. Execução de Flutter/build pendente: SDK e cache não disponíveis neste ambiente; download do SDK retornou HTTP 404. Resultados anteriores da PR não validam esta alteração.
