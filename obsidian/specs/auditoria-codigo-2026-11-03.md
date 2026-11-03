---
title: Auditoria cruzada código x Obsidian — 2026-11-03
tags: [nexosaude, auditoria, arquitetura, documentacao]
status: revisão estática; sem execução de testes ou deploy
---

# Auditoria cruzada do NexoSaúde — 03/11/2026

> [!important] Alcance real
> Revisão **estática** da árvore versionada, comparações de branches e leitura dirigida do código de módulos centrais, testes, regras, fluxo de build e notas. Não equivale à inspeção linha a linha de todos os arquivos, a uma auditoria independente do Firebase ou à execução da suíte. Esta nota separa comportamento confirmado no código, riscos e recomendações. Nenhum dado, ruleset, índice, aplicação ou serviço foi publicado.

## 1. Qual código está em qual branch?

Referências verificadas no GitHub no momento da auditoria:

| Branch | Commit | Interpretação |
| --- | --- | --- |
| `master` | `5fb7aaf98a3102f25b70734fc0ee83139c58a663` | Linha de base atual do repositório |
| `producao` | `5fb7aaf98a3102f25b70734fc0ee83139c58a663` | Mesmo commit da `master` no GitHub |
| `nova-audit` | `22fa4d53edd449ae8e7dcdf5bd18e40a2c1b2c4e` | 145 commits à frente de `master` |
| `feat/agenda-clinical-dark` | `771e300ef4b3c6dfcbde9688015beafa03c4c28d` | 171 commits à frente de `master`; referência da variante clínica |

**Atenção:** commit na branch `producao` não demonstra qual build foi implantado no Hosting nem qual ruleset está ativo no Firebase. O código publicado e o backend efetivamente ativo exigem verificação no ambiente real. O vault pode descrever uma funcionalidade que está apenas na branch experimental.

A árvore de `feat/agenda-clinical-dark` tem 517 arquivos (incluindo ativos e scaffolding), com 70 arquivos em `lib/screens/`, 43 em `lib/services/`, 21 em `lib/models/`, 77 em `test/` (70 testes Dart), 78 itens em `obsidian/`, 14 em `docs/`, 19 em `web/`, 27 em `migrate/` e 5 em `workers/`. Contagem de arquivos não significa que todos foram aprovados em teste.

## 2. Mapa da implementação, por domínio

| Domínio | Fonte de verdade observada |
| --- | --- |
| Sessão e permissões | `lib/services/session_manager.dart`, `clinic_capabilities.dart`, `menu_access.dart`, `clinic_member_directory.dart` e `firestore.rules`. A UI filtra por unidade, mas **a autorização real precisa ser validada nas Rules**. |
| Agenda | `agenda_manager_screen.dart`, `clinical_agenda_view.dart`, `agenda_professionals.dart`, `agenda_professional_selector.dart`, `appointment_service.dart`. A variante clínica é ativada por `AGENDA_CLINICAL_DARK`. |
| Atendimento | `care_day_screen.dart`, `care_visit_screen.dart`, `clinical_care_view.dart`, `care_visit_service.dart` e `care_workflow.dart`. |
| Pacientes e prontuário | `patient_workspace.dart`, `clinical_patient_screen.dart`, `clinical_patient_view.dart`, `clinical_records_view.dart`, `tabs/clinical_record_screen.dart` e `clinical_record_service.dart`. |
| Financeiro | `financial_service.dart`, `payment_service.dart`, `collection_queue_service.dart`, `clinical_collections_view.dart`, `oracle_report_service.dart`. |
| Laboratório | `lab_service.dart`, `lab_order_dialog.dart`, `clinical_lab_view.dart`, `lab_kanban_board.dart`. |
| Relatórios | `clinical_reports_view.dart`, `receita_saude_service.dart`, `receita_saude_dialog.dart`, `receita_saude_export.dart`. |
| Portal | `portal_mirror.dart`, `web/portal.html`, `web/confirmar.html`, `web/anamnese.html` e `remarcacao_service.dart`. |
| Documentos | `document_service.dart`, `tabs/patient_docs_tab.dart` e `workers/private-documents/`. |
| CI e publicação | `.github/workflows/ci-manual.yml`, `deploy.bat`, `firebase.json`, `test/rules/matrix.test.js`. |

## 3. Achados priorizados

### A01 — Cancelamento da agenda não garante sempre registro no prontuário (alta)

Em `lib/screens/agenda/agenda_manager_screen.dart`, `_showCancellationDialog` grava em sequência:
1. `appointments/{id}` com status `Cancelado`, `cancelledBy`, `cancellationReason`, `cancellationSource` e `cancelledAt`;
2. `clinical_records` com `procedureName='Cancelamento de Consulta'` e descrição contendo origem, motivo e operador.

