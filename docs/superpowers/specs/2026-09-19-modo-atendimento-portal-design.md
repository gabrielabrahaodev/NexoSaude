# Modo Atendimento + Portal do Paciente — Design

Data: 2026-09-19. Status: aprovado em 3 seções, aguardando revisão do spec.

## 1. Contexto e objetivo

Rotina do profissional (dentista/psicólogo) hoje é fragmentada em 4 telas
(agenda, prontuário, cobrança, WhatsApp). Paciente depende da recepção para
confirmar sessão e saber débitos (no-show + carga operacional).
Objetivo: fundir o existente numa rotina linear (Modo Atendimento) e dar
autonomia ao paciente via link público (Portal), respeitando os limites do
plano Spark (sem Cloud Functions: nada executa sozinho no servidor; tudo
nasce de um clique no app ou de escrita pública com allowlist).

## 2. Não-objetivos (YAGNI)

- Modelos de evolução editáveis pelo owner (v1: 4–6 fixos por tipo de clínica).
- Automação de WhatsApp agendado (impossível no Spark; envio segue manual via `wa.me`).
- Remarcação automática pelo paciente (vira pendência para a recepção).
- Histório/financeiro completo no portal (só próximos + débitos em aberto).

## 3. Subprojeto 1 — Modo Atendimento

Novo item de menu "Atendimento" (roles: dentista, psicólogo, owner).

### 3.1 Componentes (tudo reuse, nenhuma collection nova)

- **Meu dia:** lista só de hoje do profissional logado
  (`clinicId` + `dentistId == uid` + dia atual via
  `AppointmentService.getByDateRange`). Leitura mínima, amiga da cota.
  Linha: horário, paciente, status, selo de pagamento.
- **Ficha de atendimento** (toque no paciente), 3 blocos:
  1. **Evolução rápida:** chips de modelo por procedimento + texto livre,
     grava via `ClinicalRecordService` (mesmo destino do prontuário atual).
  2. **Cobrar:** valor da sessão → cria lançamento + Pix via
     `FinancialService` (mesmo `recordingFor` de hoje).
  3. **Próxima sessão:** cria agendamento (`AppointmentService.add`) +
     abre `wa.me` com texto pronto de confirmação.
- Tema claro/escuro via `AppColors`; filtro de profissional herdado
  (`dentistId == uid` para dentista/psicólogo).

### 3.2 Fluxo de dados

Leituras limitadas ao dia corrente. Escritas reaproveitam services e rules
existentes (nenhuma rule nova neste subprojeto).

## 4. Subprojeto 2 — Portal do paciente (decisão b)

Link público por paciente com próximas sessões + débitos em aberto + Pix +
"avisei que paguei". Leitura via espelho (rules não enxergam token de URL,
então `patients/` e `financial/` seguem fechados).

### 4.1 Espelho `portal/{token}`

- `portalToken`: string aleatória de 32 chars, gerada no cadastro
  (`create_patient_screen`), revogável com 1 clique (gera novo; link antigo morre).
- Conteúdo do espelho (mínimo): próximas 3 sessões (data, profissional,
  status) + débitos em aberto (vencimento, valor) + chave Pix da clínica.
  Nada de histórico, nada de dados de outros pacientes.
- Escrita do espelho SOMENTE pelo app logado, via helper único
  `syncPortalMirror()` chamado nos pontos de escrita existentes:
  agendar/confirmar/cancelar sessão, criar lançamento, dar baixa,
  cancelar lançamento. Nenhum outro lugar escreve no espelho.
- Custo: 1 doc por paciente; portal lê 1 doc (cota irrisória).

### 4.1b Espelho de disponibilidade `portal_slots/{clinicId}` (compartilhado)

- Conteúdo: `{dentistId: {data: ["HH:mm", ...]}}` com os horários LIVRES dos
  próximos 60 dias. Só horários — zero dado de paciente, público sem drama.
- Grade-fonte v1: a mesma da agenda (08:30–20:00, slots de 30min, hardcoded
  como hoje). Grade configurável pelo owner é futuro (fora do v1).
- Manutenção atômica: agendar/bloquear = `arrayRemove` do slot;
  cancelar/desbloquear = `arrayUnion` de volta. Concorrência segura
  (transform atômico). +1 escrita por mutação de agenda (cota ok).
- Mudança de grade (horário do dentista) exige rebuild: rotina
  `rebuildSlotsMirror()` (botão no Gestão v1; automático quando a grade
  virar configurável).
