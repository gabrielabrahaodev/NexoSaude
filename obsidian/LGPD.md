# LGPD — NexoSaúde (análise e sugestões)

Documento para análise posterior. Nada aqui foi implementado — são sugestões
aguardando decisão. Data da análise: 2026-10-05.

## Papéis

- **Controladora:** cada clínica (decide finalidade dos dados dos pacientes).
- **Operadora:** NexoSaúde/SaaS (trata dados por conta das clínicas).
- **Suboperadores:** Google/Firebase (banco, auth, hosting), Meta/WhatsApp
  (mensagens de cobrança/confirmação), Cloudinary (documentos/imagens).

## Criptografia — veredito

Nada a criptografar no app. O Firestore já criptografa em repouso (AES-256)
e em trânsito (TLS). A LGPD não exige criptografia nominalmente (art. 46
pede "medidas de segurança"); cifrar campos quebraria buscas e índices e
criaria gestão de chaves desproporcional no plano Spark. Exceção: o Export
gera JSON/CSV em texto puro — ali vale ZIP com senha (sugestão 3).

## O que já está conforme

- Consentimento portal/WhatsApp explícito, default desmarcado,
  `accepted/at/via/by`; sweep apagou 415 espelhos sem aceite (E2).
- Revogação efetiva (mata link + espelho, `accepted:false`/`revokedAt`).
- Rules por `clinicId`, anamnese com allowlist de 14 campos, segredos só owner.
- Cascatas de eliminação (paciente, clínica nx-160, orçamento nx-168).
- Token opaco de 32 chars, sem dado sensível em URL.
- Chaves de serviço (`migrate/*-key.json`) fora do git (ignoradas).

## Sugestões (decidir: fazer / adiar / descartar)

| # | Sugestão | Base | Esforço | Decisão |
|---|---|---|---|---|
| 1 | Contrato operador↔controladora (DPA) + Termos/Privacidade na landing e no app | art. 39, 9º | M (texto jurídico + aceite versionado) | ☐ |
| 2 | Estender o aceite ao tratamento de dados de saúde (anamnese/prontuário), exibido no prontuário | art. 11 | S | ☐ |
| 3 | ZIP com senha no Export + log de quem exportou (`export_audits`, owner-only) | art. 37, 46 | S | ☐ |
| 4 | Aviso sobre compartilhamento com a Meta (WhatsApp) + nota de suboperadores | art. 5º, 39 | S | ☐ |
| 5 | Trilha mínima de auditoria (só eventos sensíveis, de olho na cota do Spark) | art. 37, 46 | M | ☐ |
| 6 | `debugPrint` com PII atrás de `kDebugMode` | art. 46 | S | ☐ |
| 7 | Menores de idade: há <12 anos? Se sim, responsável + consentimento parental | art. 14 | pergunta | ☐ |
| 8 | Designar DPO + plano de incidentes (notificar ANPD/titulares) | art. 41, 48 | formal | ☐ |
| 9 | Justificar/logar acesso do superadmin a todas as clínicas | art. 6º VII | — | ☐ |
| 10 | Política de retenção por tipo de dado (soft-delete hoje guarda tudo) | art. 16 | — | ☐ |

## Ver também

- [[specs/2026-09-19-modo-atendimento-portal-design]] §4.4 (abuso, privacidade)
- [[screens/patient-details]] (máquina de estados do aceite)
- [[Requisitos]] §16 / RN-71
