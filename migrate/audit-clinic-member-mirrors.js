// Auditoria READ-ONLY dos espelhos de membros por clínica.
// Uso: node migrate/audit-clinic-member-mirrors.js
// Requer migrate/new-key.json local (service account ignorada no git).
// Lê clinics, users, members e members_private; não grava nem corrige dados.
// A saída nunca imprime valores pessoais, apenas caminhos/campos com problemas.

const admin = require('firebase-admin');
const serviceAccount = require('./new-key.json');

const PROJECT_ID = 'nexosaude';
const PUBLIC_ALLOWED_FIELDS = new Set([
  'uid', 'name', 'role', 'status', 'createdAt', 'updatedAt',
]);
const PUBLIC_REQUIRED_FIELDS = [...PUBLIC_ALLOWED_FIELDS];
const PRIVATE_ALLOWED_FIELDS = new Set([
  'uid', 'name', 'email', 'role', 'status', 'phone', 'whatsapp', 'cpf',
  'menuAccess', 'allowedClinics', 'createdAt', 'updatedAt',
]);
const PRIVATE_REQUIRED_FIELDS = [...PRIVATE_ALLOWED_FIELDS];

if (!serviceAccount || serviceAccount.project_id !== PROJECT_ID) {
  throw new Error('Credencial incorreta: esperado project_id ' + PROJECT_ID + '.');
}
if (process.argv.includes('--apply') ||
    process.argv.includes('--write') ||
    process.argv.includes('--fix')) {
  throw new Error('Este script é somente leitura e não aceita flags de escrita (--apply/--write/--fix).');
}
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log('Uso: node migrate/audit-clinic-member-mirrors.js');
  console.log('Auditoria READ-ONLY; não altera o Firestore.');
  process.exit(0);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const issues = [];
const counts = {
  users: 0,
  clinics: 0,
  expectedPublic: 0,
  expectedPrivate: 0,
  actualPublic: 0,
  actualPrivate: 0,
  checkedPublic: 0,
  checkedPrivate: 0,
};

function issue(code, path, detail) {
  issues.push({ code, path, detail });
}

