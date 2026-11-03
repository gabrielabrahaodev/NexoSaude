const test = require('node:test');
const assert = require('node:assert/strict');
const { inventoryCloudinaryDocument } = require('../migrate/cloudinary-inventory-core.js');
const { classifyRemoteDocument, validateCloudinaryDocumentMetadata } = require('../migrate/remote-document-classification.js');

test('inventaria Cloudinary sem expor URL nem publicId', () => {
  const record = inventoryCloudinaryDocument({
    clinicId: 'clinicA', patientId: 'patientA', documentId: 'docA',
    metadata: {
      url: 'https://res.cloudinary.com/dbbh601ay/image/upload/v123/private.jpg',
      publicId: 'patients/patientA/private', resourceType: 'image',
      sizeBytes: 1234, extension: 'jpg', uploadedAt: '2026-10-01T12:00:00.000Z',
    },
  });
  assert.ok(record);
  assert.equal(record.source, 'cloudinary-url');
  assert.equal(record.cleanupStatus, 'ready-for-script');
  assert.equal(record.urlHost, 'res.cloudinary.com');
  assert.equal(record.hasPublicId, true);
  assert.equal(record.sizeBytes, 1234);
  assert.equal(Object.hasOwn(record, 'url'), false);
  assert.equal(Object.hasOwn(record, 'publicId'), false);
});

test('ignora R2 mesmo que metadata tenha publicId', () => {
  assert.equal(inventoryCloudinaryDocument({
    clinicId: 'clinicA', patientId: 'patientA', documentId: 'docR2',
    metadata: { url: 'r2://clinicA/patientA/object.pdf', publicId: 'r2-object', resourceType: 'r2' },
  }), null);
});

test('marca Cloudinary sem publicId para revisão manual', () => {
  const record = inventoryCloudinaryDocument({
    clinicId: 'clinicA', patientId: 'patientA', documentId: 'legacy',
    metadata: { url: 'https://res.cloudinary.com/dbbh601ay/image/upload/old.jpg', resourceType: 'image' },
  });
  assert.equal(record.cleanupStatus, 'manual-review');
});

test('ignora documento sem URL remota nem publicId', () => {
  assert.equal(inventoryCloudinaryDocument({
    clinicId: 'clinicA', patientId: 'patientA', documentId: 'local',
    metadata: { title: 'Receita', sizeBytes: 15 },
  }), null);
});

test('marca publicId com URL que não é Cloudinary para revisão', () => {
  const record = inventoryCloudinaryDocument({
    clinicId: 'clinicA', patientId: 'patientA', documentId: 'uncertain',
    metadata: { url: 'https://example.invalid/object', publicId: 'legacy-id' },
  });
  assert.equal(record.source, 'publicId-present-without-cloudinary-url');
  assert.equal(record.cleanupStatus, 'manual-review');
});

test('classifica R2 como remoto privado e nunca direciona para o destroy do Cloudinary', () => {
  assert.deepEqual(classifyRemoteDocument({
    url: 'r2://clinicA/patientA/documentA.pdf',
    path: 'clinicA/patientA/documentA.pdf',
    publicId: 'clinicA/patientA/documentA.pdf',
    resourceType: 'r2',
  }), { storage: 'r2', resourceType: 'r2' });
});

test('classifica Cloudinary conhecido para limpeza individual autenticada', () => {
  assert.deepEqual(classifyRemoteDocument({
    url: 'https://res.cloudinary.com/example/raw/upload/patient.pdf',
    publicId: 'patients/patientA/documentA',
    resourceType: 'raw',
  }), { storage: 'cloudinary', resourceType: 'raw' });
});

test('preserva registros com publicId sem provedor inequívoco para revisão manual', () => {
  assert.deepEqual(classifyRemoteDocument({
    url: 'https://example.invalid/file',
    publicId: 'unknown-object',
    resourceType: 'image',
  }), { storage: 'manual-review', resourceType: 'image' });
});

test('ignora metadados locais sem identificador de armazenamento remoto', () => {
  assert.equal(classifyRemoteDocument({ url: '', title: 'Receita local' }), null);
});


test('aceita limpeza Cloudinary somente para URL HTTPS da conta e tipo explícitos', () => {
  assert.deepEqual(validateCloudinaryDocumentMetadata({
    url: 'https://res.cloudinary.com/dbbh601ay/image/upload/v123/patient.jpg',
    publicId: 'patients/patientA/documentA',
    resourceType: 'image',
  }, 'dbbh601ay'), {
    url: 'https://res.cloudinary.com/dbbh601ay/image/upload/v123/patient.jpg',
    publicId: 'patients/patientA/documentA',
    resourceType: 'image',
    cloudName: 'dbbh601ay',
  });
});

test('recusa host que apenas contém o texto cloudinary.com', () => {
  assert.throws(() => validateCloudinaryDocumentMetadata({
    url: 'https://res.cloudinary.com.attacker.invalid/dbbh601ay/image/upload/patient.jpg',
    publicId: 'patients/patientA/documentA',
    resourceType: 'image',
  }, 'dbbh601ay'), /host HTTPS Cloudinary válido/);
  assert.throws(() => validateCloudinaryDocumentMetadata({
    url: 'https://attacker.invalid/file?next=cloudinary.com',
    publicId: 'patients/patientA/documentA',
    resourceType: 'image',
  }, 'dbbh601ay'), /host HTTPS Cloudinary válido/);
});

test('recusa conta, tipo de recurso e metadados ambíguos antes de limpeza', () => {
  const valid = {
    url: 'https://res.cloudinary.com/dbbh601ay/image/upload/patient.jpg',
    publicId: 'patients/patientA/documentA',
    resourceType: 'image',
  };
  assert.throws(
    () => validateCloudinaryDocumentMetadata(valid, 'another-cloud'),
    /conta Cloudinary esperada/,
  );
  assert.throws(
    () => validateCloudinaryDocumentMetadata({ ...valid, resourceType: 'raw' }, 'dbbh601ay'),
    /resourceType ou tipo de entrega/,
  );
  const { resourceType, ...withoutType } = valid;
  assert.throws(
    () => validateCloudinaryDocumentMetadata(withoutType, 'dbbh601ay'),
    /resourceType ausente ou inválido/,
  );
  const { publicId, ...withoutPublicId } = valid;
  assert.throws(
    () => validateCloudinaryDocumentMetadata(withoutPublicId, 'dbbh601ay'),
    /publicId/,
  );
});
