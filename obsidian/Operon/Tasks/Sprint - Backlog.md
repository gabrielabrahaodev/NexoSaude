# Backlog NexoSaúde

Fila priorizada (scrum). Épicos entregues em [[E1 - Plataforma e Assinatura]], [[E2 - Portal e LGPD]], [[E3 - Atendimento e Agenda]], [[E4 - Acesso e Multiclínica]], [[E5 - Cota e Dados]], [[E6 - Docs e Vault]], [[E7 - Avaliações Técnicas]]. Regra: todo item novo ganha `operonId` único (`nx-1xx`) e pai quando couber.

## Agora (prioridade A)

- [x] Mostrar nome do usuário logado junto ao "Sair do Sistema" no menu [[main-dashboard]] {{operonId:: nx-116}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e4}} #nexosaude #area/app
- [x] Agenda no celular: exibir o nome inteiro do paciente na célula [[agenda-manager]] {{operonId:: ox2veye}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e3}} #nexosaude #area/app {{datetimeModified:: 2026-09-29T01:23:07}}
- [x] Agenda: filtro de profissional com largura reduzida (max 320px, alinhado à esquerda) [[agenda-manager]] {{operonId:: nx-118}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e3}} #nexosaude #area/agenda
- [x] Padronizar cabeçalhos de todas as telas: seletor de mês no padrão arredondado de Relatórios + header moderno minimalista [[ui-consistency]] {{operonId:: nx-119}} {{status:: Finished}} {{priority:: A}} {{parentTask:: nx-e4}} #nexosaude #area/app
- [ ] Deploy da master em produção (build + hosting) e validar login owner {{operonId:: nx-101}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-e1}} {{dateDue:: 2026-10-03}} #nexosaude #area/entrega
- [ ] Commitar a fila pendente na master (código + vault já validados: analyze 0, testes verdes) {{operonId:: nx-102}} {{status:: Planned}} {{priority:: A}} {{dateDue:: 2026-10-02}} #nexosaude #area/entrega
- [ ] Reconsentir os 53 pacientes com consulta em 14 dias (lista em Temp + recepção reemite com diálogo) {{operonId:: nx-103}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-e2}} {{dateDue:: 2026-10-06}} #nexosaude #area/operacao
- [ ] Validar trial ponta a ponta (pedir → aprovar no Master → entrar → portal) {{operonId:: nx-104}} {{status:: Planned}} {{priority:: A}} {{parentTask:: nx-e1}} #nexosaude #area/qualidade

## Depois (prioridade B)

- [ ] Decidir Blaze (US$ 1–3/mês) vs seguir no Spark {{operonId:: nx-105}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-e5}} #nexosaude #area/decisao
- [ ] Trocar SALES_WHATSAPP placeholder na landing {{operonId:: nx-106}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-e1}} #nexosaude #area/site
- [ ] Revisar bloqueios fundidos do Yervant com o dono {{operonId:: nx-107}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-e3}} #nexosaude #area/dados
- [ ] Deploy de firestore.indexes.json pendente (nunca aceitar delete) {{operonId:: nx-108}} {{status:: Planned}} {{priority:: B}} {{parentTask:: nx-e5}} #nexosaude #area/infra
- [ ] Checagem de CPF duplicado no cadastro (query existe, bloqueio comentado) {{operonId:: nx-109}} {{status:: Planned}} {{priority:: B}} #nexosaude #area/app
- [ ] Higiene Cloudinary/API keys: restringir preset unsigned + chaves no console {{operonId:: nx-110}} {{status:: Planned}} {{priority:: B}} #nexosaude #area/seguranca
- [ ] Cadastrar datas de nascimento (405/415 sem) para aniversariantes do KPI {{operonId:: nx-111}} {{status:: Planned}} {{priority:: B}} #nexosaude #area/operacao
- [ ] Alertas de exceção no KPI (pacientes/casos fora do esperado hoje) {{operonId:: nx-114}} {{status:: Planned}} {{priority:: B}} #nexosaude #area/app
- [ ] Exclusão definitiva do projeto antigo (30 dias após shutdown) {{operonId:: nx-113}} {{status:: Planned}} {{priority:: B}} {{dateDue:: 2026-10-29}} {{parentTask:: nx-e5}} #nexosaude #area/infra

## Estacionado (n�o fazer sem decis�o expl�cita)

- [ ] Inspetor workstation na agenda (revertido; retomar só com novo desenho) {{operonId:: nx-112}} {{status:: Paused}} {{priority:: C}} #nexosaude #estacionado #area/app
- [ ] Automação WhatsApp (n8n/Apps Script/gateway) — arquivado por falta de infra {{operonId:: nx-115}} {{status:: Paused}} {{priority:: C}} #nexosaude #estacionado #area/automacao