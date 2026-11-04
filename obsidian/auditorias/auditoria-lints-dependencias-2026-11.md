# Auditoria de lints e dependências — 2026-11

## Base e escopo

- Referência: `feat/procedure-tags-workflow`, commit `1c8abf252e420a7e43b30d359a7ded7cd717d0c8`.
- Manutenção: `chore/flutter-lints-security-2026-11`, PR para a mesma branch de referência.
- Checkout inicial limpo; nenhuma alteração local foi descartada. Arquivos Obsidian preexistentes, version.json, scripts de migração e Firebase Options foram preservados.
- Flutter 3.38.7, Dart 3.10.7, Node inicial 24.22.1. Matriz validada também em Node **20.20.2**, Java 21, Firebase CLI 15.34.2.
- Nenhum merge, deploy, publicação de Rules/índices, migração ou acesso a dados clínicos reais.

## Antes e depois

| Verificação | Antes | Depois |
|---|---:|---:|
| Erros Dart | 0 | 0 |
| Warnings | 34 | 0 |
| Infos | 162 | 0 |
| Total do analyze | 196 | 0 |
| Testes Flutter aprovados | 547 | 547 |
| Vulnerabilidades npm | 20 (14 moderadas, 6 altas) | 0 |

Os 197 apontamentos/558 testes do pedido não correspondem à referência solicitada: a PR #7 tem correções e testes adicionais. Esta manutenção não os removeu nem fez cherry-pick dessa PR; partiu exatamente da branch indicada. Não foram removidos testes ou assertions. Testes existentes tiveram apenas migração da API de armazenamento, identificadores e blocos.

## Alterações

- Guards de ciclo de vida: `mounted` para o State, `context.mounted`/`ctx.mounted` para contextos locais de modais, incluindo retorno após await antes de navegar, emitir avisos ou atualizar estado. Operações de persistência já iniciadas continuam concluindo; uma tela desmontada não tenta atualizar sua UI.
- RadioGroup substitui callbacks individuais de RadioListTile. Mantidas opções, cores e impedimento de converter falta inicial em atendimento realizado; mudança para realizado continua limpando o atestado.
- DropdownButtonFormField usa initialValue; switches usam activeThumbColor; DragTarget usa details.data; odontograma usa scaleByDouble com a mesma escala x/y/z; PDF usa TableHelper. Nenhuma mudança de layout aprovada foi intencionalmente realizada.
- Removidos imports/casts/variáveis não utilizados e condições impossíveis de nulidade. Billing continua usando amountDue, previstas e isPartial do cálculo já validado; não foi criado fallback financeiro novo.
- Recebimento já fechava o modal antes do try de persistência, tornando popped sempre true no catch. Removido apenas esse reset inalcançável; o erro continua sendo comunicado pelo ScaffoldMessenger capturado.
- Falha ao ler taxa de antecipação continua usando o mesmo padrão 2,29; agora registra diagnóstico. API legada Cloudinary permanece pública para consumidores externos, mas consumidores internos/testes usam requiresRemoteStorageCleanup.
- `crypto ^3.0.7` declarado diretamente porque há import direto; versão resolvida preservada.

## Dependências

- file_picker **6.2.1 → 8.3.7**, menor linha selecionada com implementações desktop inline e compatível com Dart/Flutter instalados. Nenhum novo projeto nativo foi configurado. O registro macOS mudou automaticamente pelo Flutter, apenas adicionando o plugin agora implementado; arquivo gerado mantido coerente com o lockfile.
- Firebase JS dos testes **10.14.1 → 12.19.0**, rules-unit-testing **3.0.4 → 5.0.2**. A linha mais recente (rules 6/Firebase 13) exige Node 24 e foi evitada para preservar Node 20.
- firebase-admin **13.10.0 removido de test/rules**: nenhum teste o importa; os contextos administrativos da matriz vêm de withSecurityRulesDisabled da biblioteca de testes. Não foi removido de scripts de migração nem de outros pacotes.
- Override transitivo `@grpc/grpc-js ^1.13.6`, resolvido em **1.14.7**. Firebase ainda declara ~1.9; a correção de segurança só existe a partir de 1.13.6. Mantida a API 1.x e comprovada a matriz no Node 20. Reavaliar/remover o override quando Firebase atualizar a faixa upstream.
- Nenhum audit fix --force, downgrade para Firebase 9, desativação de TLS/checksum ou supressão de lints foi utilizado. npm audit foi habilitado explicitamente com --audit=true porque a imagem o desativa por configuração.

