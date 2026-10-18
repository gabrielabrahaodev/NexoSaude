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

module.exports = { classifyRemoteDocument };
