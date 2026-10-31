---
title: Collections
tags:
  - nexosaude
  - brain
  - screens
name: screen-collections
description: Cobrança manual inteligente multi-clínica — fila, rateio por presença, Pix e pagamentos existentes.
---

# CollectionsScreen

## Tela clínica — PR #2

`collections_screen.dart` mantém o fallback anterior sob `AGENDA_CLINICAL_DARK=false`. O padrão abre `clinical_collections_screen.dart`, com apresentação pura em `clinical_collections_view.dart`, agregação em `models/collection_queue.dart` e acesso em `services/collection_queue_service.dart`.

Referências: screen(5).png / code(4).html / DESIGN(4).md. Cabeçalho, competência, unidades, três indicadores, fila e painel Régua de Cobrança; claro/escuro e adaptação de 320 a 1440px. Logo/menu aprovados continuam no shell; sem nome do operador no topo.

## Escopo e fontes

- Diretório: perfil próprio, unidades do owner por ownerId e IDs de allowedClinics/clinicId. Não enumera financial global. Unidades bloqueadas e trials conhecidos vencidos são excluídos; Rules continuam sendo a autoridade de acesso. Superadmin pode usar a unidade selecionada.
- Todas as queries operacionais trazem clinicId explícito. A visão Todas as Unidades agrega somente os IDs autorizados; não usa o caminho ALL sem filtro de SessionManager. O filtro local não altera a unidade do menu.
- Financial: limites mensais exatos em dueDate/date/paymentDate/paidDate + monthlyPeriod para pacotes. Deduplica por ID. Patients, appointments e treatment_plans são compartilhados por unidade; não há listener por card.
- Odontologia: saldo por lançamento/parcela no mês de vencimento. Psicologia: pacotes no monthlyPeriod, sem duplicá-los na fila de sessões; avulsas no mês de vencimento. Agrupamento por clínica + paciente + período + plano.
- Total em aberto considera valores calculáveis, descontando paidAmount. Pacientes inexistentes/planos ambíguos/sessões ausentes impedem cobrança. Pagos, cancelados, substituídos e despesas não entram na fila. Cobrado permanece em aberto, pois contato não é pagamento.
- Liquidado usa OracleReportService.calculateMonth, a mesma base gerencial de caixa de Relatórios. A contagem é de lançamentos, não de sessões/atendimentos inferidos.
- Contatos são eventos WhatsApp registrados no mês nos documentos desta competência, deduplicados por eventId. Não é telemetria de entrega, SMS ou conversão bancária. Registros parciais legados sem confirmação não são contados como confirmados.

## Pacotes e apuração

PackageBilling continua sendo a fonte da matemática: mês incompleto parcial; divisor sessões previstas não canceladas; faltas com atestado não são cobráveis; desconto de terceiro antes do rateio. Vínculos explícitos têm prioridade; sem vínculo inequívoco a ação fica bloqueada. Não junta contratos distintos do mesmo paciente. Já pago, parcialmente pago, cobrado ou apurado não sofre novo rateio.

Confirmar envio de pacote ainda não apurado fixa o valor revisado no financial, preservando billingOriginalAmount e gravando billingRatedAmount/billingAppliedAt/billingPeriod. O valor é distribuído em centavos entre as linhas, sem aplicar desconto novamente. Não grava isPaid/paidAmount/paymentDate. Antes de Receber no Balcão, a apuração pede confirmação explícita com valor anterior e novo. A baixa continua no formulário existente.

A transação compara os campos financeiros e as fontes de presença/desconto com o snapshot revisado. Se mudaram, aborta e exige atualização. Não apura valores automaticamente ao abrir a tela, selecionar, copiar ou cancelar o envio.

## Ações

- Selecionar card atualiza o inspetor. No mobile, rola até ele. Busca local por paciente, descrição, fatura/ID e prontuário registrado; unidade/mês/seleção não se perdem ao alternar tema.
- Copiar Texto copia a prévia exata. Pix usa pixKey real e BR Code local com valor e CRC quando há cidade cadastrada. Sem cidade, usa somente a chave. Sem Pix, não inventa código. Telefone normalizado aceita DDD 55 e usa phone/celular/whatsapp válidos.
- Disparar abre WhatsApp a partir de gesto do operador. A prévia é estável e os dados são revalidados antes da abertura. Confirmação SIM registra texto exato + operador/data no prontuário e status cobrado + histórico; NÃO é no-op. Não dá baixa. Sem telefone/valor/cálculo, ação bloqueada.
- Lote é um assistente manual, um contato por clique, com Pular/Encerrar e confirmação individual. Não abre pop-ups em loop nem afirma entrega automática. Exclui contato confirmado hoje e lembrete futuro.
- Comprovante idempotente em patients/{id}/clinical_data/collection_{eventId}, usando Rules existentes que permitem ler documento ausente. Prontuário, apuração e contato são atômicos. Retry com o mesmo evento não duplica nem desfaz pagamento posterior.
- Reagendar Notif. escolhe data/hora futura e grava nextContactAt/histórico em transação. Suspende a elegibilidade até a data; envio continua manual. Não cria job ou SMS.
- Receber no Balcão abre PatientFinancialTab existente na unidade do débito, com lançamento/valor sugeridos. Em pacote com várias linhas, escolhe a linha primeiro. Famílias de parcelamento continuam no modal de família, com seus cálculos originais. A unidade esperada é conferida antes de abrir e confirmar o recebimento.
- Exportar Fechamento gera CSV seguro do mês/unidade: fila pesquisada, recebimentos do mês e totais da unidade. A pesquisa filtra a fila exportada; totais/recebimentos são do fechamento da unidade. Não exporta telefone/token do portal.
- Falha de uma fonte mostra erro, sem representar valor antigo como competência nova. Tentar novamente recarrega fontes. Troca de usuário cancela o contexto anterior.

## Diferenças dos exemplos

Não há SMS, API de envio em massa, agendamento automático, confirmação bancária do Pix ou métrica confiável de conversão/crescimento neste módulo. Os controles usam os fluxos manuais reais descritos acima. Não inventar os valores/pacientes, número de sessões ou atraso ilustrativos da referência. Numeração de prontuário só se cadastrada.

## Validação

Roteiro completo em `docs/design/collections/TESTE.md`. 28 novos testes Flutter, suíte completa com 480 testes aprovados, 39 testes de Rules no emulador e build web release. Prévias renderizadas/inspecionadas nos dois temas. Nenhuma alteração de Rules/índices/dependências ou dados de produção; sem merge/deploy.

## Ver também

- [[financial]] — cálculos e status
- [[psychology-packages]] — presença e desconto
- [[patient-details]] — recebimento por paciente
- [[financial-report]] — base de caixa compartilhada
