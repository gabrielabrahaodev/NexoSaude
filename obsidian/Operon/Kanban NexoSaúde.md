---

kanban-plugin: board
kanban-plugin-created: 2026-09-29

---

## A Fazer

- [ ] Reconsentir os 53 pacientes com consulta em 14 dias [[Sprint - Backlog]] `nx-103` (venceu 06/10 — REAGENDADO p/ 23/10)
- [ ] Validar trial ponta a ponta [[Sprint - Backlog]] `nx-104` (inclui pedido com `uid` + aprovação Master + relógio 7d)
- [ ] Matriz de rules no emulator + release `rules/indexes` (reavaliação 16/10) `nx-171` — 1º lote: matriz 14/14 ✓, publicado `f50ad0ac` ✓, ao vivo confirmado ✓, manual pendente; 2º lote (anamnese token, status, revogação, reset): ARQUIVO, matriz a rodar
- [ ] Backfill `trialEndsAt` legadas + política trial null (reavaliação §3) `nx-172` — 2 clínicas sem trial (Yervant, Jabaquara); + `status: Ativo` no doc superadmin (sem status hoje)
- [ ] Backfill `clinicId` pacientes sem clínica, se houver (reavaliação §9) `nx-173` — base 16/10: 440/440 COM clínica
- [ ] Limpeza manual periódica de órfãos Cloudinary (retenção) `nx-174`
- [ ] Regressão manual 2º lote (anamnese token, revogação, reset, public_clinics, menuAccess) `nx-175`


## Depois

- [ ] Decidir Blaze vs Spark [[Sprint - Backlog]] `nx-105`
- [ ] Cadastrar datas de nascimento (405 sem) [[Sprint - Backlog]] `nx-111`
- [ ] Exclusão definitiva do projeto antigo (30 dias) [[Sprint - Backlog]] `nx-113`


## Estacionado

- [ ] Inspetor workstation (revertido) [[Sprint - Backlog]] `nx-112`
- [ ] Automação WhatsApp (sem infra) [[Sprint - Backlog]] `nx-115`


## Concluído

- [x] [[E1 - Plataforma e Assinatura]]
- [x] [[E2 - Portal e LGPD]]
- [x] [[E3 - Atendimento e Agenda]]
- [x] [[E4 - Acesso e Multiclínica]]
- [x] [[E5 - Cota e Dados]]
- [x] [[E6 - Docs e Vault]]
- [x] [[E7 - Avaliações Técnicas]]
- [x] Deploy master + login owner `nx-101`, fila na master `nx-102`, SALES_WHATSAPP `nx-106`, bloqueios Yervant `nx-107`, indexes `nx-108`, CPF duplicado `nx-109`, Cloudinary `nx-110`, alertas KPI `nx-114` (16/10, ver backlog)
