# Receita Saúde — PR #2

## Fluxo

1. Relatórios → mês/unidade → Receita Saúde (vizinho de Exportar DRE, mesmo estilo).
2. Selecionar profissional prestador. Conferir nome, CPF pessoal, ocupação cadastrada no Carnê-Leão e registro do conselho. Para profissional não vinculado, identificar manualmente. Não utilizar CPF/CNPJ da clínica nem do operador como substituto do prestador.
3. Conferir pagamentos, CPF do beneficiário e de quem realmente pagou; selecionar Pagador é o próprio beneficiário somente quando for o caso. Preencher data efetiva se ausente, sem presumir data de vencimento/antecipação. Pode desmarcar linhas. Ajustes não são gravados no sistema.
4. Relatório PDF gera documento de apoio chamado Receita Saúde, com pendências, valor bruto e dados conferidos. O documento indica que não é recibo oficial/protocolo de envio.
5. CSV para Carnê-Leão exige dados válidos e gera arquivo de escrituração para um profissional/mês. No Carnê-Leão Web, acessar Escrituração, importar, analisar e concluir emissão autenticada. Este botão não acessa conta gov.br nem transmite dados ao governo.
6. Conferir recibos existentes antes de importar: a Receita adiciona lançamentos e não substitui os anteriores. Não marcar como emitido no sistema a partir de mero download.

## Formato

Conforme página oficial Formato do arquivo de Escrituração (verificada 31/10/2026): 16 campos, sem cabeçalho, ponto e vírgula, CRLF, UTF-8, até 1.000 linhas, mesmo ano e CPF do profissional. Ordem: data pagamento; R01.001.001; ocupação; bruto recebido; dedução vazia; descrição até 255 caracteres; PF; CPF pagador; CPF beneficiário; quatro vazios; S; CPF profissional; registro até 15 caracteres. CPF somente dígitos e valor decimal vírgula, sem milhares. Descrição sanitizada para não quebrar campos/linhas. Registro vazio permitido quando houver um único registro ativo.

https://www.gov.br/receitafederal/pt-br/assuntos/meu-imposto-de-renda/pagamento/carne-leao/manual/formato-arquivo
https://www.gov.br/receitafederal/pt-br/assuntos/meu-imposto-de-renda/pagamento/carne-leao/manual

## Verificação

- Conferir botão nos dois temas e larguras 390/768/1200, alinhado ao vizinho quando houver espaço e sem overflow quando quebrar linha.
- Não assumir CPF do pagador a partir do paciente ou CPF do prestador a partir de usuário sem vínculo. Testar pagador diferente do beneficiário, profissional diferente do operador e grupo sem vínculo.
- Pagamento no mês e vencimento cartão no futuro deve entrar pela data de pagamento. Antecipação de recebível antigo não vira novo pagamento do paciente. Pendentes/cancelados/substituídos/saídas excluídos; parciais por filhas sem duplicar original e fragmentos de antecipação reunidos.
- CPF inválido, data ausente/fora do mês, profissional misturado, ocupação inválida, separador no registro, valor inválido/zero e >1.000 linhas bloqueiam CSV.
- Datas/CPF corrigidos mantêm foco e não alteram Firestore. Testar usuário com acesso a duas clínicas e fechar/trocar unidade durante carregamento/exportação; não baixar dados da unidade anterior.
- Falha de leitura oferece retry. Falha na geração conserva conferência. Geração em andamento bloqueia duplo clique/fechar/edição. PDF com dados incompletos destaca pendências.
- Abrir PDF e CSV com acentos; conferir campos, parcelas, totais brutos e nomes antes de realizar a importação oficial com dados de teste. Não enviar arquivos ilustrativos ao governo.

Dados ausentes: payerCpf em diversos recebimentos legados/filhas; CPF de beneficiários sem cadastro preenchido; CPF/registro/ocupação do profissional podem exigir conferência manual. Não há histórico/protocolo oficial de emissão, consulta ao conselho ou transmissão gov.br. Não há conciliação automática com recibos já emitidos.

Validação local: suíte completa com **415 testes Flutter aprovados**; **18 testes novos** de Receita Saúde aprovados, além dos testes do botão junto aos indicadores; build Web release concluído. Testes cobrem leiaute oficial, datas, exclusões, antecipação parcial, CPF/limites, PDF com fonte incorporada, foco, falha/retry e bloqueio de cliques em geração. As Rules, índices e dados de produção não foram alterados. A importação autenticada no governo permanece uma etapa do usuário.
