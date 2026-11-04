# Auditoria de integridade — 03/11/2026

Base confirmada na PR 6: 4141190092ca0cc83f56c7f4f6662b49a3b85f78, CI 41740145556 aprovado.

| Risco | Mudança implementada | Validação | Estado |
|---|---|---|---|
| Exclusão de paciente/clínica e Tags órfãs | Tags incluídas no plano. Bloqueio conservador antes dos lotes quando há dados clínicos, Tags, financeiro ou planos. Clínica com catálogo exige revisão administrativa | Plano escopado para 0/1/N pacientes. Testes com falha entre lotes e corrida de criação ainda necessários | Mitigado no app |
| Orçamento aprovado apaga histórico | Exclusão aprovada bloqueada. Orçamento pendente apagado em transação que valida unidade/paciente e estado atual | Política testada com UI desatualizada e plano existente | Corrigido no serviço; Rules gerais de exclusão ainda precisam endurecimento |
| Catálogo deixa definição órfã | Exclusão virou desativação lógica, pai e definição atualizados na mesma transação | Análise/CI; teste de integração pendente | Implementado |
| Plano alternativo sem Tags | createFromBudget não possui chamadores no lib/test; método legado passa a falhar explicitamente orientando aprovação atômica | rg createFromBudget lib test | Corrigido |
| Tags adulteráveis | Regra genérica exclui procedure_tags. Clínica/paciente no create; campos de contrato imutáveis no update; incrementos limitados; delete negado | Emulador verifica alteração de contrato, clínica, snapshot, contador e exclusão | Mitigado |
| Concorrência real | Consulta antes de salvar permanece. Ainda há escritores diretos em agenda, atendimento, remarcação, scripts e portal | Sem prova de exclusão mútua | Bloqueado para rollout |
| Espelho incompleto | occupySlot/releaseSlot/adjustSlots continuam usando horário inicial/arrays | Reconciliação e testes ainda necessários | Pendente |
| Bases master/producao | Diagnóstico dos logs das bases ainda não concluído | CI da PR não prova as bases | Pendente |

## Limite de segurança e rollout

A definição de pronto do pedido ainda não foi atingida. Não publicar estas Rules isoladamente: criação de Tags ainda não prova vínculo com orçamento/plano via getAfter e finalização ainda não prova a evolução e sessão correspondente. Um usuário da mesma clínica pode fabricar uma transição com campos permitidos. Migração Admin ignora Rules e exige revisão própria. Documentos concluídos ficam imutáveis no cliente.

A proteção completa de reserva exige um escritor autenticado único para todos os caminhos. O cliente e portal hoje podem gravar appointments diretamente. Apenas adicionar locks no Flutter não fornece proteção contra cliente malicioso. Antes do rollout, é necessário escolher backend autenticado compatível com o plano de infraestrutura, auditar reservas legadas em DRY-RUN e fechar nas Rules os escritores que contornem esse backend. A infraestrutura atual documenta Spark e ausência de Functions. Nenhum serviço pago foi ativado.

O escritor futuro deve transacionar agendamento, comprovante booking e ocupação por profissional e intervalo. Encaixe precisa autorização e limite validados. Cancelamento só libera a própria reserva. Espelhos públicos devem ser reconstruídos a partir dessas reservas sem PII. Não ativar locks antes do inventário de legados e reconciliação.

## Retenção e exclusões

Política escolhida nesta rodada é bloquear exclusão de dados contratados/clínicos até existir fluxo administrativo de retenção e arquivamento. Isso é conservador, inclusive para Tags ainda pendentes. Não determina prazo legal de retenção. As guardas no app não impedem alterações concorrentes entre o preflight e batches e não substituem Rules/backend. Falha de batch continua propagando erro; retomada administrativa continua pendente. O plano de clínica inclui Tags, mas a execução normal bloqueia quando elas existem.

## Publicação e dados reais

Rules alteradas somente no repositório. Índices preservados. Antes de publicação, concluir invariantes de aprovação/finalização, matriz de emulador e rollout do escritor único. Depois seguir rules-validate, rules-release e rules-inspect com autorização do proprietário. A PR deve continuar sem merge.

Reconciliações necessárias: inventário de Tags/planos/órfãos; reservas legadas por unidade/profissional/intervalo; portal_slots por duração e sobreposição. Implementação dos scripts de reconciliação continua pendente. Executar primeiro DRY-RUN com manifesto, revisar conflitos e backup, solicitar autorização antes de qualquer APPLY.

Nenhum merge, deploy, migração ou escrita em dados reais foi executado.
