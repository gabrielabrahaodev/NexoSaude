# Migração p/ projeto novo (rebrand)

Ordem segura: o projeto antigo **não é tocado** até o novo estar 100% validado.

## 1. Criar o projeto novo (você, 5 min, Console Firebase)
1. Console → Add project → nome de exibição da nova marca.
2. Project ID: minúsculo, único global (ex.: `clinigest-xxxxx`) — **imutável**, escolha bem.
3. Ative **Authentication** (Email/Senha) e **Firestore** (modo produção, região `southamerica-east1` se disponível).
4. IAM: crie 2 chaves service account (JSON) — `old-key.json` (projeto antigo) e `new-key.json` (novo). Salve em `migrate/` (ignorado pelo git — NUNCA commite nem cole no chat).

## 2. Migrar Auth (usuários com a mesma senha)
```bash
firebase auth:export usuarios.json --project odontocontrole-1c701
firebase auth:import usuarios.json --project NOVO-ID
```
Confere no Console → Authentication a contagem. UIDs preservados → vínculos intactos.

## 3. Migrar Firestore (tudo, mesmos IDs)
```bash
cd migrate
npm install
node migrate.js old-key.json new-key.json
```
Confere os contadores impressos (patients, appointments, financial, etc.) x Console do antigo.

## 4. Apontar o app
```bash
cd ..
flutterfire configure --project=NOVO-ID   # regenera firebase_options.dart
```
- Atualizar `web/anamnese.html` e `web/confirmar.html` (firebaseConfig).
- `.firebaserc` → default = NOVO-ID.
- `firebase deploy --only firestore:rules,indexes` (regras já valem p/ o novo).
- `flutter build web` + `firebase deploy --only hosting`.
- Rebrand visual (textos/logo) conforme decisão de marca.

## 5. Validar no novo (checklist)
Login (2 usuários) → agenda → ficha paciente → receber Pix → relatório/livro → cobrança WhatsApp → kanban psico → tema → acesso. Tudo ok?

## 6. Descomissionar o antigo (SÓ depois do passo 5)
Recomendado: manter 30 dias parado como backup e só então excluir o projeto no Console (Configurações → Excluir). Não exclua antes.
