# Gestão Operacional — referência screen(9).png/code(6).html

## Implementação
Cabeçalho e navegação tonal em cinco abas, na mesma ordem e conforme permissões g_proc/g_estoque/g_forn/g_cart/g_config. Tela inicial Procedimentos (se liberada). Busca por nome/categoria/repasse/flags, filtro por categoria real e cartões com valor, repasse, custo e mensalidade. Os dois botões de criação abrem o mesmo formulário. Edição preserva active; exclusão requer confirmação. Temas claro e escuro usam superfícies locais. Estoque, Fornecedores, Cartões e Configurações mantêm suas funções e recebem o tema da área, incluindo Pix, conta, grade, aparência e acesso.

## Conferência manual
1. Na Gestão, conferir abas permitidas como owner e equipe restrita; não revelar aba bloqueada.
2. Em 320/390/768/1040/1440 px, testar busca, categoria, nenhum resultado, criação pelos dois botões, edição e cancelar exclusão. Cartões se empilham e abas rolam horizontalmente.
3. Conferir preço e repasse com catálogo real. Testar percentuais, valor fixo, custo, mensalidade e procedimento inativo.
4. Testar falha ao salvar e repetição de clique; o formulário mantém dados e apresenta erro. Troca de unidade bloqueia salvamento de formulário antigo.
5. Mudar para claro e escuro na Configuração; confirmar tema de cartões, filtros e formulários sem perda de aba.
6. Conferir os cadastros existentes de estoque, fornecedores, cartões, Pix, grade e permissões.

## Diferenças do exemplo
Não são inventados rótulos Preventivo/Especializado, repasse nominal por profissional, sincronização 100%, servidor online ou contagem fixa de estoque crítico. Categoria e repasse são os cadastrados. O menu/logo e usuário no rodapé permanecem os aprovados no sistema. A referência mostra Procedimentos, não o conteúdo da aba Configurações; suas seções funcionais existentes foram preservadas.

## Validação
Diff sem erros de whitespace. Testes de widget de busca/categoria/ações nos dois temas adicionados. Flutter, build e renderização não executados nesta revisão: SDK não disponível no ambiente. Avaliação autenticada necessária antes de publicação em produção.
