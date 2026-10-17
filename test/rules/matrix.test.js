// Matriz de autorização das firestore.rules (reavaliação 16/10 §13).
// Roda contra o Firestore Emulator:
//   firebase emulators:exec --only firestore "npm --prefix test/rules test"
// Perfis: anon / staff mesma clínica / staff outra clínica / owner outra /
// owner própria / superadmin. NÃO publicar rules novas até a matriz passar.
const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8');

const A = 'clinicA';
const B = 'clinicB';
const TRIAL_END = new Date('2099-01-01T00:00:00.000Z');

async function seed(admin) {
  const db = admin.firestore();
  await db.doc(`users/ownerA`).set({
    role: 'owner', name: 'Owner A', allowedClinics: [A], status: 'Ativo', email: 'a@x',
  });
  await db.doc(`users/staffA`).set({
    role: 'recepcionista', name: 'Staff A', allowedClinics: [A], status: 'Ativo',
    email: 's@x', phone: null, whatsapp: null, cpf: null, menuAccess: null,
  });
  await db.doc(`users/staffB`).set({
    role: 'recepcionista', name: 'Staff B', allowedClinics: [B], status: 'Ativo', email: 'b@x',
  });
  await db.doc(`users/pendingU`).set({
    role: 'recepcionista', name: 'Pending', allowedClinics: [A], status: 'pending_approval',
    email: 'p@x',
  });
  await db.doc(`users/ownerB`).set({
    role: 'owner', name: 'Owner B', allowedClinics: [B], status: 'Ativo', email: 'o@x',
  });
  await db.doc(`users/root`).set({
    role: 'superadmin', allowedClinics: [], status: 'Ativo', email: 'r@x',
  });
  await db.doc(`clinics/${A}`).set({
    name: 'A', ownerId: 'ownerA', trialEndsAt: TRIAL_END,
    blockedByAdmin: false,
  });
  await db.doc(`clinics/${B}`).set({
    name: 'B', ownerId: 'ownerB', trialEndsAt: TRIAL_END,
    blockedByAdmin: true,
  });
  for (const [clinicId, uid, role, status, email, name] of [
    [A, 'ownerA', 'owner', 'Ativo', 'a@x', 'Owner A'],
    [A, 'staffA', 'recepcionista', 'Ativo', 's@x', 'Staff A'],
    [A, 'pendingU', 'recepcionista', 'pending_approval', 'p@x', 'Pending'],
    [B, 'ownerB', 'owner', 'Ativo', 'o@x', 'Owner B'],
    [B, 'staffB', 'recepcionista', 'Ativo', 'b@x', 'Staff B'],
  ]) {
    await db.doc(`clinics/${clinicId}/members/${uid}`).set({
      uid, name, role, status, createdAt: new Date(), updatedAt: new Date(),
    });
    await db.doc(`clinics/${clinicId}/members_private/${uid}`).set({
      uid, name, email, role, status, phone: '', whatsapp: '', cpf: '',
      menuAccess: {}, allowedClinics: [clinicId],
      createdAt: new Date(), updatedAt: new Date(),
    });
  }
  await db.doc(`patients/p1`).set({
    clinicId: A, portalToken: 'tok123', anamnesisToken: 'ana456',
    lgpdPortalConsent: { accepted: true },
  });
  await db.doc('patients/p2').set({ clinicId: B });
  await db.doc('portal/tok123').set({
    patientId: 'p1', clinicId: A, sessions: [], debts: [],
  });
  await db.doc('portal/oldTok').set({
    patientId: 'p1', clinicId: A, sessions: [], debts: [],
  });
  await db.doc(`appointments/ap1`).set({
    clinicId: A, patientId: 'p1', status: 'Agendado', portalToken: null,
  });
  // Legado com token obsoleto carimbado (limpeza pendente): omitir o token
  // NÃO confirma (fonte única = cadastro atual).
  await db.doc(`appointments/ap2`).set({
    clinicId: A, patientId: 'p1', status: 'Agendado', portalToken: 'oldTok',
  });
  // Anamnese: doc id == patientId (como o app grava).
  await db.doc(`anamnesis/p1`).set({ patientId: 'p1', smoker: false });
  await db.doc(`password_reset_requests/reqGlobal`).set({
    email: 'g@g.com', status: 'pending', createdAt: new Date(),
  });
  await db.doc(`password_reset_requests/reqA`).set({
    email: 'a@a.com', status: 'pending', createdAt: new Date(), clinicId: A,
  });
  await db.doc(`financial/f1`).set({
    clinicId: A, patientId: 'p1', amount: 100,
  });
  await db.doc('patients/pDelete').set({ clinicId: A, name: 'Delete fixture' });
  await db.doc('inventory/iA').set({ clinicId: A, name: 'item A' });
  await db.doc('inventory/iB').set({ clinicId: B, name: 'item B' });
  await db.doc('suppliers/sA').set({ clinicId: A, name: 'supplier A' });
  await db.doc('expenses/eA').set({ clinicId: A, amount: 10 });
  await db.doc('lab_orders/lA').set({ clinicId: A, status: 'new' });
  await db.doc(`portal_slots/${A}`).set({ 'staff.d1': [] });
}