### Pacotes afetados no relatório inicial

Os números do audit contam pacotes afetados, inclusive cadeias transitivas; não representam 20 falhas independentes. Todos pertencem às devDependencies de test/rules e não são distribuídos no bundle Flutter nem no Worker de documentos.

| Pacote | Severidade inicial | Versões iniciais | Versões finais |
|---|---|---|---|
| `@firebase/auth` | moderate | 1.7.9 | 1.13.6 |
| `@firebase/auth-compat` | moderate | 0.5.14 | 0.6.11 |
| `@firebase/firestore` | high | 4.7.3 | 4.17.2 |
| `@firebase/firestore-compat` | high | 0.3.38 | 0.4.14 |
| `@firebase/functions` | moderate | 0.11.8 | 0.14.0 |
| `@firebase/functions-compat` | moderate | 0.3.14 | 0.5.0 |
| `@firebase/rules-unit-testing` | high | 3.0.4 | 5.0.2 |
| `@firebase/storage` | moderate | 0.13.2 | 0.14.5 |
| `@firebase/storage-compat` | moderate | 0.3.12 | 0.4.5 |
| `@google-cloud/firestore` | moderate | 7.11.6 | removido |
| `@google-cloud/storage` | moderate | 7.22.0 | removido |
| `@grpc/grpc-js` | high | 1.14.6, 1.9.16 | 1.14.7 |
| `firebase` | high | 10.14.1 | 12.19.0 |
| `firebase-admin` | moderate | 13.10.0 | removido |
| `gaxios` | moderate | 6.7.1, 7.3.1 | removido |
| `google-gax` | moderate | 4.6.1 | removido |
| `retry-request` | moderate | 7.0.2 | removido |
| `teeny-request` | moderate | 9.0.0 | removido |
| `undici` | high | 6.19.7 | removido |
| `uuid` | moderate | 9.0.1 | removido |

### Advisories de origem

