# Aba Orçamentos — PR #2

Referências: screen(3).png, code(2).html e DESIGN(3).md recebidos em 31/10/2026. O conteúdo da aba segue os cartões/cores/proporções da referência e usa os dados reais; logo, menu, cabeçalho sem usuário, seleção de unidade e tema aprovados são preservados.

## Conferência

1. Pacientes → selecionar cadastro → Orçamentos. Conferir CTA azul, filtros com contagens reais, busca, impressão e cartões em claro/escuro. A rolagem pertence à ficha, sem uma área fixa de 1.000px.
2. Conferir proposta pendente expandida: tabela com procedimento/região/quantidade/unitário/desconto/subtotal, total, condições reais e Aprovar e Gerar Tratamento. Aprovados usam cartão compacto e Ver Tratamento; não mostrar assinatura ou quitação sem registro.
3. Filtrar por status e procedimento/título/valor. Contagens são da lista completa; impressão do filtro usa somente as propostas visíveis. Erro de leitura deve ser explícito.
4. Novo Orçamento Clínico: catálogo ativo da clínica; pesquisar, adicionar/remover itens, editar descrição/região/quantidade/preço/desconto. Testar 1.234,56, quantidade inteira e desconto de 0–100%. Subtotal/total devem bater com os campos gravados. Rascunho e foco permanecem ao digitar.
5. Escolher validade/condições/forma/parcelas se necessário. São sugestões da proposta; a aprovação usa o assistente financeiro existente. Não há envio automático ao paciente pelo botão Salvar Orçamento.
6. Salvar: impedir duplo clique/edição/fechar durante a gravação. Falha conserva itens e permite retry com o mesmo ID. Não salvar se a clínica/paciente mudou.
7. Aprovar pelo wizard e conferir um plano e seus lançamentos, valores líquidos por linha preservados e metadados de região/quantidade/desconto no plano. Ver Tratamento vai para a aba existente, priorizando o plano vinculado.
8. Excluir: manter confirmação; aprovado usa a cascata já existente de tratamentos/financeiro/custos. Cancelar deve manter os dados.
9. Imprimir Proposta e imprimir filtro: conferir PDF, português, totais e condições. O PDF é proposta, não recibo.
10. Compartilhar Link copia somente URL pública HTTPS já registrada. Sem URL, botão indisponível com explicação. Recibo só aparece com URL real e plano concluído; caso contrário, Ver Tratamento.
11. Testar 390/768/1200px nos dois temas, inclusive texto longo, vários itens e lista vazia. Tabela rola horizontalmente no celular. Trocar unidade/paciente não deve mostrar ações ou gravações do anterior.

## Informações da imagem sem equivalente garantido

Não há geração automática de numeração ORC sequencial, link público de proposta, assinatura biométrica, carimbo de execução/quitado nem códigos TUSS no catálogo atual. Metadados já gravados são respeitados; dados ausentes não são inventados. Validade/condições/parcelamento passam a ser opcionais na criação. Desconto e região ausentes em antigos ficam identificados. O desconto é armazenado por linha sem mudar o significado financeiro de price.

Testes novos: budget_presentation_test, clinical_budgets_view_test e budget_create_dialog_test. Dois testes antigos de Atendimento usam finder por subtipo de FilledButton para compatibilidade com Flutter 3.38+; produto/ações de Atendimento não foram alterados. Prévias dos dois temas renderizadas e inspecionadas.

Validação: **435 testes Flutter aprovados**, incluindo **20 novos testes de Orçamentos**, análise estática com **0 erros** e build Web release concluído com Flutter 3.38.7 / Dart 3.10.7 (compatível com pubspec). Prévias renderizadas nos dois temas. Dependências, índices e Rules preservados; nenhuma gravação em produção ou deploy.
