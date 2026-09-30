---
operonId: nx-e4
status: stable
priority: A
tags:
  - nexosaude
  - area/acesso
title: E4 — Acesso, menu e multi-clínica
type: epic
updated: 2026-09-30
---

# E4 — Acesso, menu e multi-clínica

**Objetivo:** nenhuma trava hardcoded — tudo que aparece na tela vem do controle de acesso configurável.
**Critério de aceite:** dentista liberado vê Gestão e troca a própria senha; recepção em 2 clínicas troca sozinha; Pix/grade/WhatsApp editáveis com flag sem virar owner.

## Entregas

- `MenuAccess` role-aware (`canShow` + `defaultFor` + matriz de testes): menu sem `if (role)` — ver [[screens/reports/main-dashboard|main-dashboard]], [[session-multitenant]]
- Gestão por abas e seções (9 sub-chaves `g_*`): tabs filtradas + Pix/Grade/Acesso/Dados com trava própria + editor com grupo dedicado
- Rules `clinics` liberam `pixKey/gradeConfig/whatsappNumber` com a flag (publicadas)
- Seletor multi-clínica (owner OU `allowedClinics>1`) + "Gerenciar" trocando de verdade + vínculo editável em Funcionários + reset de senha na ficha
- Administração recolhível com scroll acompanhando; seletor some com 1 clínica
- WhatsApp da clínica (E.164, `normalizeWhatsApp` testado) usado na Avaliação; seção Dados da clínica

## Ver também

- [[screens/operations/operations-manager|operations-manager]], [[screens/operations/operations-tabs|operations-tabs]], [[screens/operations/employee-manager|employee-manager]], [[screens/operations/clinic-management|clinic-management]], [[foundation/04-requisitos|Requisitos]], [[foundation/02-use-cases|CASOS_DE_USO]]