- [@grpc/grpc-js: In certain configurations, getAuthContext can return unauthorized certificates as though they were authorized](https://github.com/advisories/GHSA-m9gg-hp2v-232j): high, faixa `<1.13.6`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [@grpc/grpc-js: The server transmits some error messages thrown by method handlers to the client in status messages](https://github.com/advisories/GHSA-f596-whhp-79r4): low, faixa `<1.13.6`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [Use of Insufficiently Random Values in undici](https://github.com/advisories/GHSA-c76h-2ccp-4975): moderate, faixa `>=6.0.0 <6.21.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [Undici has an unbounded decompression chain in HTTP responses on Node.js Fetch API via Content-Encoding leads to resource exhaustion](https://github.com/advisories/GHSA-g9mf-h72j-4rw9): moderate, faixa `<6.23.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici Denial of Service attack via bad certificate data](https://github.com/advisories/GHSA-cxrh-j4jr-qwg3): low, faixa `>=6.0.0 <6.21.2`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [Undici: Malicious WebSocket 64-bit length overflows parser and crashes the client](https://github.com/advisories/GHSA-f269-vfmq-vjvj): high, faixa `>=6.0.0 <6.24.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [Undici has an HTTP Request/Response Smuggling issue](https://github.com/advisories/GHSA-2mjp-6q6p-2qxm): moderate, faixa `<6.24.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [Undici has Unbounded Memory Consumption in WebSocket permessage-deflate Decompression](https://github.com/advisories/GHSA-vrm6-8vpv-qv8q): high, faixa `<6.24.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [Undici has Unhandled Exception in WebSocket Client Due to Invalid server_max_window_bits Validation](https://github.com/advisories/GHSA-v9p9-hfj2-hcw8): high, faixa `<6.24.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [Undici has CRLF Injection in undici via `upgrade` option](https://github.com/advisories/GHSA-4992-7rv2-5pvq): moderate, faixa `<6.24.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to HTTP header injection via Set-Cookie percent-decoding](https://github.com/advisories/GHSA-p88m-4jfj-68fv): moderate, faixa `<6.27.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to Set-Cookie SameSite attribute downgrade via permissive substring matching](https://github.com/advisories/GHSA-g8m3-5g58-fq7m): low, faixa `<6.27.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to downstream response desynchronization via retry interceptor](https://github.com/advisories/GHSA-8xcm-r25x-g524): moderate, faixa `<6.28.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to CRLF Injection via blob-like body 'type' property](https://github.com/advisories/GHSA-m8rv-5g2x-5cg5): moderate, faixa `<6.28.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to cookie attribute injection via unsanitized domain and unparsed setCookie fields](https://github.com/advisories/GHSA-v3r7-h72x-cjcm): moderate, faixa `<6.28.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to HTTP response queue poisoning via keep-alive socket reuse](https://github.com/advisories/GHSA-35p6-xmwp-9g52): low, faixa `<6.27.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to downstream response splitting via retry interceptor](https://github.com/advisories/GHSA-r53p-7pc4-xj5r): low, faixa `<6.28.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to Denial of Service via unrequested WebSocket subprotocol](https://github.com/advisories/GHSA-rfgv-xxqx-mfg5): high, faixa `>=6.7.0 <6.28.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to Denial of Service via unbounded memory in the EventSource parser](https://github.com/advisories/GHSA-4qv8-2p9j-2685): moderate, faixa `>=6.5.0 <6.29.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to TLS certificate validation bypass via dropped tls options in Agent](https://github.com/advisories/GHSA-2m5v-pch6-74hx): high, faixa `>=4.0.0 <6.29.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici vulnerable to Denial of Service via TLS 1.2 certificate-changing renegotiation](https://github.com/advisories/GHSA-qrxm-fqhp-jwvm): high, faixa `>=4.2.1 <6.29.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici WebSocket client vulnerable to Denial of Service via unbounded automatic PONG buffering](https://github.com/advisories/GHSA-9fm3-97px-rjf6): moderate, faixa `>=5.15.0 <6.29.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [undici WebSocket client vulnerable to denial of service via fragment count bypass](https://github.com/advisories/GHSA-vxpw-j846-p89q): high, faixa `<6.27.0`. Cadeia removida/atualizada ou override gRPC, conforme tabela.
- [uuid: Missing buffer bounds check in v3/v5/v6 when buf is provided](https://github.com/advisories/GHSA-w5hq-g745-h8pq): moderate, faixa `<11.1.1`. Cadeia removida/atualizada ou override gRPC, conforme tabela.

## Validação realizada

- flutter pub get: sucesso; nenhum aviso de implementação file_picker.
- flutter analyze (sem no-fatal e sem exclusões novas): **No issues found**.
- flutter test --no-pub --concurrency=4: **547 passaram**, sem falhas; mesma contagem inicial.
- flutter build web --release: sucesso. Dry run WASM emitiu incompatibilidades já existentes em dart:html/universal_html; o alvo validado é JavaScript, não WASM.
- npm ci em test/rules: sucesso, lockfile reproduzível.
- npm audit --audit=true: **found 0 vulnerabilities**.
- Firebase emulators:exec com configuração local equivalente (Rules reais e UI desligada), projeto fictício nexosaude-test: **41 testes passaram no Node 20.20.2**, sem falhas/skips.
- Smoke Chromium: file_picker real abriu seletor; arquivo nexo-smoke.txt foi selecionado com bytes, enviado por HTTP a servidor exclusivamente local e ecoado com status 200 e conteúdo idêntico. Harness externo ao checkout, sem credenciais e sem backend Firebase.
- git diff --check: sem problemas.

## Limites e riscos residuais

- Não foram testados uploads/exclusões no Worker/R2 real nem contas reais de Auth; os testes de serviços/documentos cobrem o código disponível com mocks. O smoke confirma seleção web e transporte local, não autorização de armazenamento externo.
- Windows, macOS, Linux nativo, Android e iOS não foram executados. A prioridade e o build validado são web.
- file_picker e bibliotecas JS tiveram mudanças de major; o smoke, a suíte Flutter e a matriz Node 20 passaram. Fazer homologação com contas fictícias antes de distribuir.
- Esta tarefa não corrige o bypass financeiro nem os outros achados da PR #7 que não estão na base escolhida; integrar essa PR é uma decisão separada. Não houve merge nesta rodada.
- Nenhuma pendência de aprovação para as correções locais. Merge e deploy continuam fora da autorização.

## Arquivos modificados

- `lib/models/procedure_model.dart`
- `lib/models/treatment_teeth.dart`
- `lib/screens/agenda/agenda_form_screen.dart`
- `lib/screens/agenda/agenda_manager_screen.dart`
- `lib/screens/care/care_visit_screen.dart`
- `lib/screens/care/remarcar_dialog.dart`
- `lib/screens/clinics/clinic_management_screen.dart`
- `lib/screens/employees/employee_manager_screen.dart`
- `lib/screens/financial/collections_screen.dart`
- `lib/screens/financial/expenses_screen.dart`
- `lib/screens/financial/financial_report_screen.dart`
- `lib/screens/financial/widgets/monthly_package_card.dart`
- `lib/screens/financial/widgets/session_charge_card.dart`
- `lib/screens/master/master_screen.dart`
- `lib/screens/news/ortho_news_screen.dart`
- `lib/screens/operations/clinical_procedures_view.dart`
- `lib/screens/operations/tabs/card_fees_tab.dart`
- `lib/screens/operations/tabs/inventory_tab.dart`
- `lib/screens/operations/tabs/procedures_tab.dart`
- `lib/screens/operations/tabs/settings_tab.dart`
- `lib/screens/operations/tabs/suppliers_tab.dart`
- `lib/screens/patients/create_patient_screen.dart`
- `lib/screens/patients/patient_details_screen.dart`
- `lib/screens/patients/psychology/psychology_kanban_board.dart`
- `lib/screens/patients/tabs/anamnesis_tab.dart`
- `lib/screens/patients/tabs/clinical_record_screen.dart`
- `lib/screens/patients/tabs/odontogram_screen.dart`
- `lib/screens/patients/tabs/patient_docs_tab.dart`
- `lib/screens/patients/tabs/patient_financial_tab.dart`
- `lib/screens/patients/tabs/treatments_tab.dart`
- `lib/screens/psychology/psychology_schedule_form_screen.dart`
- `lib/screens/public/public_evaluation_screen.dart`
- `lib/screens/reports/reports_screen.dart`
- `lib/services/appointment_service.dart`
- `lib/services/clinic_delete_service.dart`
- `lib/services/patient_financial_oracle.dart`
- `lib/services/patient_service.dart`
- `lib/services/pending_counts.dart`
- `lib/services/pix_brcode.dart`
- `lib/services/portal_mirror.dart`
- `lib/services/subscription.dart`
- `lib/services/treatment_service.dart`
- `lib/ui/odontogram/tooth_widget.dart`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `pubspec.lock`
- `pubspec.yaml`
- `test/clinical_registration_view_test.dart`
- `test/clinical_reports_view_test.dart`
- `test/document_service_test.dart`
- `test/rules/package-lock.json`
- `test/rules/package.json`
- `obsidian/auditorias/auditoria-lints-dependencias-2026-11.md` (este relatório).