São **duas escritas separadas**, não um commit atômico. A falha da segunda pode deixar o agendamento cancelado sem o histórico clínico. O caminho genérico `AppointmentService.cancel(id)` altera status e espelhos/slots, mas **não cria registro clínico**. Portanto é incorreto declarar que *todo* cancelamento gera prontuário.

**Recomendação, não implementada:** unificar o contrato de cancelamento, garantir idempotência e coerência transacional/compensação; testar erro entre as gravações, cancelamento repetido, origem, motivo e isolamento da clínica. Ver [[agenda]] e [[clinical]].

### A02 — Prontuário clínico renovado apenas na branch de desenvolvimento (média)

`ClinicalRecordsView` exibe filtros Todos/Evoluções/Cancelamentos/Procedimentos, contagens reais, ordenação e ações Novo/Editar/Excluir. Classifica cancelamento pelo título ou `attendanceStatus='missed'`, administrativos por cobrança/`type='administrative'`; Procedimentos exige `treatmentId` explícito. Não infere diagnósticos, laudos ou tratamentos por texto.

`ClinicalRecordTab` permite evolução geral sem plano ativo; exige descrição, preserva autor e data iniciais na edição, anota `editedBy`/`editedAt`, verifica troca de unidade/paciente ao salvar e pede confirmação ao excluir. O título visual “CONDUTA & DIAGNÓSTICO” para uma evolução genérica merece revisão de terminologia. Não confundir presença de registro com assinatura/validação profissional.

### A03 — Cloudinary na master; R2/Worker condicionado a opt-in na variante clínica (alta, operacional)

- `master/lib/services/document_service.dart`: upload via Cloudinary e exclusão remota desativada.
- Na `feat/agenda-clinical-dark`, novos uploads utilizam Worker autenticado + bucket R2 privado. `DocumentService.isPrivateStorageConfigured` exige URL válida no build. `deploy.bat` **desativa por padrão** e só usa `PRIVATE_FILES_API_URL` quando `NEXO_ENABLE_PRIVATE_STORAGE=true`.
- Sem opt-in, a aba Documentação bloqueia novos envios e informa por quê; documentos legados com URL salva ainda podem ser abertos. A implantação real do Worker não foi verificada.
- Exclusão de metadados de arquivos remotos exige antes a remoção do binário pelo fluxo válido. Cloudinary legado depende do procedimento administrativo; `purgePatientFiles` não é uma rotina que apaga arquivos automaticamente.

**Recomendação:** não ativar Worker por documentação ou sem configuração explícita e testes com arquivos fictícios. Ver [[comms]], [[patient-details]] e `workers/private-documents/README.md`.

### A04 — Exclusões são processos sensíveis, com preflight e lotes (alta)

`PatientService.deletePatientCascade` identifica dados relacionados, arquivos remotos e remove documentos em lotes de 450. Sua verificação prévia busca documentos remotos antes do primeiro batch, interrompendo a exclusão se houver metadados que demandem limpeza externa. `ClinicDeleteService` faz preflight semelhante, procura pacientes apenas da unidade, considera diretórios de membros e revogação de portal, e protege contra clínica bloqueada/expirada em execução via navegador.

**Limitação:** lotes não formam transação única de toda a cascata. Erro a meio caminho pode exigir reconciliação administrativa. Confirmar backup, DRY-RUN e relatório antes de qualquer exclusão de dados reais.

### A05 — Diretórios de membros e autorização não devem ser confundidos (alta)

Na variante clínica, `clinics/{clinicId}/members` fornece o mínimo necessário à UI; `members_private` armazena dados privados acessíveis a gestor autorizado. A agenda usa `watchAgendaProfessionals` e `agendaProfessionalsFromMembers`: só membros ativos de papéis owner, dentista ou psicólogo são elegíveis. Owner/recepção/superadmin podem selecionar conforme `canChooseAgendaProfessional`; profissional clínico fica restrito ao próprio UID na apresentação.

Esses filtros são **regras de UI**, não autorização suficiente: confirmar o isolamento e os estados do perfil com `test/rules/matrix.test.js`, inclusive os caminhos públicos. Não concluir que o ruleset está ativo apenas porque aparece no repositório.

### A06 — Pagamento parcial, espelho e histórico financeiro (alta)

`FinancialService.partialRemainder` calcula `amount - paidAmount - payValue`. Há compatibilidade entre formato legado (`amount` integral + `paidAmount`) e novo (saldo em `amount`, parcelas-filhas). Em `buildPortalMirror`, o total de débitos abertos é calculado por `amount - paidAmount`, ignorando quitados/cancelados/substituídos.