- Invariante: o espelho é consultivo — o aceite SEMPRE revalida no dado
  vivo (`getBusySlots`). Pior caso de deriva: mostrar slot errado, nunca
  double-booking real.

### 4.2 Tela pública e escritas com allowlist (padrão Confirmado/anamnese)

- Rota pública Flutter `#/portal?t=TOKEN` (mesmo padrão da avaliação pública).
- **Escrita pública (allowlist, padrão Confirmado/anamnese):** botões **Confirmar** / **Pedir remarcação** gravam só `{status, updatedAt}` no espelho + no agendamento. Pedido de remarcação vira pendência pra recepção (status `remarcar`), não remarca sozinho.
- Leituras: `get` público em `portal/{token}` (doc opaco; sem token não há
  como descobrir o ID) + `get` público em `portal_slots/{clinicId}`.
- Escritas públicas restritas a:
  - `portal/{token}`: `{statusSessao, pedidoRemarcacao, propostasRecusadas,
    avisoPagamento, updatedAt}` (allowlist rígida de chaves, como a anamnese).
    `pedidoRemarcacao = {sessaoId, novaData}` (escolhida da lista de livres);
    `propostasRecusadas` = array de datetimes (só cresce via app interno).
  - `appointments/{id}`: só `status` em {`Confirmado`, `remarcar`} — espelhando
    a rule do Confirmado que já existe.
- "Pedir remarcação" e "Avisei que paguei" viram pendências para recepção/
  tesouraria (não executam sozinhas).
- **Fluxo remarcação:** paciente propõe (slot livre − `propostasRecusadas`)
  → pendência com selo na agenda + item no "Meu dia" do dentista responsável
  → recepção/dentista aprova (revalida `getBusySlots`, atualiza agendamento +
  `syncPortalMirror`) ou **recusa e avisa** (abre `wa.me` com texto pronto +
  link; proposta vai pra `propostasRecusadas` e some da lista DESSE paciente —
  segue livre para os demais).
- Débitos detalhados e baixa seguem no app interno.

### 4.3 Rules novas (firestore.rules)

- `match /portal/{token}`: `allow get: if true`; escrita sem login SOMENTE
  via `diff().affectedKeys().hasOnly([...])` (allowlist, padrão anamnese);
  `create/delete` e demais escritas: só autenticado (o app via
  `syncPortalMirror`).
- `appointments`: estender o allowlist público existente com
  `status in ['Confirmado', 'remarcar']` restrito às chaves de status.

### 4.4 Abuso, privacidade e LGPD

- Token longo não-sequencial; espelho mínimo; revogação com 1 clique.
- Dado financeiro via link exige consentimento do paciente (aviso no
  cadastro + aceite registrado); responsabilidade do owner.
- Sem login no portal: perda do aparelho = revogar token.

## 5. Erros que importam

- Espelho dessincronizado (pior risco: valor errado no portal). Mitiga:
  helper único + teste que quebra se novo ponto de escrita não sincronizar.
- Espelho de slots derivado (grade mudou e ninguém rebuildou). Mitiga:
  botão `rebuildSlotsMirror` no Gestão + aceite sempre revalida no vivo.
- Link vazado → revogar token.
- Quota → portal lê 1 doc; Modo Atendimento lê só o dia.
- Falha de rede no balcão → persistence local já ativa; toasts de erro
  via `toast(context, msg, error: true)`.

## 6. Testes

- Unitários: `syncPortalMirror` (fixtures → espelho esperado),
  geração/revogação de token (formato, unicidade), helpers novos.
- Sem widget test com Firebase (padrão do repo: baseline quebra sem backend).
- `flutter analyze` zero errors antes de cada entrega.

## 7. Ordem de construção

1. Modo Atendimento (valor imediato).
2. Espelho + `syncPortalMirror` + rules do portal.
3. Tela pública do portal (sessões + débitos + Pix + "avisei que paguei").
4. Revogar token + aceite LGPD no cadastro.

## 8. Critérios de aceite

- Profissional conclui evolução + cobrança + próxima sessão sem sair da
  ficha de atendimento.
- Paciente com link confirma sessão e vê débitos + Pix; "avisei que paguei"
  aparece como pendência interna.
- Revogar token invalida o link antigo imediatamente.
- Slot recusado some da lista do paciente e segue livre para os demais;
  aprovação com slot ocupado no vivo é barrada com aviso.
- Nenhuma tela nova lê collection inteira (cota sob controle).
