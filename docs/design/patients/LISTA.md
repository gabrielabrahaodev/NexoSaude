# Lista de pacientes — PR #2

Referência: screen(4).png / code(3).html. Mantém o shell, logo e seletor de tema aprovados; o nome do operador continua somente no rodapé. Sem gravação de dados ilustrativos, dependências, Rules ou índices novos.

## Conferência autenticada

1. Abrir Pacientes em uma unidade. Comparar título, contador real, botões Exportar CSV/Novo Paciente, painel de busca e quatro filtros, ordenação e cartões com a referência. Conferir ambos os temas e 320/390/768/1280px.
2. Buscar nome com/sem acentos, CPF/telefone com e sem pontuação, prontuário registrado. Ctrl/⌘+K deve focar a busca. Digitar uma frase sem perder foco.
3. Combinar filtros: sem aceite LGPD, pendência financeira, plano ativo e orçamento em negociação não expirado. Contagens são da unidade. Ordenar alfabeticamente, por cadastro e por último atendimento finalizado nos últimos 90 dias.
4. Abrir por cartão/botão: somente o painel direito deve mudar, começando em Cadastro. Voltar preserva busca, filtros e ordenação. A lista oculta não recebe atalhos de teclado. Trocar unidade descarta a seleção anterior.
5. Novo Paciente (cabeçalho/flutuante) abre o formulário existente. Menu e pressão prolongada abrem a confirmação de exclusão; cancelar não abre ficha nem exclui.
6. Exportar gera pacientes.csv do conjunto filtrado/ordenado, com CPF integral, campos reais e proteção contra fórmulas. Sem contexto complementar, os campos dependentes ficam vazios; token LGPD não é exportado.
7. Conferir erro/carregamento nas fontes: não manter dados de outra unidade nem converter falha em pendência zero. Filtros complementares ficam indisponíveis até haver dados; retry deve recuperar a leitura.

## Dados que não são presumidos

- 1.248 pacientes, 14 sem LGPD e nomes/valores da imagem são ilustrativos. A tela calcula os dados da unidade.
- Número de prontuário aparece somente quando já registrado. Não existe sequência nova gerada por esta tela.
- Não são presumidos especialidade individual, assiduidade, anamnese pendente ou etapa de prótese no laboratório; os selos usam status cadastrado, plano ativo, orçamento pendente e pendência real.
- Último atendimento usa agendamento Finalizado nos últimos 90 dias. Histórico mais antigo permanece na ficha.
- Não se presume conexão ativa da unidade nem notificações novas pelo desenho da referência.

## Validação

17 testes específicos aprovados: dados, deduplicação, CSV seguro, filtros combinados, ordenação, buscas, ações, Ctrl+K, troca de tema e responsividade. Suíte completa: 452 testes aprovados. Build web release concluído; análise estática sem erros, com avisos/informações já existentes no projeto. Prévias claro/escuro renderizadas para inspeção. Sem merge/deploy; validar dados reais com sessão autenticada antes de produção.
