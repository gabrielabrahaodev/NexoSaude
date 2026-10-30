// Auditoria READ-ONLY das datas de trial. Não há modo --apply e nenhuma escrita.
// Uso: node migrate/audit-clinic-trials.js
// Requer migrate/new-key.json local, nunca versionada.
const admin = require('firebase-admin');
const serviceAccount = require('./new-key.json');
const PROJECT_ID = 'nexosaude';

if (serviceAccount.project_id !== PROJECT_ID) {
  throw new Error('Credencial incorreta: esperado project_id ' + PROJECT_ID + '.');
}
if (process.argv.includes('--apply')) {
  throw new Error('Este script é somente leitura; não aceita --apply.');
}
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

(async () => {
  const snapshot = await db.collection('clinics').get();
  const now = new Date();
  let missing = 0;
  let invalid = 0;
  let expired = 0;
  let blocked = 0;
  let activeFuture = 0;

  console.log('Projeto: ' + PROJECT_ID);
  console.log('Modo: READ-ONLY (nenhuma escrita)');
  console.log('Clínicas encontradas: ' + snapshot.size);
  console.log('');
  console.log('clinicId | trialEndsAt | bloqueada | diagnóstico');

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const raw = data.trialEndsAt;
    const blockedByAdmin = data.blockedByAdmin === true;
    let expiresText = 'AUSENTE';
    const diagnosis = [];

    if (raw == null) {
      missing++;
      diagnosis.push('SEM trialEndsAt — as Rules atuais tratam como ativa');
    } else if (typeof raw.toDate !== 'function' || Number.isNaN(raw.toDate().getTime())) {
      invalid++;
      expiresText = 'INVÁLIDO';
      diagnosis.push('trialEndsAt não é timestamp válido');
    } else {
      const expires = raw.toDate();
      expiresText = expires.toISOString();
      if (expires <= now) {
        expired++;
        diagnosis.push('trial vencido');
      } else {
        activeFuture++;
        diagnosis.push('trial futuro');
      }
    }
    if (blockedByAdmin) {
      blocked++;
      diagnosis.push('bloqueada pelo Master');
    }
    if (diagnosis.length === 0) diagnosis.push('revisar manualmente');
    console.log(doc.id + ' | ' + expiresText + ' | ' +
      (blockedByAdmin ? 'sim' : 'não') + ' | ' + diagnosis.join('; '));
  }

  console.log('');
  console.log('Resumo:');
  console.log('Sem trialEndsAt: ' + missing);
  console.log('trialEndsAt inválido: ' + invalid);
  console.log('Trial vencido: ' + expired);
  console.log('Trial futuro: ' + activeFuture);
  console.log('Bloqueadas: ' + blocked);
  console.log('Este relatório não escreve no Firestore nem altera as Rules.');
  console.log('Não publique Rules fail-closed antes de revisar e regularizar casos legados.');
})().catch((error) => {
  console.error('FALHOU:', error.message);
  process.exit(1);
});
