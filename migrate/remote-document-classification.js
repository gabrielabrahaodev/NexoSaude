'use strict';

function classifyRemoteDocument(metadata) {
  const data = metadata && typeof metadata === 'object' ? metadata : {};
  const url = String(data.url || '').trim();
  const lowerUrl = url.toLowerCase();
  const resourceType = String(data.resourceType || '').trim().toLowerCase();
  const publicId = String(data.publicId || '').trim();

  if (resourceType === 'r2' || lowerUrl.startsWith('r2://')) {
    return { storage: 'r2', resourceType: 'r2' };
  }

  let host = '';
  try {
    host = new URL(url).hostname.toLowerCase();
  } catch (_) {}
  if (host === 'cloudinary.com' || host.endsWith('.cloudinary.com')) {
    return {
      storage: 'cloudinary',
      resourceType: ['image', 'video', 'raw'].includes(resourceType)
        ? resourceType : null,
    };
  }

  // Um publicId sem origem inequívoca deve ser preservado para revisão.
  if (publicId) {
    return { storage: 'manual-review', resourceType: resourceType || null };
  }
  return null;
}

/**
 * Fail-closed validation for destructive Cloudinary cleanup.
 * Requires a real HTTPS Cloudinary host, the expected account in the URL,
 * an explicit supported resourceType matching the URL path, and a publicId.
 */
function validateCloudinaryDocumentMetadata(metadata, expectedCloudName) {
  const data = metadata && typeof metadata === 'object' ? metadata : {};
  const url = String(data.url || '').trim();
  const publicId = String(data.publicId || '').trim();
  const resourceType = String(data.resourceType || '').trim().toLowerCase();

  if (!url) throw new Error('Metadata não contém URL remota.');
  if (!publicId) throw new Error('Metadata não contém publicId.');
  if (!['image', 'video', 'raw'].includes(resourceType)) {
    throw new Error('resourceType ausente ou inválido; revisão manual obrigatória.');
  }

  let parsed;
  try {
    parsed = new URL(url);
  } catch (_) {
    throw new Error('URL Cloudinary inválida; revisão manual obrigatória.');
  }

  const host = parsed.hostname.toLowerCase();
  if (parsed.protocol !== 'https:' ||
      !(host === 'cloudinary.com' || host.endsWith('.cloudinary.com'))) {
    throw new Error('A URL não pertence a um host HTTPS Cloudinary válido.');
  }

  const segments = parsed.pathname.split('/').filter(Boolean);
  if (!segments[0] || (expectedCloudName && segments[0] !== expectedCloudName)) {
    throw new Error('A URL não corresponde à conta Cloudinary esperada.');
  }
  if (segments[1] !== resourceType ||
      !['upload', 'private', 'authenticated'].includes(segments[2] || '')) {
    throw new Error('resourceType ou tipo de entrega não confere com a URL.');
  }

  return { url: parsed.toString(), publicId, resourceType, cloudName: segments[0] };
}

module.exports = { classifyRemoteDocument, validateCloudinaryDocumentMetadata };