describe('matriz reavaliação P0/P1', () => {
  let env;
  before(async () => {
    env = await initializeTestEnvironment({
      projectId: 'nexosaude-test',
      firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
    });
    await env.withSecurityRulesDisabled(async (ctx) => seed(ctx));
  });
  after(async () => env.cleanup());

  const ctx = (uid) =>
    uid == null
      ? env.unauthenticatedContext()
      : env.authenticatedContext(uid);

  it('P0-1: owner não promove a si mesmo (role imutável)', async () => {
    const db = ctx('ownerA').firestore();
    await assertFails(db.doc('users/ownerA').update({ role: 'superadmin' }));
  });

  it('P0-1: owner não edita usuário de outra clínica', async () => {
    const db = ctx('ownerA').firestore();
    await assertFails(
      db.doc('users/staffB').update({ allowedClinics: [A, B] }));
  });

  it('P0-1: owner vincula staff à própria clínica', async () => {
    const db = ctx('ownerA').firestore();
    await assertSucceeds(
      db.doc('users/staffA').update({ status: 'Ativo' }));
  });

  it('P0: users não pode ser enumerado; diretório de membros é por clínica', async () => {
    const staff = ctx('staffA').firestore();
    await assertFails(staff.collection('users').get());
    await assertFails(staff.collection('users')
      .where('allowedClinics', 'array-contains', A).get());
    await assertSucceeds(ctx('root').firestore().collection('users').get());
    await assertFails(staff.doc('users/staffB').get());
    await assertFails(staff.doc('users/ownerA').get());
    await assertFails(staff.doc('users/pendingU').get());
    await assertSucceeds(staff.doc('users/staffA').get());
    await assertSucceeds(ctx('ownerA').firestore().doc('users/staffA').get());

    const publicMembers = staff.collection('clinics').doc(A).collection('members');
    await assertSucceeds(publicMembers.get());
    const publicMember = await assertSucceeds(publicMembers.doc('staffA').get());
    for (const field of ['email', 'phone', 'whatsapp', 'cpf', 'menuAccess', 'allowedClinics']) {
      assert.equal(Object.prototype.hasOwnProperty.call(publicMember.data(), field), false,
        'o diretório público não deve conter ' + field);
    }

    const privateMembers = staff.collection('clinics').doc(A).collection('members_private');
    await assertFails(privateMembers.get());
    await assertFails(privateMembers.doc('staffA').get());
    const ownerPrivate = ctx('ownerA').firestore()
      .collection('clinics').doc(A).collection('members_private');
    await assertSucceeds(ownerPrivate.get());
    await assertSucceeds(ownerPrivate.doc('staffA').get());

    await assertFails(ctx('staffB').firestore().collection('clinics')
      .doc(A).collection('members').get());
    await assertFails(ctx(null).firestore().collection('clinics')
      .doc(A).collection('members').get());
  });

  it('P0: espelho público é mínimo e coerente com users/{uid}', async () => {
    const owner = ctx('ownerA').firestore();
    await assertSucceeds(owner.doc('clinics/clinicA/members/staffA')
      .update({ updatedAt: new Date() }));
    await assertFails(owner.doc('clinics/clinicA/members/staffA')
      .update({ email: 'leak@example.test' }));
    await assertFails(owner.doc('clinics/clinicA/members/ghost').set({
      uid: 'ghost', name: 'Ghost', role: 'recepcionista', status: 'Ativo',
      createdAt: new Date(), updatedAt: new Date(),
    }));
    await assertFails(owner.doc('clinics/clinicA/members/staffB')
      .update({ updatedAt: new Date() }));
  });

  it('P0: perfil e espelhos de novo funcionário são atômicos', async () => {
    const owner = ctx('ownerA').firestore();
    const batch = owner.batch();
    const uid = 'newStaff';
    const now = new Date();
    batch.set(owner.doc('users/' + uid), {
      name: 'Novo Funcionário', cpf: '123', email: 'new@example.test',
      role: 'dentist', allowedClinics: [A], createdAt: now, status: 'Ativo',
    });
    batch.set(owner.doc('clinics/' + A + '/members/' + uid), {
      uid, name: 'Novo Funcionário', role: 'dentist', status: 'Ativo',
      createdAt: now, updatedAt: now,
    });
    batch.set(owner.doc('clinics/' + A + '/members_private/' + uid), {
      uid, name: 'Novo Funcionário', email: 'new@example.test',
      role: 'dentist', status: 'Ativo', phone: '', whatsapp: '', cpf: '123',
      menuAccess: {}, allowedClinics: [A], createdAt: now, updatedAt: now,
    });
    await assertSucceeds(batch.commit());
  });

  it('P0: espelho privado valida campos contra users e é restrito ao owner', async () => {
    const owner = ctx('ownerA').firestore();
    const privateRef = owner.doc('clinics/clinicA/members_private/staffA');
    await assertSucceeds(privateRef.update({ updatedAt: new Date() }));
    await assertFails(privateRef.update({ cpf: '12345678900' }));
    await assertFails(ctx('staffA').firestore()
      .doc('clinics/clinicA/members_private/staffA').get());
    await assertFails(ctx('staffA').firestore()
      .doc('clinics/clinicA/members_private/staffA').update({ cpf: 'x' }));
  });

  it('P0: clinics não é enumerável entre tenants', async () => {
    const owner = ctx('ownerA').firestore();
    await assertFails(owner.collection('clinics').get());
    await assertSucceeds(owner.collection('clinics')
      .where('ownerId', '==', 'ownerA').get());
    await assertFails(ctx('staffB').firestore().doc(`clinics/${A}`).get());
    await assertSucceeds(ctx('staffA').firestore().doc(`clinics/${A}`).get());
    await assertFails(ctx(null).firestore().doc(`clinics/${A}`).get());
  });

  it('P0: registros operacionais não podem apontar para paciente de outro tenant', async () => {
    const db = ctx('staffA').firestore();
    await assertSucceeds(db.doc('appointments/apptSameTenant').set({
      clinicId: A, patientId: 'p1', status: 'Agendado',
    }));
    await assertFails(db.doc('appointments/apptCrossTenant').set({
      clinicId: A, patientId: 'p2', status: 'Agendado',
    }));
    await assertFails(db.doc('appointments/ap1').update({
      patientId: 'p2',
    }));
  });

  it('P0-2: staff de outra clínica não altera financeiro', async () => {
    const db = ctx('staffB').firestore();
    await assertFails(db.doc('financial/f1').update({ amount: 999 }));
  });

  it('P1: aviso financeiro anônimo exige token atual do paciente vinculado', async () => {
    const db = ctx(null).firestore();
    await assertFails(db.doc('financial/f1').update({
      avisoPagamento: { at: new Date() }, updatedAt: new Date(),
    }));
    await assertFails(db.doc('financial/f1').update({
      avisoPagamento: { at: new Date(), portalToken: 'wrong' },
      updatedAt: new Date(),
    }));
    await assertSucceeds(db.doc('financial/f1').update({
      avisoPagamento: { at: new Date(), portalToken: 'tok123' },
      updatedAt: new Date(),
    }));
    await assertFails(db.doc('financial/f1').update({ amount: 1 }));
  });

  it('P1: portal limita escritas autenticadas ao espelho do token atual', async () => {
    const owner = ctx('ownerA').firestore();
    await assertSucceeds(owner.doc('portal/tok123').update({
      clinicName: 'Clínica A atualizada',
    }));
    await assertFails(owner.doc('portal/tok123').update({
      unexpectedField: 'not allowed',
    }));
    await assertFails(owner.doc('portal/tok123').update({
      patientId: 'p2',
    }));
    await assertFails(owner.doc('portal/tok123').update({
      clinicId: B,
    }));
  });

  it('P1: portal só lê espelho com token atual e consentimento aceito', async () => {
    const anon = ctx(null).firestore();
    await assertSucceeds(anon.doc('portal/tok123').get());
    await assertFails(anon.doc('portal/oldTok').get());
    await assertFails(anon.doc('portal/not-a-token').get());
    await assertSucceeds(anon.doc('portal/tok123').update({
      avisoPagamento: { ids: ['f1'], at: new Date() },
    }));
    await assertFails(anon.doc('portal/oldTok').update({
      avisoPagamento: { ids: ['f1'], at: new Date() },
    }));
  });

  it('P1-5: anônimo confirma COM token ATUAL; sem token e velho negam', async () => {
    const db = ctx(null).firestore();
    // Link válido (token atual do cadastro).
    await assertSucceeds(db.doc('appointments/ap1').update({
      status: 'Confirmado', portalToken: 'tok123',
    }));
    // Omitir o token NÃO confirma, mesmo com carimbo obsoleto no doc.
    await assertFails(db.doc('appointments/ap2').update({
      status: 'Confirmado', confirmationDate: new Date(),
    }));
    // Link antigo (token girado) NÃO confirma nem remarca.
    await assertFails(db.doc('appointments/ap1').update({
      status: 'Confirmado', portalToken: 'oldTok',
    }));
    await assertFails(db.doc('appointments/ap1').update({
      status: 'remarcar', proposedDate: new Date(), portalToken: 'oldTok',
    }));
    await assertFails(db.doc('appointments/ap1').update({
      status: 'Confirmado', portalToken: '',
    }));
  });

  it('P0-2: staff de outra clínica não confirma sem token válido', async () => {
    const db = ctx('staffB').firestore();
    // Sem o token do paciente, auth sozinho não basta (antes bastava).
    await assertFails(db.doc('appointments/ap1').update({
      status: 'Confirmado', portalToken: 'errado',
    }));
  });

  it('P1-3: owner não escreve trial/bloqueio; superadmin sim', async () => {
    const db = ctx('ownerA').firestore();
    await assertFails(
      db.doc(`clinics/${A}`).update({ blockedByAdmin: true }));
    await assertFails(
      db.doc(`clinics/${A}`).update({ trialEndsAt: new Date() }));
    await assertSucceeds(db.doc(`clinics/${A}`).update({ name: 'A2' }));
    const root = ctx('root').firestore();
    await assertSucceeds(
      root.doc(`clinics/${A}`).update({ blockedByAdmin: true }));
    // Higiene: restaura a clínica p/ os testes seguintes (bloqueio ativo
    // negaria todo acesso operacional da clínica A adiante).
    await assertSucceeds(
      root.doc(`clinics/${A}`).update({ blockedByAdmin: false, name: 'A' }));
  });

  it('P1-3: trava enforceable — clínica bloqueada nega operacional', async () => {
    const db = ctx('staffB').firestore();
    await assertFails(db.collection('patients').add({ clinicId: B }));
    const root = ctx('root').firestore();
    await assertSucceeds(root.collection('patients').add({ clinicId: B }));
  });

  it('P1-4: trial com uid próprio passa; de outro nega; anônimo nega', async () => {
    const good = {
      nome: 'Novo', whatsapp: '11999999999', email: 'n@n.com',
      clinicName: 'Clinica C', type: 'dental', uid: 'ownerA',
      status: 'solicitado', createdAt: new Date(),
    };
    await assertSucceeds(
      ctx('ownerA').firestore().collection('trial_requests').add(good));
    await assertFails(
      ctx('staffA').firestore().collection('trial_requests').add(good));
    await assertFails(
      ctx(null).firestore().collection('trial_requests').add(good));
  });

  it('P1-6: projeção pública lê sem login; sem listagem; lead válido passa', async () => {
    const anon = ctx(null).firestore();
    await assertFails(anon.collection('public_clinics').get());
    const root = ctx('root').firestore();
    await root.doc('public_clinics/pub1').set({
      name: 'Pub', whatsappNumber: '119', updatedAt: new Date(),
    });
    await assertSucceeds(anon.doc('public_clinics/pub1').get());
    await assertSucceeds(anon.collection('public_clinics/pub1/leads').add({
      answers: ['a'], score: 10, createdAt: new Date(),
      origin: 'web_form', status: 'new_lead',
    }));
    await assertFails(anon.collection('public_clinics/pub1/leads').add({
      answers: [], score: 10, createdAt: new Date(),
      origin: 'web_form', status: 'hacked',
    }));
  });

  it('P2-8: slots — staff de outra clínica não escreve; anônimo não lista', async () => {
    const db = ctx('staffB').firestore();
    await assertFails(db.doc(`portal_slots/${A}`).set({ x: 1 }));
    await assertFails(ctx(null).firestore().collection('portal_slots').get());
    await assertSucceeds(ctx(null).firestore().doc(`portal_slots/${A}`).get());
  });

  it('P1: owner só cria unidade herdando trial; staff e extensão negados', async () => {
    const ownerA = ctx('ownerA').firestore();
    await assertSucceeds(ownerA.collection('clinics').add({
      name: 'Unidade 2', type: 'dental', ownerId: 'ownerA',
      trialEndsAt: TRIAL_END, blockedByAdmin: false, createdAt: new Date(),
    }));
    await assertFails(ownerA.collection('clinics').add({
      name: 'Sem trial', type: 'dental', ownerId: 'ownerA',
      createdAt: new Date(), blockedByAdmin: false,
    }));
    await assertFails(ownerA.collection('clinics').add({
      name: 'Fake', type: 'dental', ownerId: 'ownerA',
      trialEndsAt: new Date('2100-01-01T00:00:00.000Z'),
      blockedByAdmin: false, createdAt: new Date(),
    }));
    await assertFails(ctx('staffA').firestore().collection('clinics').add({
      name: 'Staff clinic', type: 'dental', ownerId: 'staffA',
      trialEndsAt: TRIAL_END, blockedByAdmin: false, createdAt: new Date(),
    }));
    await assertSucceeds(ctx('root').firestore().collection('clinics').add({
      name: 'M', type: 'dental', ownerId: 'ownerA',
      trialEndsAt: TRIAL_END, blockedByAdmin: false, createdAt: new Date(),
    }));
  });

  it('P1: deletes operacionais usam o clinicId antigo sem request.resource', async () => {
    const owner = ctx('ownerA').firestore();
    await assertSucceeds(owner.doc('patients/pDelete').delete());
    await assertSucceeds(owner.doc('inventory/iA').delete());
    await assertSucceeds(owner.doc('suppliers/sA').delete());
    await assertSucceeds(owner.doc('expenses/eA').delete());
    await assertSucceeds(owner.doc('lab_orders/lA').delete());
    await assertFails(owner.doc('inventory/iB').delete());
  });

  it('P1: um tenant não transfere documentos operacionais para sua clínica', async () => {
    await assertFails(ctx('ownerA').firestore().doc('inventory/iB')
      .update({ clinicId: A }));
    await assertFails(ctx('ownerA').firestore().doc('suppliers/sA')
      .update({ clinicId: B }));
  });

  it('P1: staff não se dá menuAccess; owner gerencia e staff opera', async () => {
    const staffA = ctx('staffA').firestore();
    await assertFails(
      staffA.doc('users/staffA').update({ menuAccess: { g_pix: true } }));
    await assertSucceeds(
      ctx('ownerA').firestore().doc('users/staffA').update({
        menuAccess: { g_pix: true },
      }));
    await assertSucceeds(
      staffA.doc(`clinics/${A}`).update({ pixKey: 'pix@x' }));
    await assertFails(
      ctx('staffB').firestore().doc(`clinics/${A}`).update({ pixKey: 'y' }));
  });

  it('P1: pendente não lista nem opera; próprio get passa', async () => {
    const p = ctx('pendingU').firestore();
    await assertFails(p.collection('users').get());
    await assertFails(p.collection('clinics').get());
    await assertFails(p.collection('patients').add({ clinicId: A }));
    await assertSucceeds(p.doc('users/pendingU').get());
  });

  it('P1: reset — global só Master; interna escopada; global nega lista', async () => {
    const ownerA = ctx('ownerA').firestore();
    await assertFails(ownerA.doc('password_reset_requests/reqGlobal').get());
    await assertSucceeds(ownerA.doc('password_reset_requests/reqA').get());
    await assertSucceeds(
      ctx('root').firestore().doc('password_reset_requests/reqGlobal').get());
    // Tudo-ou-nada: havendo pedido global, lista sem filtro nega p/ owner.
    await assertFails(ownerA.collection('password_reset_requests').get());
    await assertSucceeds(ownerA
      .collection('password_reset_requests')
      .where('clinicId', '==', A)
      .get());
  });

  it('P1: public_clinics só dono da clínica ou Master', async () => {
    // A projeção usa o MESMO id da clínica (ownsClinic prova a posse).
    await assertSucceeds(
      ctx('ownerA').firestore().doc(`public_clinics/${A}`).set({
        name: 'A', whatsappNumber: '119', updatedAt: new Date(),
      }));
    await assertFails(
      ctx('ownerB').firestore().doc(`public_clinics/${A}`).set({
        name: 'X', whatsappNumber: '119', updatedAt: new Date(),
      }));
  });

  it('P2: lead gigante nega (teto anti-spam)', async () => {
    const anon = ctx(null).firestore();
    await assertFails(
      anon.collection('public_clinics/pub1/leads').add({
        answers: ['x'.repeat(1500), 'y'.repeat(1000)],
        score: 10, createdAt: new Date(),
        origin: 'web_form', status: 'new_lead',
      }));
  });

  it('P0 anamnese: sem get público; escrita só com prova do token', async () => {
    const anon = ctx(null).firestore();
    await assertFails(anon.doc('anamnesis/p1').get());
    // Sem prova e com prova errada: nega.
    await assertFails(anon.doc('anamnesis/p1').update({ smoker: true }));
    await assertFails(anon.doc('anamnesis/p1').update({
      smoker: true, proofToken: 'errada',
    }));
    // Prova certa + allowlist: permite (link válido do WhatsApp).
    await assertSucceeds(anon.doc('anamnesis/p1').update({
      patientId: 'p1', smoker: true, proofToken: 'ana456',
    }));
    await assertFails(anon.doc('anamnesis/p2').set({
      patientId: 'p1', smoker: true, proofToken: 'ana456',
    }));
    // Campo fora da allowlist mesmo com prova: nega.
    await assertFails(anon.doc('anamnesis/p1').update({
      patientId: 'p1', diagnosis: 'x', proofToken: 'ana456',
    }));
    // Staff de outra clínica sem prova: nega; da mesma clínica: permite.
    await assertFails(
      ctx('staffB').firestore().doc('anamnesis/p1').update({ smoker: false }));
    await assertSucceeds(
      ctx('staffA').firestore().doc('anamnesis/p1').update({ smoker: false }));
  });
});
