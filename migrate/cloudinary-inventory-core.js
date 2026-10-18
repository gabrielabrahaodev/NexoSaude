'use strict';

function timestampToIso(value) {
  if (!value) return null;
  try {
    const date = value instanceof Date
      ? value
      : typeof value.toDate === 'function'
        ? value.toDate()
        : new Date(value);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  } catch (_) { return null; }
}

/** Redige candidato legado sem incluir URL completa ou publicId no relatório. */
function inventoryCloudinaryDocument(input) {
  const clinicId = input && input.clinicId;
  const patientId = input && input.patientId;
  const documentId = input && input.documentId;
  const data = input && input.metadata && typeof input.metadata === 'object'
    ? input.metadata : {};
  const url = String(data.url || '').trim();
  const publicId = String(data.publicId || '').trim();
  const resourceType = String(data.resourceType || '').trim().toLowerCase();
  if (resourceType === 'r2' || url.toLowerCase().startsWith('r2://')) return null;
  let urlHost = null;
  if (url) {
    try { urlHost = new URL(url).hostname.toLowerCase(); } catch (_) {}
  }
  const isCloudinaryUrl = Boolean(urlHost) &&
    (urlHost === 'cloudinary.com' || urlHost.endsWith('.cloudinary.com'));
  if (!isCloudinaryUrl && !publicId) return null;
  const clinic = String(clinicId || '');
  return {
    clinicId: clinic,
    patientId: String(patientId || ''),
    documentId: String(documentId || ''),
    firestorePath: 'patients/' + String(patientId || '') + '/docs/' + String(documentId || ''),
    source: isCloudinaryUrl ? 'cloudinary-url' : 'publicId-present-without-cloudinary-url',
    urlHost: urlHost || null,
    hasPublicId: Boolean(publicId),
    resourceType: resourceType || null,
    sizeBytes: data.sizeBytes != null && Number.isFinite(Number(data.sizeBytes)) ? Number(data.sizeBytes) : null,
    extension: data.extension ? String(data.extension).slice(0, 20) : null,
    uploadedAt: timestampToIso(data.uploadedAt),
    cleanupStatus: isCloudinaryUrl && publicId && clinic &&
      ['image', 'video', 'raw'].includes(resourceType)
      ? 'ready-for-script' : 'manual-review',
  };
}
module.exports = { inventoryCloudinaryDocument };
