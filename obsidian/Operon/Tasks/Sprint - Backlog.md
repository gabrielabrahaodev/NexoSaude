# Backlog NexoSaúde

Fila priorizada (scrum). Épicos entregues em [[E1 - Plataforma e Assinatura]], [[E2 - Portal e LGPD]], [[E3 - Atendimento e Agenda]], [[E4 - Acesso e Multiclínica]], [[E5 - Cota e Dados]], [[E6 - Docs e Vault]], [[E7 - Avaliações Técnicas]]. Regra: todo item novo ganha `operonId` único (`nx-1xx`) e pai quando couber.

## Agora (prioridade A)

- [x] Mostrar nome do usuário logado junto ao "Sair do Sistema" no menu [[main-dashboard]] {{operonId:: nx-116}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e4}} #nexosaude #area/app
- [x] Agenda no celular: exibir o nome inteiro do paciente na célula [[agenda-manager]] {{operonId:: ox2veye}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e3}} #nexosaude #area/app {{datetimeModified:: 2026-09-29T01:23:07}}
- [x] Agenda: filtro de profissional com largura reduzida (max 320px, alinhado à esquerda) [[agenda-manager]] {{operonId:: nx-118}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e3}} #nexosaude #area/agenda
- [x] Padronizar cabeçalhos de todas as telas: seletor de mês no padrão arredondado de Relatórios + header moderno minimalista [[ui-consistency]] {{operonId:: nx-119}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e4}} #nexosaude #area/app
- [x] Compactar visual global: headers 44px + fontes/paddings reduzidos (exceto agenda e pagamentos) [[ui-consistency]] {{operonId:: nx-120}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e4}} #nexosaude #area/app
- [x] Remarcação do portal em laranja no atendimento/agenda com aceitar + WhatsApp + reflexo no portal [[remarcar-dialog]] {{operonId:: nx-121}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e3}} #nexosaude #area/agenda
- [x] Parcelamento: status terminal, cancel em batch, vencimentos mensais editáveis, parcial x parcelar [[patient-tabs]] {{operonId:: nx-122}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e2}} #nexosaude #area/financeiro
- [x] Notícias científicas por tema da clínica (Europe PMC + Semantic Scholar) [[ortho-news]] {{operonId:: nx-123}} {{status:: Finished}} {{priority:: B}} {{parentTask:: nx-e7}} #nexosaude #area/app
- [x] Backup owner: tela Exportar (JSON/CSV, tudo marcado) + CPF duplicado + temp forte [[main-dashboard]] {{operonId:: nx-124}} {{status:: Finished}} {{priority:: A}} #nexosaude #area/app
- [x] Atendimento sem novo lançamento; próxima sessão com dentista + horários livres [[care-day]] {{operonId:: nx-125}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e3}} #nexosaude #area/atendimento
- [x] Cobrança via WhatsApp registrada no prontuário (SIM-confirmado) [[collections]] {{operonId:: nx-126}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e2}} #nexosaude #area/financeiro
- [x] Parcelas de cartão em modal da família (filhas fora da lista) [[patient-tabs]] {{operonId:: nx-134}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e2}} #nexosaude #area/financeiro
- [x] Repetir próxima semana (+7 dias com choque) [[care-day]] {{operonId:: nx-127}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s1}} #nexosaude #area/atendimento
- [x] Cargas paralelas na ficha (Future.wait) [[care-day]] {{operonId:: nx-128}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s2}} #nexosaude #area/atendimento
- [x] Sheet instantânea com shimmer no bloco de risco [[agenda-manager]] {{operonId:: nx-129}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s2}} #nexosaude #area/atendimento
- [x] Deep-links de volta (cobrança/ficha sem menu) [[collections]] {{operonId:: nx-130}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s2}} #nexosaude #area/atendimento
- [x] Faixa fixa de alertas clínicos (dividir com wizard de contexto) [[care-day]] {{operonId:: nx-131}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s3}} #nexosaude #area/atendimento
- [x] Próxima sessão sugerida (+7 dias validada) [[care-day]] {{operonId:: nx-132}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s3}} #nexosaude #area/atendimento
- [x] Presença em massa no Meu dia [[care-day]] {{operonId:: nx-133}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s3}} #nexosaude #area/atendimento
- [x] Deploy da master em produção (build + hosting) e validar login owner {{operonId:: nx-101}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e1}} {{dateDue:: 2026-10-03}} #nexosaude #area/entrega
- [x] Commitar a fila pendente na master (código + vault já validados: analyze 0, testes verdes) {{operonId:: nx-102}} {{status:: Finished}} {{priority:: A}} {{dateDue:: 2026-10-02}} #nexosaude #area/entrega
- [ ] Reconsentir os 45 pacientes sem aceite com consulta em 14 dias (filtro Sem aceite na lista + recepção reemite na ficha) {{operonId:: nx-103}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-e2}} {{dateDue:: 2026-10-06}} #nexosaude #area/operacao
- [ ] Validar trial ponta a ponta (pedir → aprovar no Master → entrar → portal) {{operonId:: nx-104}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-e1}} #nexosaude #area/qualidade
- [ ] PAG-01 — Estado VENCIDO há N dias (S) [[patient-tabs]] {{operonId:: nx-140}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s4}} #nexosaude #area/financeiro
- [ ] PAG-02 — Chip só estado; parcelamento em subtítulo (M) [[patient-tabs]] {{operonId:: nx-141}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s4}} #nexosaude #area/financeiro
- [ ] PAG-03 — Contagem nos totais + próximo vencimento (S) [[patient-details]] {{operonId:: nx-142}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s4}} #nexosaude #area/financeiro
- [ ] PAG-04 — Formato de moeda pt-BR (S) [[ui-consistency]] {{operonId:: nx-143}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s4}} #nexosaude #area/financeiro
- [ ] PAG-17 — Resumo sem conta dobrada pai + filhas (S) [[patient-details]] {{operonId:: nx-144}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s4}} #nexosaude #area/financeiro
- [ ] PAG-05 — Data absoluta ao lado de "ontem" (S) [[patient-details]] {{operonId:: nx-145}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s5}} #nexosaude #area/financeiro
- [ ] PAG-06 — WhatsApp com rótulo "Cobrar" (S) [[patient-tabs]] {{operonId:: nx-146}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s5}} #nexosaude #area/financeiro
- [ ] PAG-07 — Cores semânticas distintas por dimensão (S) [[patient-tabs]] {{operonId:: nx-147}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s5}} #nexosaude #area/financeiro
- [ ] PAG-08 — Zero em cor neutra (S) [[patient-details]] {{operonId:: nx-148}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s5}} #nexosaude #area/financeiro
- [ ] PAG-09 — Reordenar cards por papel (S) [[patient-details]] {{operonId:: nx-149}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s5}} #nexosaude #area/financeiro
- [ ] PAG-18 — Nó da timeline usa mesma regra do chip (S) [[patient-tabs]] {{operonId:: nx-150}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-s5}} #nexosaude #area/financeiro
- [ ] PAG-10 — Investigar "Sessão 1" triplicada (M) [[patient-tabs]] {{operonId:: nx-151}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-s6}} #nexosaude #area/financeiro
- [ ] PAG-11 — Legenda dos nós (S) [[patient-tabs]] {{operonId:: nx-152}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-s6}} #nexosaude #area/financeiro
- [ ] PAG-12 — Uso da área direita no desktop (M) [[patient-tabs]] {{operonId:: nx-153}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-s6}} #nexosaude #area/financeiro
- [ ] PAG-13 — Progresso da família inline (M) [[patient-tabs]] {{operonId:: nx-154}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-s6}} #nexosaude #area/financeiro
- [ ] PAG-14 — Contraste e alvos de toque (S) [[patient-tabs]] {{operonId:: nx-155}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-s6}} #nexosaude #area/financeiro
- [ ] PAG-15 — Glifos distintos por estado (S) [[patient-tabs]] {{operonId:: nx-156}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-s6}} #nexosaude #area/financeiro
- [x] Evento da agenda reflete no portal na hora: delta com fallback p/ rebuild + cadastro rápido constrói o doc (nx-159) [[portal-page]] {{operonId:: nx-159}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s2}} #nexosaude #area/portal
- [x] Sheet da agenda sem pulo de layout: risco com future memoizado + shimmer animado + altura fixa (follow-up S2) [[agenda-manager]] {{operonId:: nx-157}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s2}} #nexosaude #area/agenda
- [x] Ficha do paciente monta sem pedacinhos: context card com Future.wait + combine puro testado (follow-up S2) [[patient-details]] {{operonId:: nx-158}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-s2}} #nexosaude #area/app

