# Remodelagem — Fase 3: segurança e isolamento (achados, sem publicar)

Auditoria das `firestore.rules` ao vivo (ruleset verificado via API em
01/10: idêntico ao repo) + fluxos públicos. **Nada foi publicado** (plano
exige autorização explícita). Emulador indisponível (sem Java) — sem testes
de rules; validar no Firebase Console antes de publicar qualquer diff.

## Aprovado como está (verificado)

- Portal: token opaco 32 chars, `get` público só no doc, updates por
  allowlist (`statusSessao`, `pedidoRemarcacao`, `avisoPagamento`); remarcação
  nunca aparece como concluída sem a recepção.
- `avisoPagamento` público NÃO quita: o app trata como selo, baixa só na
  tesouraria. Integridade financeira preservada por lógica, não só por regra.
- Isolamento multicínica no servidor (regra F + blocos): owner ou
  `hasClinicAccess`; UI nunca é a única barreira.
- Anamnese pública restrita aos 14 campos; `password_reset` sem e-mail.

## Propostas (diffs NÃO aplicados — decidir e publicar à parte)

### P1. Confirmar/remarcar exigindo token (média)
Hoje `appointments/{id}` aceita `Confirmado` e `remarcar` de anônimo com só o
ID (links `confirmar.html?id=` e portal sem vínculo token↔doc).
```diff
 match /appointments/{appointmentId} {
   allow update: if
     request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status',
 'confirmationDate']) &&
+    request.resource.data.portalToken == resource.data.portalToken &&
     request.resource.data.status == 'Confirmado';
```
Exige antes: incluir `t=` no link do confirmar e enviar `portalToken` no
update (portal.html já tem o token; confirmar.html precisa do parâmetro).
Sem isso, o diff quebra o fluxo atual.

### P2. `users` leitura escopada (média-baixa)
Hoje qualquer autenticado lê qualquer `users/{uid}` (nomes, e-mails, papéis
de todas as clínicas). Proposta: owner/superadmin/próprio + staff da mesma
clínica (overlap de `allowedClinics`). Cuidado: telas de equipe listam
usuários — validar cada leitor antes.

### P3. Anamnese: update público vinculado (baixa)
Update público aceita qualquer `patientId` conhecido. Aceitável hoje (IDs
imprevisíveis + allowlist), mas registrar como risco residual. Endurecer
exigiria token por paciente — muda o fluxo do link; não proposto agora.

## Riscos residuais assumidos

- Links opacos (portal/confirmar) como única barreira: mitigado por
  revogação + allowlists, sem expiração.
- Superadmin enxerga todas as clínicas (desenho da plataforma).
- Sem trilha de quem leu o quê (ver LGPD-5 no backlog).

## Operacionais Fase 4 (triagem — já existem, sem código novo)

Conflitos de agenda (`getBusySlots`), sugestão (nx-132), inbox de
remarcações (badges), busca de pacientes, fluxo consulta→presença→evolução→
próxima (S1–S3), extrato com baixa/estorno, alertas, feedback de erro
(nx-164). **Pendente de decisão de negócio: lista de espera** (não existe;
exige desenho de regra antes de codar).
