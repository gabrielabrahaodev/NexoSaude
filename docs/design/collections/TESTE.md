# Cobrança Manual Inteligente — PR #2

Referências: screen(5).png, code(4).html, DESIGN(4).md. Tela clara/escura conforme a estrutura de competência, protocolo por unidade, indicadores, fila e inspetor. Shell/logo aprovados preservados.

## Conferência autenticada

1. Entrar como owner com duas unidades e como staff com uma. Todas as Unidades só deve agregar as unidades autorizadas/operacionais. Filtro local não muda a unidade do menu. Erro de acesso deve mostrar erro, sem zerar saldos nem expor dados de outro mês. Troca de usuário deve descartar contexto.
2. Navegar por meses, inclusive dezembro/janeiro. Pacotes usam monthlyPeriod e não aparecem outra vez em avulsas; procedimentos/sessões usam vencimento. Quitados/cancelados/substituídos/despesas não entram na fila; cobrado ainda é pendência financeira.
3. Conferir saldo de 300 com 100 pago: 200 em aberto. Conferir duas linhas e dois planos diferentes do mesmo paciente: não misturar contratos. Clique no card deve atualizar paciente, unidade, descrição, prazo e valor do inspetor. Busca por nome sem acentos/prontuário/fatura filtra a fila.
4. Psicologia: pacote 480, desconto de terceiro 80 e 4 sessões previstas, com uma realizada, uma falta sem atestado, uma falta com atestado e uma pendente: cobrar 200. Conferir canceladas fora do divisor, mês incompleto e sessões de outro contrato. Sem vínculo/plano/sessões, impedir envio/recebimento e excluir cálculo indisponível do total.
5. Confirmar envio de um pacote: mostrar valor rateado, manter valor original em billingOriginalAmount, registrar valor apurado uma única vez. Reabrir não deve aplicar desconto novamente. Alterar presença/desconto/valor durante a revisão deve exigir atualização. Copiar/cancelar não apura nem quita.
6. Copiar deve usar o texto exato da prévia. WhatsApp deve usar telefone atualizado e Pix da unidade correta. Chave/cidade ausentes devem mostrar aviso e mensagem sem código inventado. DDD 55 não deve ser confundido com DDI. Confirmar NÃO não grava contato; confirmar SIM grava histórico e texto exato no prontuário, sem isPaid/paidAmount/paymentDate. Repetir o mesmo evento não duplica nem desfaz baixa posterior.
7. Lote: revisar um contato por vez, Pular e Encerrar; não abrir abas em loop. Lembrete futuro e contato de hoje não entram nos elegíveis. Mensagem aberta não significa entregue. Sem API/SMS, não mostrar confirmação de entrega automática.
8. Reagendar escolhe data/hora futura e suspende a elegibilidade. Explicar que o envio é manual e não será disparado por servidor. Conferir retry/falha, ausência de alteração de pagamento e registro de histórico.
9. Receber no Balcão deve abrir o recebimento existente na unidade do débito. Pacote com várias linhas pede seleção; famílias continuam no seu modal. Conferir parcial, Pix/Dinheiro/Débito/Crédito, parcelas, taxas, repasse/custos e cancelamento do formulário. Troca de unidade impede confirmar cobrança antiga. Apuração de pacote pede confirmação antes de fixar o valor; não dá baixa por si só.
10. Exportar Fechamento gera CSV com dados reais e proteção contra fórmulas. Busca filtra a fila exportada; totais/recebimentos continuam do mês/unidade. Não exportar token do portal. KPI liquidado deve coincidir com a mesma base de caixa de Relatórios, sem confundir quantidade de lançamentos com sessões.
11. Conferir 320/390/768/1040/1440px, nomes longos, valores altos, nenhum resultado, carregamento/erro, menus e tema durante seleção/busca. Mobile deve permitir chegar ao inspetor sem overflow.

## Dados/serviços que não existem na referência funcional atual

SMS, envio automático em massa, job de reagendamento, conciliação bancária Pix e taxa confiável de conversão não existem neste módulo. Contador usa confirmações registradas na competência da fila; não representa entregas do WhatsApp. Sem crescimento mensal fictício, pacientes/prontuários/valores/quantidades de sessões ilustrativos. Pix Copia e Cola é estático/local e não consulta o banco.

## Verificações executadas

- 28 testes novos de agregação, rateio, deduplicação, unidade, frozen/atestado/desconto, guardas de escrita/fontes, CSV, Pix/telefone e interface/ações em ambos os temas, de 320 a 1440px.
- Suíte Flutter completa: 480 testes aprovados. Análise estática sem erros; baseline de avisos/informações do projeto permanece.
- 39 testes de Rules no Firestore Emulator, incluindo contato/apuração/prontuário atômicos, idempotência após baixa, isolamento entre clínicas e rollback. Rules não alteradas.
- Build web release concluído. Prévias claro/escuro renderizadas e inspecionadas com dados controlados; não substituem a conferência autenticada.
- Sem novas dependências, índices, deploy, merge ou gravação de exemplos em produção.