## Depois (prioridade B)

- [ ] Decidir Blaze (US$ 1–3/mês) vs seguir no Spark {{operonId:: nx-105}} {{status:: Paused}} {{priority:: B}} {{parentTask:: nx-e5}} #nexosaude #area/decisao
- [x] Trocar SALES_WHATSAPP placeholder na landing {{operonId:: nx-106}} {{status:: Finished}} {{priority:: B}} {{parentTask:: nx-e1}} #nexosaude #area/site
- [x] Revisar bloqueios fundidos do Yervant com o dono {{operonId:: nx-107}} {{status:: Finished}} {{priority:: B}} {{parentTask:: nx-e3}} #nexosaude #area/dados
- [x] Deploy de firestore.indexes.json pendente (nunca aceitar delete) {{operonId:: nx-108}} {{status:: Finished}} {{priority:: B}} {{parentTask:: nx-e5}} #nexosaude #area/infra
- [x] Checagem de CPF duplicado no cadastro (query existe, bloqueio comentado) {{operonId:: nx-109}} {{status:: Finished}} {{priority:: B}} #nexosaude #area/app
- [x] Higiene Cloudinary/API keys: restringir preset unsigned + chaves no console {{operonId:: nx-110}} {{status:: Finished}} {{priority:: B}} #nexosaude #area/seguranca
- [ ] Cadastrar datas de nascimento (405/415 sem) para aniversariantes do KPI {{operonId:: nx-111}} {{status:: Planned}} {{priority:: B}} #nexosaude #area/operacao
- [x] Alertas de exceção no KPI (pacientes/casos fora do esperado hoje) {{operonId:: nx-114}} {{status:: Finished}} {{priority:: B}} #nexosaude #area/app
- [ ] Exclusão definitiva do projeto antigo (30 dias após shutdown) {{operonId:: nx-113}} {{status:: Planned}} {{priority:: B}} {{dateDue:: 2026-10-29}} {{parentTask:: nx-e5}} #nexosaude #area/infra

## Estacionado (n�o fazer sem decis�o expl�cita)

- [ ] Inspetor workstation na agenda (revertido; retomar só com novo desenho) {{operonId:: nx-112}} {{status:: Paused}} {{priority:: C}} #nexosaude #estacionado #area/app
- [ ] Automação WhatsApp (n8n/Apps Script/gateway) — arquivado por falta de infra {{operonId:: nx-115}} {{status:: Paused}} {{priority:: C}} #nexosaude #estacionado #area/automacao