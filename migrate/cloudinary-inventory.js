#!/usr/bin/env node
'use strict';

// Inventário read-only de metadados de arquivos legados. Nunca escreve no
// Firestore nem chama APIs de armazenamento. --apply é rejeitado.
const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');
const { inventoryCloudinaryDocument } = require('./cloudinary-inventory-core');
const PROJECT_ID = 'nexosaude';
const args = process.argv.slice(2);

function argValue(name) {
  const index = args.indexOf(name);
  if (index >= 0 && args[index + 1] && !args[index + 1].startsWith('--')) return args[index + 1];
  const prefix = name + '=';
  const found = args.find((arg) => arg.startsWith(prefix));
  return found ? found.slice(prefix.length) : null;
}
if (args.includes('--apply')) throw new Error('Este inventário é somente leitura; --apply não é permitido.');
if (args.includes('--help') || args.includes('-h')) {
  console.log('Uso: node migrate/cloudinary-inventory.js [--clinic CLINIC_ID] [--out CAMINHO_JSON]');
  console.log('Sempre READ-ONLY; não sobrescreve arquivo de relatório existente.');
  process.exit(0);
}
const clinicId = argValue('--clinic');
const outputPath = argValue('--out');
if (clinicId && (clinicId.includes('/') || clinicId.length > 150)) throw new Error('clinicId inválido.');
const serviceAccount = require('./new-key.json');
if (!serviceAccount || serviceAccount.project_id !== PROJECT_ID) {
  throw new Error('Credencial incorreta: esperado project_id ' + PROJECT_ID + '.');
}
admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId: PROJECT_ID });
const db = admin.firestore();

async function runLimited(items, limit, operation) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const index = next++;
      if (index >= items.length) return;
      await operation(items[index]);
    }
  });
  await Promise.all(workers);
}
async function readPatientPage(lastDocument) {
  let query = db.collection('patients');
  if (clinicId) query = query.where('clinicId', '==', clinicId);
  query = query.orderBy(admin.firestore.FieldPath.documentId()).limit(200);
  if (lastDocument) query = query.startAfter(lastDocument);
  return query.get();
}
(async () => {
  const records = [];
  let scannedPatients = 0;
  let scannedDocuments = 0;
  let lastDocument = null;
  let page;
  do {
    page = await readPatientPage(lastDocument);
    scannedPatients += page.size;
    await runLimited(page.docs, 8, async (patientDoc) => {
      const patient = patientDoc.data() || {};
      const actualClinicId = String(patient.clinicId || '');
      const docs = await patientDoc.ref.collection('docs').get();
      scannedDocuments += docs.size;
      for (const document of docs.docs) {
        const record = inventoryCloudinaryDocument({
          clinicId: actualClinicId,
          patientId: patientDoc.id,
          documentId: document.id,
          metadata: document.data(),
        });
        if (record) records.push(record);
      }
    });
    lastDocument = page.docs.length ? page.docs[page.docs.length - 1] : null;
  } while (page.size === 200);
  records.sort((a, b) =>
    a.clinicId.localeCompare(b.clinicId) ||
    a.patientId.localeCompare(b.patientId) ||
    a.documentId.localeCompare(b.documentId));
  const report = {
    projectId: PROJECT_ID,
    generatedAt: new Date().toISOString(),
    scope: clinicId ? { clinicId: clinicId } : { allClinics: true },
    readOnly: true,
    summary: {
      patientsScanned: scannedPatients,
      documentsScanned: scannedDocuments,
      legacyCandidates: records.length,
      readyForPerFileCleanup: records.filter((record) => record.cleanupStatus === 'ready-for-script').length,
      manualReview: records.filter((record) => record.cleanupStatus === 'manual-review').length,
    },
    records: records,
  };
  const content = JSON.stringify(report, null, 2) + '\n';
  if (outputPath) {
    const resolved = path.resolve(outputPath);
    fs.writeFileSync(resolved, content, { encoding: 'utf8', flag: 'wx' });
    console.log('Relatório gravado em: ' + resolved);
    console.log(JSON.stringify(report.summary, null, 2));
  } else {
    process.stdout.write(content);
  }
})().catch((error) => {
  console.error('FALHOU:', error.message);
  process.exitCode = 1;
}).finally(async () => { await admin.app().delete().catch(() => {}); });
