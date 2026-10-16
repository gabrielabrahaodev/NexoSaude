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

async function seed(admin) {
  const db = admin.firestore();
  await db.doc(`users/ownerA`).set({
    role: 'owner', allowedClinics: [A], status: 'Ativo', email: 'a@x',
  });
  await db.doc(`users/staffA`).set({
    role: 'recepcionista', allowedClinics: [A], status: 'Ativo', email: 's@x',
  });
  await db.doc(`users/staffB`).set({
    role: 'recepcionista', allowedClinics: [B], status: 'Ativo', email: 'b@x',
  });
  await db.doc(`users/ownerB`).set({
    role: 'owner', allowedClinics: [B], status: 'Ativo', email: 'o@x',
  });
  await db.doc(`users/root`).set({
    role: 'superadmin', allowedClinics: [], status: 'Ativo', email: 'r@x',
  });
  await db.doc(`clinics/${A}`).set({ name: 'A', ownerId: 'ownerA' });
  await db.doc(`clinics/${B}`).set({
    name: 'B', ownerId: 'ownerB', blockedByAdmin: true,
  });
  await db.doc(`patients/p1`).set({ clinicId: A, portalToken: 'tok123' });
  await db.doc(`appointments/ap1`).set({
    clinicId: A, patientId: 'p1', status: 'Agendado', portalToken: null,
  });
  await db.doc(`financial/f1`).set({ clinicId: A, amount: 100 });
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

  it('P0-1: staff lista users; anônimo não', async () => {
    await assertSucceeds(ctx('staffA').firestore().collection('users').get());
    await assertFails(ctx(null).firestore().collection('users').get());
  });

  it('P0-2: staff de outra clínica não altera financeiro', async () => {
    const db = ctx('staffB').firestore();
    await assertFails(db.doc('financial/f1').update({ amount: 999 }));
  });

  it('P0-2: anônimo só avisoPagamento; outro campo nega', async () => {
    const db = ctx(null).firestore();
    await assertSucceeds(db.doc('financial/f1').update({ avisoPagamento: true }));
    await assertFails(db.doc('financial/f1').update({ amount: 1 }));
  });

  it('P1-5: anônimo confirma COM token do paciente; sem token nega', async () => {
    const db = ctx(null).firestore();
    await assertSucceeds(db.doc('appointments/ap1').update({
      status: 'Confirmado', portalToken: 'tok123',
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
  });

  it('P1-3: trava enforceable — clínica bloqueada nega operacional', async () => {
    const db = ctx('staffB').firestore();
    await assertFails(db.collection('patients').add({ clinicId: B }));
    const root = ctx('root').firestore();
    await assertSucceeds(root.collection('patients').add({ clinicId: B }));
  });

  it('P1-4: trial com uid próprio passa; de outro nega; anônimo nega', async () => {
    const good = {
      nome: 'N', whatsapp: '11999999999', email: 'n@n.com',
      clinicName: 'C', type: 'dental', uid: 'ownerA',
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

  it('P0-2: anamnese fora da allowlist nega p/ staff sem clínica', async () => {
    const db = ctx('staffB').firestore();
    await assertFails(db.doc('anamnesis/p1').update({ diagnosis: 'x' }));
    await assertSucceeds(ctx(null).firestore().doc('anamnesis/p2').set({
      patientId: 'p2', smoker: false,
    }));
  });
});
