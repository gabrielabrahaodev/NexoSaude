---
operonId: nx-s3
status: Finished
priority: A
tags:
  - nexosaude
  - area/atendimento
---

# S3 — Qualidade do atendimento

**Objetivo:** segurança clínica e rotina de turno sem abrir ficha por ficha.
**Critério de aceite:** alertas visíveis antes de atender; presença do turno em lote; próxima sessão sugerida (não montada).

## Tarefas

### nx-131 — Faixa fixa de alertas clínicos
Alergias, diabetes, hipertensão, gestante e cardíaco (a anamnese já coleta) em faixa sempre visível no topo da ficha — dividir apresentação com o wizard de resumo de contexto (`PatientSmartContextCard`), sem duplicar fonte. Ver [[care-day]].
**Aceite:** profissional vê alertas antes de atender, vindos da mesma fonte do resumo.

### nx-132 — Próxima sessão sugerida
Ao abrir a ficha, sugerir mesmo dia/hora da semana seguinte já validado contra a grade (livre/ocupado visível): vira "confirmar" em vez de "montar". Ver [[care-day]].
**Aceite:** sugestão aparece pronta; 1 toque confirma se livre.

### nx-133 — Presença em massa no Meu dia
Checkbox por linha + "Confirmar selecionados" no `CareDayScreen` para presença em lote no início do turno. Ver [[care-day]].
**Aceite:** turno confirmado sem abrir cada ficha; falha parcial avisa quais faltaram.