**Risco de interpretação:** não somar parcelas-filhas novamente ao pai nem tratar “aviso de pagamento” ou contato WhatsApp como quitação. Para cobrança legada de R$ 200,00 com R$ 80,00 recebidos, saldo restante esperado é R$ 120,00; para formato novo, conferir saldo e filhas. Ver [[financial]] e [[portal-mirror]].

### A07 — Recebimento não deve gerar pedido de laboratório (média)

A variante clínica separa pedido/custo em `LabService` da baixa financeira. Um custo explícito de laboratório gera despesa pendente; pagamento do paciente não deve criar pedido nem apagar seus custos no estorno. Validar ações no kanban geral, por paciente e nas telas financeiras. Ver [[clinic-lab]] e [[financial]].

### A08 — Receita Saúde é apoio à conferência/exportação, não emissão fiscal automática (média)

O fluxo de `ReceitaSaudeService`, diálogo e exportador monta arquivo a partir de dados financeiros reais, com revisão manual de prestador, CPF e datas. **Não** transmite dados para gov.br, não emite protocolo/recibo nem confirma regularidade profissional. Conferir importação e risco de duplicação antes do uso real. Ver [[reports]].

### A09 — Testes e CI: diferença concreta entre branches (média)

Em `master`, `.github/workflows/ci-manual.yml` tem apenas `workflow_dispatch`. Na variante clínica, o workflow inclui execução em `push` (master/producao/nova-audit) e PR para master/producao, análises Flutter, testes Dart, verificações Node/HTML e matriz Firestore com Java 21 e emulador. Ter testes no repositório não comprova que passaram no HEAD atual.

**Necessário antes de merge:** executar `flutter analyze`, `flutter test`, build web, `test/rules/matrix.test.js` no emulador e testes manuais nas larguras 320/360/390/430; registrar SHA e resultados. Consulte [[remodelagem-plano-testes]] e os arquivos de `docs/design/*/TESTE.md`.

## 4. Pendências concretas de documentação

- `README.md` na `master` ainda aponta para `brain/`; o vault está em `obsidian/`. Ajustar em PR próprio quando forem permitidas mudanças fora de Obsidian.
- A descrição antiga de documentos em `obsidian/modules/comms.md` ainda tratava exclusão como somente Firestore e Cloudinary ativo para todos os builds. Corrigida nesta rodada na branch de documentação.
- `obsidian/APP_FLOW.md` descreve ficha do paciente exclusivamente por push, mas a variante clínica usa `PatientWorkspace` embutido no painel (ver nota atualizada).
- `obsidian/screens/agenda-manager.md` e `obsidian/modules/agenda.md` precisavam de ressalva sobre caminhos distintos de cancelamento.
- O vault tem documentos históricos datados (ex.: `remodelagem-fase3-seguranca.md`) com propostas **já superadas pelo código de desenvolvimento**; são registros históricos, não instruções de implantação.

## 5. Checklist para continuidade

- [ ] Verificar qual SHA foi efetivamente implantado no Firebase Hosting e qual ruleset/indexes estão ativos; nunca inferir do nome `producao`.
- [ ] Rodar e anexar resultados atuais de Flutter analyze/test/build web, testes Node e Firestore emulator na branch alvo.
- [ ] Testar perfis, isolamento de unidade, mirror público/privado, revogação de token e trial bloqueado.
- [ ] Provar comportamento de cancelamento em todos os caminhos: UI, serviço, falha da anotação e cancelamento repetido.
- [ ] Testar financeiro legado/novo, Pix, famílias de parcelas, estorno, relatórios e aviso de pagamento.
- [ ] Testar R2 somente se habilitado; assegurar proteção do legado Cloudinary e exclusões remotas.
- [ ] Validar 320/360/390/430 px, temas claro/escuro, diálogo com teclado, agenda, ficha, prontuário, cobranças.
- [ ] Revisar políticas LGPD, retenção, auditoria de alteração/exclusão de registros clínicos e confirmação profissional.
- [ ] Submeter alterações por PR, sem merge/deploy automático.

## 6. Referências de código e notas

- `firestore.rules`; `lib/services/clinic_member_directory.dart`; `lib/services/agenda_professionals.dart`
- `lib/screens/agenda/agenda_manager_screen.dart`; `lib/services/appointment_service.dart`
- `lib/screens/patients/clinical_records_view.dart`; `lib/screens/patients/tabs/clinical_record_screen.dart`
- `lib/services/document_service.dart`; `lib/services/patient_service.dart`; `lib/services/clinic_delete_service.dart`
- `lib/services/financial_service.dart`; `lib/services/portal_mirror.dart`; `lib/services/collection_queue_service.dart`
- `.github/workflows/ci-manual.yml`; `deploy.bat`; `workers/private-documents/README.md`
- [[agenda]], [[clinical]], [[comms]], [[financial]], [[portal-mirror]], [[APP_FLOW]], [[remodelagem-plano-testes]]
