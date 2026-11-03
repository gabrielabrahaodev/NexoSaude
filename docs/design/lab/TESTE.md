# Laboratório — validação PR #2

1. Receber pagamento: não deve existir Gerar Pedido, laboratório, previsão ou custo de laboratório no formulário; repasse e custos operacionais gerais continuam independentes.
2. Menu Laboratório: verificar quatro colunas, contagens reais, busca por paciente/ID/descrição/tipo e filtros por laboratório/profissional/tipo. Exportar respeita os filtros e gera CSV seguro.
3. Paciente → Laboratório: mesmos componentes, apenas pedidos daquele paciente, sem nova rota/dashboard.
4. Novo Pedido sem custo: informar paciente (fixo na ficha), fornecedor Laboratório, descrição e responder Não. Confirmar pedido nos dois kanbans e ausência de nova conta.
5. Novo Pedido com custo: informar valor como `1.234,56`, vencimento e responder Sim. Confirmar um pedido e uma conta pendente de R$ 1.234,56 em Relatórios → A Pagar no mês escolhido. A conta deve mostrar paciente/fornecedor/descrição. Só baixar como paga pelo financeiro; o custo não altera a cobrança/receita do paciente.
6. Falha na criação: formulário mantém campos e permite retry; não pode existir pedido parcial nem conta duplicada. Reenviar o mesmo ID não desfaz baixa prévia. Cliques repetidos ficam bloqueados enquanto salva.
7. Movimentar pedido por arraste/menu: confirmar data, conferir espelho na outra tela, histórico e interações. Mover status não cria outra conta.
8. Estornar/cancelar recebimento: pedidos (inclusive legados com relatedFinancialId) permanecem; custos de laboratório não são excluídos. Excluir pedido pelo kanban mantém a conta e informa isso na confirmação.
9. Trocar clínica/paciente: não deve aparecer pedido da unidade anterior. Tentar vínculo de laboratório/paciente/plano de outra clínica deve falhar sem gravação parcial.
10. Conferir geral e individual em claro/escuro, larguras 320/390/768/1200/1440. No celular, rolar a página/coluna para acessar ações e deslizar horizontalmente entre etapas.

Dados não inventados: IDs internos não exibidos nos cartões; ausência de urgência/horário específicos; atraso pela data; dados antigos sem tipo/fornecedor/solicitante/custo explícito ficam Não informado. Não há criação retroativa automática de despesas para pedidos legados.

Testes: `flutter test`; `flutter analyze --no-pub`; `flutter build web --release --no-pub`; `firebase emulators:exec --only firestore --project nexosaude-test "npm --prefix test/rules test"`. Nenhuma publicação de Rules ou dados de produção faz parte desta revisão.

Validação concluída: **377 testes Flutter aprovados**, **37 testes de autorização no emulador aprovados**, análise estática com **0 erros** (213 avisos/informações remanescentes) e build Web release concluído. As prévias do kanban foram renderizadas e inspecionadas nos modos claro e escuro.


## Ajustes de cabeçalho, OS e arraste

- Cabeçalho de todas as telas sem nome do usuário; identidade permanece no rodapé do menu.
- Cartões e título dos detalhes sem número/ID de OS; busca indica paciente ou trabalho.
- Mouse: clicar e arrastar diretamente, sem segurar primeiro. Toque: manter pressionado por 300 ms e arrastar até a coluna. Confirmar a data no diálogo para gravar a etapa.
- Verificar Enviado, Aguardando Retorno e Entregue no geral e no paciente; mover não cria custo nem altera a conta existente. Regressão por gesto real em `lab_drag_drop_test.dart`, com serviço de gravação controlado, nos dois temas.
