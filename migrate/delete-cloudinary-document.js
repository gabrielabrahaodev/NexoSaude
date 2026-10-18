// Exclusão remota administrativa de UM documento Cloudinary legado.
// READ-ONLY por padrão; o arquivo no Cloudinary e a metadata Firestore só
// são apagados com --apply e confirmação do caminho exato.
// Uso:
//   node migrate/delete-cloudinary-document.js --clinic CID --patient PID --document DID
//   node migrate/delete-cloudinary-document.js --clinic CID --patient PID --document DID --apply --confirm-delete CID/PID/DID
// Credenciais requeridas no ambiente: CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY,
// CLOUDINARY_API_SECRET. Nunca salvar o API secret no código ou no Firestore.
const admin = require('firebase-admin');
const crypto = require('node:crypto');
const serviceAccount = require('./new-key.json');
const { validateCloudinaryDocumentMetadata } = require('./remote-document-classification');

const PROJECT_ID = 'nexosaude';
const args = process.argv.slice(2);
function argValue(name) {
  const index = args.indexOf(name);
  if (index >= 0 && args[index + 1] && !args[index + 1].startsWith('--')) return args[index + 1];
  const prefix = name + '=';
  const found = args.find((value) => value.startsWith(prefix));
  return found ? found.slice(prefix.length) : null;
}
const clinicId = argValue('--clinic');
const patientId = argValue('--patient');
const documentId = argValue('--document');
const APPLY = args.includes('--apply');
const confirmation = argValue('--confirm-delete');
const expectedConfirmation = [clinicId, patientId, documentId].join('/');

if (!serviceAccount || serviceAccount.project_id !== PROJECT_ID) {
  throw new Error('Credencial incorreta: esperado project_id ' + PROJECT_ID + '.');
}
if (!clinicId || !patientId || !documentId ||
    [clinicId, patientId, documentId].some((value) => value.includes('/'))) {
  throw new Error('Informe --clinic CID --patient PID --document DID, sem barras nos IDs.');
}
if (APPLY && confirmation !== expectedConfirmation) {
  throw new Error('Proteção destrutiva: --confirm-delete deve ser exatamente ' + expectedConfirmation + '.');
}
const CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME || '';
const API_KEY = process.env.CLOUDINARY_API_KEY || '';
const API_SECRET = process.env.CLOUDINARY_API_SECRET || '';
if (APPLY && (!CLOUD_NAME || !API_KEY || !API_SECRET)) {
  throw new Error('APPLY exige CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY e CLOUDINARY_API_SECRET no ambiente.');
}
if (CLOUD_NAME && CLOUD_NAME !== 'dbbh601ay') {
  throw new Error('Cloudinary inesperado: confira CLOUDINARY_CLOUD_NAME antes de continuar.');
}
if (args.includes('--help') || args.includes('-h')) {
  console.log('Uso: node migrate/delete-cloudinary-document.js --clinic CID --patient PID --document DID [--apply --confirm-delete CID/PID/DID]');
  console.log('Sem --apply é READ-ONLY; nenhuma escrita será realizada.');
  process.exit(0);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

function cloudinarySignature(params, secret) {
  const normalized = Object.keys(params).sort()
    .map((key) => key + '=' + params[key])
    .join('&') + secret;
  return crypto.createHash('sha1').update(normalized).digest('hex');
}

(async () => {
  const patientRef = db.collection('patients').doc(patientId);
  const patientSnap = await patientRef.get();
  if (!patientSnap.exists) throw new Error('Paciente não encontrado.');
  if (String((patientSnap.data() || {}).clinicId || '') !== clinicId) {
    throw new Error('O paciente não pertence à clínica informada; nada foi alterado.');
  }

  const docRef = patientRef.collection('docs').doc(documentId);
  const docSnap = await docRef.get();
  if (!docSnap.exists) throw new Error('Documento de metadata não encontrado.');
  const metadata = docSnap.data() || {};
  // Não confie em substring de URL nem presuma "image" quando o tipo falta.
  // Só permita limpeza quando host, conta, tipo de recurso e publicId conferirem.
  const { publicId, resourceType } = validateCloudinaryDocumentMetadata(
    metadata,
    'dbbh601ay',
  );

  console.log('Projeto: ' + PROJECT_ID);
  console.log('Clínica: ' + clinicId);
  console.log('Paciente: ' + patientId);
  console.log('Documento: ' + documentId);
  console.log('Tipo remoto: ' + resourceType);
  console.log('publicId presente: sim (valor omitido)');
  console.log('Modo: ' + (APPLY ? 'APPLY DESTRUTIVO' : 'DRY-RUN (nenhuma escrita)'));

  if (!APPLY) {
    console.log('DRY-RUN: nem Cloudinary nem Firestore foram alterados.');
    console.log('Revise o caminho e depois use --apply --confirm-delete ' + expectedConfirmation);
    return;
  }

  const timestamp = String(Math.floor(Date.now() / 1000));
  const signedParams = {
    invalidate: 'true',
    public_id: publicId,
    timestamp,
  };
  const signature = cloudinarySignature(signedParams, API_SECRET);
  const body = new URLSearchParams({
    ...signedParams,
    api_key: API_KEY,
    signature,
  });
  const endpoint = 'https://api.cloudinary.com/v1_1/' +
    encodeURIComponent(CLOUD_NAME) + '/' + resourceType + '/destroy';
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const responseData = await response.json().catch(() => ({}));
  if (!response.ok ||
      !['ok', 'not found'].includes(String(responseData.result || '').toLowerCase())) {
    throw new Error('Cloudinary não confirmou a exclusão (' + response.status +
      ', result=' + String(responseData.result || 'desconhecido') +
      '). Metadata Firestore preservada.');
  }

  await docRef.delete();
  console.log('Arquivo remoto confirmado como removido/ausente; metadata Firestore removida.');
})().catch((error) => {
  console.error('FALHOU:', error.message);
  process.exitCode = 1;
}).finally(async () => {
  await admin.app().delete().catch(() => {});
});