function asString(value) {
  return String(value);
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function isTimestamp(value) {
  return value != null &&
    typeof value.toDate === 'function' &&
    Number.isFinite(value.toDate().getTime());
}

function isPlainMap(value) {
  return value != null && typeof value === 'object' &&
    !Array.isArray(value) && !isTimestamp(value);
}

function canonical(value) {
  if (value === undefined || value === null) return null;
  if (isTimestamp(value)) return { __firestoreTimestampMs: value.toDate().getTime() };
  if (Array.isArray(value)) return value.map(canonical);
  if (isPlainMap(value)) {
    const result = {};
    for (const key of Object.keys(value).sort()) result[key] = canonical(value[key]);
    return result;
  }
  return value;
}

function sameValue(a, b) {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
}

function expectedString(user, field) {
  return user[field] || '';
}

function expectedMenuAccess(user) {
  return isPlainMap(user.menuAccess) ? user.menuAccess : {};
}

function expectedAllowedClinics(user, clinicId, clinicsById) {
  const allowed = [...new Set((Array.isArray(user.allowedClinics)
    ? user.allowedClinics : []).map(asString))];
  const clinic = clinicsById.get(clinicId);
  const ownerId = String(clinic?.ownerId || '');
  if (!ownerId) return [];
  return allowed.filter((otherId) =>
    clinicsById.has(otherId) &&
    String(clinicsById.get(otherId).ownerId || '') === ownerId
  ).sort();
}

function checkAllowedFields(data, allowed, required, path) {
  for (const key of Object.keys(data)) {
    if (!allowed.has(key)) {
      issue('CAMPO_NAO_PERMITIDO', path, 'campo extra: ' + key);
    }
  }
  for (const key of required) {
    if (!hasOwn(data, key)) {
      issue('CAMPO_AUSENTE', path, 'campo obrigatório ausente: ' + key);
    }
  }
}

function checkStringFields(data, fields, path) {
  for (const field of fields) {
    if (hasOwn(data, field) && typeof data[field] !== 'string') {
      issue('TIPO_INVALIDO', path, 'campo deve ser string: ' + field);
    }
  }
}

function checkUpdatedAt(data, path) {
  if (!isTimestamp(data.updatedAt)) {
    issue('TIMESTAMP_INVALIDO', path, 'updatedAt ausente ou não é Timestamp do Firestore');
  }
}

function compareField(actual, expected, field, path) {
  if (!sameValue(actual, expected)) {
    issue('DIVERGENCIA', path, 'campo não corresponde à origem: ' + field);
  }
}

function checkPublicMirror(doc, user, clinicId, clinicsById) {
  const path = 'clinics/' + clinicId + '/members/' + doc.id;
  const data = doc.data() || {};
  counts.checkedPublic++;

  checkAllowedFields(data, PUBLIC_ALLOWED_FIELDS, PUBLIC_REQUIRED_FIELDS, path);
  checkStringFields(data, ['uid', 'name', 'role', 'status'], path);
  checkUpdatedAt(data, path);

  if (data.uid !== doc.id) {
    issue('UID_DIVERGENTE', path, 'uid deve corresponder ao ID do documento');
  }

  compareField(data.uid, doc.id, 'uid', path);
  compareField(data.name, expectedString(user, 'name'), 'name', path);
  compareField(data.role, expectedString(user, 'role'), 'role', path);
  compareField(data.status, expectedString(user, 'status'), 'status', path);

  if (user.createdAt) {
    compareField(data.createdAt, user.createdAt, 'createdAt', path);
  } else if (!isTimestamp(data.createdAt)) {
    issue('TIMESTAMP_INVALIDO', path, 'createdAt deveria ser Timestamp porque users/{uid}.createdAt está ausente');
  }
}

function checkPrivateMirror(doc, user, clinicId, clinicsById) {
  const path = 'clinics/' + clinicId + '/members_private/' + doc.id;
  const data = doc.data() || {};
  counts.checkedPrivate++;

  checkAllowedFields(data, PRIVATE_ALLOWED_FIELDS, PRIVATE_REQUIRED_FIELDS, path);
  checkStringFields(data, [
    'uid', 'name', 'email', 'role', 'status', 'phone', 'whatsapp', 'cpf',
  ], path);
  checkUpdatedAt(data, path);

  if (data.uid !== doc.id) {
    issue('UID_DIVERGENTE', path, 'uid deve corresponder ao ID do documento');
  }

  compareField(data.uid, doc.id, 'uid', path);
  compareField(data.name, expectedString(user, 'name'), 'name', path);
  compareField(data.email, expectedString(user, 'email'), 'email', path);
  compareField(data.role, expectedString(user, 'role'), 'role', path);
  compareField(data.status, expectedString(user, 'status'), 'status', path);
  compareField(data.phone, expectedString(user, 'phone'), 'phone', path);
  compareField(data.whatsapp, expectedString(user, 'whatsapp'), 'whatsapp', path);
  compareField(data.cpf, expectedString(user, 'cpf'), 'cpf', path);
  compareField(data.menuAccess, expectedMenuAccess(user), 'menuAccess', path);

  if (!Array.isArray(data.allowedClinics) ||
      data.allowedClinics.some((value) => typeof value !== 'string')) {
    issue('TIPO_INVALIDO', path, 'allowedClinics deve ser uma lista de strings');
  } else {
    compareField(
      [...data.allowedClinics].sort(),
      expectedAllowedClinics(user, clinicId, clinicsById),
      'allowedClinics',
      path,
    );
  }

  if (user.createdAt) {
    compareField(data.createdAt, user.createdAt, 'createdAt', path);
  } else if (!isTimestamp(data.createdAt)) {
    issue('TIMESTAMP_INVALIDO', path, 'createdAt deveria ser Timestamp porque users/{uid}.createdAt está ausente');
  }
}

(async () => {
  const [usersSnap, clinicsSnap] = await Promise.all([
    db.collection('users').get(),
    db.collection('clinics').get(),
  ]);
  counts.users = usersSnap.size;
  counts.clinics = clinicsSnap.size;

  const usersById = new Map(usersSnap.docs.map((doc) => [doc.id, doc.data() || {}]));
  const clinicsById = new Map(clinicsSnap.docs.map((doc) => [doc.id, doc.data() || {}]));
  const expectedByClinic = new Map();

  // Calcula quais pares clínica/usuário devem existir, com as mesmas condições
  // do backfill: usuário vinculado, clínica existente e ownerId definido.
  for (const [uid, user] of usersById) {
    const allowed = [...new Set((Array.isArray(user.allowedClinics)
      ? user.allowedClinics : []).map(asString))];
    for (const clinicId of allowed) {
      if (!clinicsById.has(clinicId)) continue;
      const clinic = clinicsById.get(clinicId);
      if (!String(clinic.ownerId || '')) continue;
      if (!expectedByClinic.has(clinicId)) expectedByClinic.set(clinicId, new Set());
      expectedByClinic.get(clinicId).add(uid);
    }
  }

  const seenPublic = new Map();
  const seenPrivate = new Map();

  for (const clinicDoc of clinicsSnap.docs) {
    const clinicId = clinicDoc.id;
    const clinicRef = db.collection('clinics').doc(clinicId);
    const [publicSnap, privateSnap] = await Promise.all([
      clinicRef.collection('members').get(),
      clinicRef.collection('members_private').get(),
    ]);
    counts.actualPublic += publicSnap.size;
    counts.actualPrivate += privateSnap.size;

    const publicIds = new Set(publicSnap.docs.map((doc) => doc.id));
    const privateIds = new Set(privateSnap.docs.map((doc) => doc.id));
    seenPublic.set(clinicId, publicIds);
    seenPrivate.set(clinicId, privateIds);

    const expectedIds = expectedByClinic.get(clinicId) || new Set();
    for (const uid of expectedIds) {
      counts.expectedPublic++;
      counts.expectedPrivate++;
      if (!publicIds.has(uid)) {
        issue('ESPELHO_PUBLICO_AUSENTE', 'clinics/' + clinicId + '/members/' + uid,
          'há vínculo esperado em users/{uid}.allowedClinics, mas falta o espelho público');
      }
      if (!privateIds.has(uid)) {
        issue('ESPELHO_PRIVADO_AUSENTE', 'clinics/' + clinicId + '/members_private/' + uid,
          'há vínculo esperado em users/{uid}.allowedClinics, mas falta o espelho privado');
      }
    }

    for (const doc of publicSnap.docs) {
      const path = 'clinics/' + clinicId + '/members/' + doc.id;
      const user = usersById.get(doc.id);
      if (!user) {
        issue('MEMBRO_SEM_USUARIO', path, 'não existe users/' + doc.id);
        continue;
      }
      if (!expectedIds.has(doc.id)) {
        issue('ESPELHO_PUBLICO_INESPERADO', path,
          'o vínculo não é esperado pelo allowedClinics/ownerId atual');
        continue;
      }
      checkPublicMirror(doc, user, clinicId, clinicsById);
    }

    for (const doc of privateSnap.docs) {
      const path = 'clinics/' + clinicId + '/members_private/' + doc.id;
      const user = usersById.get(doc.id);
      if (!user) {
        issue('MEMBRO_SEM_USUARIO', path, 'não existe users/' + doc.id);
        continue;
      }
      if (!expectedIds.has(doc.id)) {
        issue('ESPELHO_PRIVADO_INESPERADO', path,
          'o vínculo não é esperado pelo allowedClinics/ownerId atual');
        continue;
      }
      checkPrivateMirror(doc, user, clinicId, clinicsById);
    }
  }

  // Também detecta espelhos deixados em subcoleções de clínicas sem ownerId
  // ou sem vínculo correspondente, inclusive se não entram no conjunto esperado.
  console.log('Projeto: ' + PROJECT_ID);
  console.log('Modo: READ-ONLY (nenhuma escrita)');
  console.log('Usuários analisados: ' + counts.users);
  console.log('Clínicas analisadas: ' + counts.clinics);
  console.log('Espelhos públicos esperados: ' + counts.expectedPublic);
  console.log('Espelhos privados esperados: ' + counts.expectedPrivate);
  console.log('Espelhos públicos encontrados: ' + counts.actualPublic);
  console.log('Espelhos privados encontrados: ' + counts.actualPrivate);
  console.log('Espelhos públicos verificados em detalhe: ' + counts.checkedPublic);
  console.log('Espelhos privados verificados em detalhe: ' + counts.checkedPrivate);
  console.log('Divergências: ' + issues.length);
  console.log('');

  if (issues.length) {
    console.log('RESULTADO: FALHAS ENCONTRADAS');
    const MAX_ISSUES = 250;
    for (const item of issues.slice(0, MAX_ISSUES)) {
      console.log('[' + item.code + '] ' + item.path + ' — ' + item.detail);
    }
    if (issues.length > MAX_ISSUES) {
      console.log('... mais ' + (issues.length - MAX_ISSUES) + ' divergências omitidas; consulte logs ou execute novamente após corrigir.');
    }
    console.log('');
    console.log('Nenhum dado foi alterado. Corrija as divergências e execute novamente.');
    process.exitCode = 1;
  } else {
    console.log('RESULTADO: OK');
    console.log('Todos os espelhos encontrados respeitam os esquemas e correspondem a users/{uid}.');
    console.log('Nenhum dado foi alterado.');
  }
})().catch((error) => {
  console.error('FALHOU:', error.message);
  process.exitCode = 1;
}).finally(async () => {
  await admin.app().delete().catch(() => {});
});
