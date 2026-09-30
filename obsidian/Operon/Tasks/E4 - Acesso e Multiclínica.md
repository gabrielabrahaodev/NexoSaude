---
operonId: nx-e4
status: Finished
priority: A
tags:
  - nexosaude
  - area/acesso
---

# E4 — Acesso, menu e multi-clínica

**Objetivo:** nenhuma trava hardcoded — tudo que aparece na tela vem do controle de acesso configurável.
**Critério de aceite:** dentista liberado vê Gestão e troca a própria senha; recepção em 2 clínicas troca sozinha; Pix/grade/WhatsApp editáveis com flag sem virar owner.

## Entregas

- `MenuAccess` role-aware (`canShow` + `defaultFor` + matriz de testes): menu sem `if (role)` — ver [[main-dashboard]], [[session-multitenant]]
- Gestão por abas e seções (9 sub-chaves `g_*`): tabs filtradas + Pix/Grade/Acesso/Dados com trava própria + editor com grupo dedicado
- Rules `clinics` liberam `pixKey/gradeConfig/whatsappNumber` com a flag (publicadas)
- Seletor multi-clínica (owner OU `allowedClinics>1`) + "Gerenciar" trocando de verdade + vínculo editável em Funcionários + reset de senha na ficha
- Administração recolhível com scroll acompanhando; seletor some com 1 clínica
- WhatsApp da clínica (E.164, `normalizeWhatsApp` testado) usado na Avaliação; seção Dados da clínica

## Ver também

- [[operations-manager]], [[operations-tabs]], [[employee-manager]], [[clinic-management]], [[Requisitos]], [[foundation/02-use-cases|CASOS_DE_USO]]
