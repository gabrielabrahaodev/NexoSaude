// Gera uma senha temporaria para um usuario — SEM e-mail (e-mails genericos).
// Atende tambem os pedidos pendentes em `password_reset_requests` (a tela
// Funcionarios mostra a temporaria + botao copiar).
//
// Uso: node reset-password.js <email> [novaSenha]
//   - sem [novaSenha]: gera `Nexo####` aleatoria.
//   - usa new-key.json (service account do projeto nexosaude).
const admin = require('firebase-admin');
const sa = require('./new-key.json');

admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'nexosaude',
});
const db = admin.firestore();

(async () => {
  const email = (process.argv[2] || '').trim().toLowerCase();
  if (!email.includes('@')) {
    console.error('Uso: node reset-password.js <email> [novaSenha]');
    process.exit(1);
  }
  const temp =
    process.argv[3] || 'Nexo' + Math.floor(1000 + Math.random() * 9000);

  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password: temp });

  const pend = await db
    .collection('password_reset_requests')
    .where('email', '==', email)
    .get();
  const batch = db.batch();
  let n = 0;
  pend.forEach((d) => {
    if (d.data().status === 'pending') {
      batch.update(d.ref, {
        status: 'done',
        tempPassword: temp,
        handledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      n++;
    }
  });
  await batch.commit();

  console.log('OK! ' + email + ' -> senha temporaria: ' + temp);
  console.log('Pedidos atendidos: ' + n);
  process.exit(0);
})().catch((e) => {
  console.error('FALHOU: ' + e.message);
  process.exit(1);
});
