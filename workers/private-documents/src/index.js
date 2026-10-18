import { validateDocumentFile } from "./validation.js";

const TOKEN_KEYS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const MAX_CONTENT_LENGTH = 11 * 1024 * 1024;
const SIGNED_URL_TTL_SECONDS = 300;
const LEGACY_TRIALLESS_TEST_CLINIC_IDS = new Set([
  "MxftREXD5vjKtE7SyJIH",
  "VlFVjTlNX8yqijeHyczt",
]);
const ALLOWED_CONTENT_TYPES = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
]);

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Exportada para teste unitário. Se o binding não existir ou falhar, a API
// falha fechada (503); um limite atingido resulta em 429.
export async function enforceRateLimit(env, bindingName, key, message) {
  const limiter = env?.[bindingName];
  if (!limiter || typeof limiter.limit !== "function") {
    throw new ApiError(503, "Proteção de tráfego indisponível; tente novamente mais tarde.");
  }
  let result;
  try {
    result = await limiter.limit({ key: String(key) });
  } catch (_) {
    throw new ApiError(503, "Proteção de tráfego indisponível; tente novamente mais tarde.");
  }
  if (!result || result.success !== true) {
    throw new ApiError(429, message || "Limite de requisições excedido. Tente novamente em um minuto.");
  }
}

function parseBase64Url(input) {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function decodeJwtSegment(segment) {
  return JSON.parse(new TextDecoder().decode(parseBase64Url(segment)));
}

async function verifyFirebaseIdToken(token, env) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new ApiError(401, "Sessão inválida.");

  let header;
  let claims;
  try {
    header = decodeJwtSegment(parts[0]);
    claims = decodeJwtSegment(parts[1]);
  } catch (_) {
    throw new ApiError(401, "Sessão inválida.");
  }
  if (header.alg !== "RS256" || typeof header.kid !== "string") {
    throw new ApiError(401, "Sessão inválida.");
  }

  const keyResponse = await fetch(TOKEN_KEYS_URL, {
    headers: { Accept: "application/json" },
  });
  if (!keyResponse.ok) throw new ApiError(503, "Não foi possível validar a sessão.");
  const keySet = await keyResponse.json();
  const jwk = (keySet.keys || []).find((candidate) => candidate.kid === header.kid);
  if (!jwk) throw new ApiError(401, "Sessão expirada ou inválida.");

  const publicKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    parseBase64Url(parts[2]),
    new TextEncoder().encode(parts[0] + "." + parts[1]),
  );
  const now = Math.floor(Date.now() / 1000);
  const projectId = env.FIREBASE_PROJECT_ID || "nexosaude";
  if (
    !valid ||
    claims.iss !== "https://securetoken.google.com/" + projectId ||
    claims.aud !== projectId ||
    typeof claims.sub !== "string" ||
    claims.sub.length === 0 ||
    claims.sub.length > 128 ||
    !Number.isFinite(claims.exp) ||
    claims.exp <= now ||
    !Number.isFinite(claims.iat) ||
    claims.iat > now + 60
  ) {
    throw new ApiError(401, "Sessão expirada ou inválida.");
  }
  return { uid: claims.sub };
}

function decodeFirestoreValue(value) {
  if (!value || typeof value !== "object") return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("timestampValue" in value) return new Date(value.timestampValue);
  if ("nullValue" in value) return null;
  if ("arrayValue" in value) {
    return (value.arrayValue.values || []).map(decodeFirestoreValue);
  }
  if ("mapValue" in value) return decodeFirestoreFields(value.mapValue.fields || {});
  return null;
}

function decodeFirestoreFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeFirestoreValue(value)]),
  );
}

function encodeFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeFirestoreValue) } };
  }
  if (typeof value === "object") return { mapValue: { fields: encodeFirestoreFields(value) } };
  return { nullValue: null };
}

function encodeFirestoreFields(fields) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, encodeFirestoreValue(value)]),
  );
}

async function createFirestoreDocument(token, path, fields, env) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  const projectId = env.FIREBASE_PROJECT_ID || "nexosaude";
  const response = await fetch(
    "https://firestore.googleapis.com/v1/projects/" +
      projectId +
      "/databases/(default)/documents/" + encodedPath,
    {
      method: "PATCH",
      headers: {
        Authorization: "Bearer " + token,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ fields: encodeFirestoreFields(fields) }),
    },
  );
  if (!response.ok) {
    if (response.status === 401 || response.status === 403) {
      throw new ApiError(403, "O arquivo foi validado, mas as regras do banco negaram a gravação dos metadados.");
    }
    throw new ApiError(503, "Não foi possível registrar os metadados do arquivo.");
  }
  return response.json();
}

async function readFirestoreDocument(token, path, env) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  const projectId = env.FIREBASE_PROJECT_ID || "nexosaude";
  const response = await fetch(
    "https://firestore.googleapis.com/v1/projects/" +
      projectId +
      "/databases/(default)/documents/" +
      encodedPath,
    { headers: { Authorization: "Bearer " + token, Accept: "application/json" } },
  );
  if (response.status === 404) return null;
  if (!response.ok) {
    if (response.status === 401 || response.status === 403) {
      throw new ApiError(403, "Sem autorização para acessar este arquivo.");
    }
    throw new ApiError(503, "Não foi possível validar as permissões no banco.");
  }
  const document = await response.json();
  return decodeFirestoreFields(document.fields || {});
}

function validDocumentId(value) {
  return typeof value === "string" &&
    value.length > 0 &&
    value.length <= 150 &&
    !value.includes("/") &&
    value !== "." &&
    value !== "..";
}

async function authorizePatient(token, uid, clinicId, patientId, env) {
  if (!validDocumentId(clinicId) || !validDocumentId(patientId)) {
    throw new ApiError(400, "Clínica ou paciente inválido.");
  }
  const user = await readFirestoreDocument(token, "users/" + uid, env);
  if (!user || user.status !== "Ativo") {
    throw new ApiError(403, "A conta não está ativa.");
  }
  const clinic = await readFirestoreDocument(token, "clinics/" + clinicId, env);
  if (!clinic) throw new ApiError(404, "Clínica não encontrada.");

  const role = String(user.role || "").toLowerCase();
  const isSuperAdmin = role === "superadmin";
  const allowedClinics = Array.isArray(user.allowedClinics) ? user.allowedClinics : [];
  if (!isSuperAdmin && !allowedClinics.includes(clinicId) &&
      !(role === "owner" && clinic.ownerId === uid)) {
    throw new ApiError(403, "Sem acesso à clínica informada.");
  }
  if (!isSuperAdmin) {
    const trialEndsAt = clinic.trialEndsAt;
    const trialMissingAllowed =
      trialEndsAt == null && LEGACY_TRIALLESS_TEST_CLINIC_IDS.has(clinicId);
    const trialInvalidOrExpired = trialEndsAt == null
      ? !trialMissingAllowed
      : !(trialEndsAt instanceof Date) || trialEndsAt.getTime() <= Date.now();
    if (clinic.blockedByAdmin === true || trialInvalidOrExpired) {
      throw new ApiError(403, "A clínica está bloqueada ou sem uma data de trial válida/ativa.");
    }
  }

  const patient = await readFirestoreDocument(token, "patients/" + patientId, env);
  if (!patient || patient.clinicId !== clinicId) {
    throw new ApiError(404, "Paciente não encontrado nesta clínica.");
  }
  return { user, clinic, patient, isSuperAdmin };
}

function getBearer(request) {
  const value = request.headers.get("Authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(value);
  if (!match) throw new ApiError(401, "Entre novamente para continuar.");
  return match[1];
}

async function authenticatedRequest(request, env) {
  const token = getBearer(request);
  const identity = await verifyFirebaseIdToken(token, env);
  return { token, ...identity };
}

function getMetadataKey(metadata, clinicId, patientId) {
  const key = String(metadata.path || metadata.publicId || "");
  if (
    metadata.resourceType !== "r2" ||
    metadata.url !== "r2://" + key ||
    !key.startsWith(clinicId + "/" + patientId + "/") ||
    key.split("/").length !== 3 ||
    key.includes("..")
  ) {
    throw new ApiError(404, "Arquivo privado não encontrado.");
  }
  return key;
}

async function readLinkedDocument(token, env, clinicId, patientId, documentId) {
  if (!validDocumentId(documentId)) throw new ApiError(400, "Documento inválido.");
  const metadata = await readFirestoreDocument(
    token,
    "patients/" + patientId + "/docs/" + documentId,
    env,
  );
  if (!metadata) throw new ApiError(404, "Metadados do documento não encontrados.");
  return { metadata, key: getMetadataKey(metadata, clinicId, patientId) };
}

function corsHeaders(request, env) {
  const origin = request.headers.get("Origin");
  const allowed = String(env.ALLOWED_ORIGINS || "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
  if (!origin) return { allowed: true, headers: {} };
  if (!allowed.includes(origin)) return { allowed: false, headers: {} };
  return {
    allowed: true,
    headers: {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Max-Age": "86400",
      Vary: "Origin",
    },
  };
}

function jsonResponse(payload, status, cors) {
  const headers = new Headers(cors || {});
  headers.set("Content-Type", "application/json; charset=utf-8");
  headers.set("Cache-Control", "no-store");
  return new Response(JSON.stringify(payload), { status: status || 200, headers });
}

async function signDownload(env, key, expires) {
  const secret = env.DOWNLOAD_SIGNING_SECRET || "";
  if (secret.length < 32) {
    throw new ApiError(503, "O armazenamento privado ainda não foi configurado.");
  }
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      new TextEncoder().encode(key + "\n" + expires),
    ),
  );
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left, right) {
  if (left.length !== right.length) return false;
  let different = 0;
  for (let i = 0; i < left.length; i++) {
    different |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return different === 0;
}

async function handleUpload(request, url, env) {
  const { token, uid } = await authenticatedRequest(request, env);
  await enforceRateLimit(env, "UPLOAD_RATE_LIMITER", uid + ":upload",
    "Muitos envios em pouco tempo. Tente novamente em um minuto.");
  const clinicId = url.searchParams.get("clinicId") || "";
  const patientId = url.searchParams.get("patientId") || "";
  await authorizePatient(token, uid, clinicId, patientId, env);

  const declaredLength = Number(request.headers.get("Content-Length") || "0");
  if (declaredLength > MAX_CONTENT_LENGTH) {
    throw new ApiError(413, "O arquivo excede o limite de 10 MB.");
  }
  let form;
  try {
    form = await request.formData();
  } catch (_) {
    throw new ApiError(400, "O arquivo enviado está inválido.");
  }
  const file = form.get("file");
  if (!file || typeof file.arrayBuffer !== "function" || typeof file.size !== "number") {
    throw new ApiError(400, "Selecione um arquivo para enviar.");
  }
  if (file.size > 10 * 1024 * 1024) {
    throw new ApiError(413, "O arquivo excede o limite de 10 MB.");
  }

  const title = String(form.get("title") || file.name || "Documento").trim();
  const category = String(form.get("category") || "Exames").trim();
  const uploaderName = String(form.get("uploaderName") || "Usuário").trim().slice(0, 100);
  const allowedCategories = new Set([
    "Exames", "Radiografias", "Documentos Pessoais",
    "Contratos", "Fotos", "Outros",
  ]);
  if (!title || title.length > 150 || /[\u0000-\u001f\u007f]/.test(title)) {
    throw new ApiError(400, "Informe um nome de arquivo válido (até 150 caracteres).");
  }
  if (!allowedCategories.has(category)) {
    throw new ApiError(400, "Categoria de documento inválida.");
  }

  const name = String(file.name || title);
  const bytes = new Uint8Array(await file.arrayBuffer());
  let valid;
  try {
    valid = validateDocumentFile(name, bytes);
  } catch (error) {
    throw new ApiError(400, error.message);
  }

  const documentId = crypto.randomUUID().replaceAll("-", "");
  const key = clinicId + "/" + patientId + "/" + documentId + "." + valid.extension;
  const uploadedAt = new Date();
  await env.FILES.put(key, bytes, {
    httpMetadata: {
      contentType: valid.contentType,
      contentDisposition: "inline",
      cacheControl: "private, no-store",
    },
    customMetadata: {
      clinicId,
      patientId,
      uploadedBy: uid,
      createdAt: uploadedAt.toISOString(),
    },
  });

  const metadata = {
    title,
    category,
    url: "r2://" + key,
    path: key,
    publicId: key,
    resourceType: "r2",
    fileType: valid.contentType.startsWith("image/") ? "image" : "document",
    extension: "." + valid.extension,
    sizeBytes: valid.sizeBytes,
    uploadedAt,
    uploadedBy: uploaderName || uid,
  };
  try {
    // Arquivo + metadata são provisionados no mesmo endpoint: evita o estado
    // comum onde o upload teve sucesso mas o app fechou antes de gravar no Firestore.
    await createFirestoreDocument(
      token,
      "patients/" + patientId + "/docs/" + documentId,
      metadata,
      env,
    );
  } catch (error) {
    try {
      await env.FILES.delete(key);
    } catch (_) {
      console.error("Não foi possível reverter objeto sem metadata.");
    }
    throw error;
  }

  return {
    documentId,
    url: metadata.url,
    path: key,
    publicId: key,
    resourceType: "r2",
    sizeBytes: valid.sizeBytes,
    extension: valid.extension,
    contentType: valid.contentType,
  };
}

async function handleDownloadLink(request, url, env) {
  const { token, uid } = await authenticatedRequest(request, env);
  await enforceRateLimit(env, "DOWNLOAD_LINK_RATE_LIMITER", uid + ":download",
    "Muitos pedidos de link de arquivo. Tente novamente em um minuto.");
  const clinicId = url.searchParams.get("clinicId") || "";
  const patientId = url.searchParams.get("patientId") || "";
  const documentId = url.searchParams.get("documentId") || "";
  await authorizePatient(token, uid, clinicId, patientId, env);
  const { key } = await readLinkedDocument(token, env, clinicId, patientId, documentId);
  const object = await env.FILES.head(key);
  if (!object || object.customMetadata?.clinicId !== clinicId ||
      object.customMetadata?.patientId !== patientId) {
    throw new ApiError(404, "Arquivo privado não encontrado.");
  }
  const expires = Math.floor(Date.now() / 1000) + SIGNED_URL_TTL_SECONDS;
  const signature = await signDownload(env, key, expires);
  const signed = new URL("/v1/files/content", url.origin);
  signed.searchParams.set("key", key);
  signed.searchParams.set("exp", String(expires));
  signed.searchParams.set("sig", signature);
  return { url: signed.toString(), expiresAt: expires };
}

async function handleDelete(request, env) {
  const { token, uid } = await authenticatedRequest(request, env);
  await enforceRateLimit(env, "DELETE_RATE_LIMITER", uid + ":delete",
    "Muitas exclusões em pouco tempo. Tente novamente em um minuto.");
  let body;
  try {
    body = await request.json();
  } catch (_) {
    throw new ApiError(400, "Solicitação inválida.");
  }
  const clinicId = String(body.clinicId || "");
  const patientId = String(body.patientId || "");
  const documentId = String(body.documentId || "");
  await authorizePatient(token, uid, clinicId, patientId, env);
  const { key } = await readLinkedDocument(token, env, clinicId, patientId, documentId);
  const object = await env.FILES.head(key);
  if (!object) return { deleted: true };
  if (object.customMetadata?.clinicId !== clinicId ||
      object.customMetadata?.patientId !== patientId) {
    throw new ApiError(403, "O arquivo não corresponde ao paciente solicitado.");
  }
  await env.FILES.delete(key);
  return { deleted: true };
}

async function handleContent(request, url, env, cors) {
  const key = url.searchParams.get("key") || "";
  const expires = Number(url.searchParams.get("exp") || "0");
  const signature = url.searchParams.get("sig") || "";
  const now = Math.floor(Date.now() / 1000);
  if (!key || key.split("/").length !== 3 || key.includes("..") ||
      !Number.isInteger(expires) || expires <= now ||
      expires > now + SIGNED_URL_TTL_SECONDS + 30 ||
      !/^[0-9a-f]{64}$/.test(signature)) {
    throw new ApiError(403, "Link de arquivo inválido ou expirado.");
  }
  const expected = await signDownload(env, key, expires);
  if (!constantTimeEqual(expected, signature)) {
    throw new ApiError(403, "Link de arquivo inválido ou expirado.");
  }
  await enforceRateLimit(env, "CONTENT_RATE_LIMITER", key + ":" + expires,
    "Muitos acessos ao mesmo link de arquivo. Tente novamente em um minuto.");
  const object = await env.FILES.get(key);
  if (!object ||
      object.customMetadata?.clinicId !== key.split("/")[0] ||
      object.customMetadata?.patientId !== key.split("/")[1]) {
    throw new ApiError(404, "Arquivo não encontrado.");
  }
  const contentType = object.httpMetadata?.contentType || "";
  if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
    throw new ApiError(415, "Tipo de arquivo não permitido.");
  }
  const headers = new Headers(cors);
  headers.set("Content-Type", contentType);
  headers.set("Content-Disposition", "inline");
  headers.set("Cache-Control", "private, no-store, max-age=0");
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Referrer-Policy", "no-referrer");
  return new Response(object.body, { status: 200, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = corsHeaders(request, env);
    if (!cors.allowed) return jsonResponse({ error: "Origem não autorizada." }, 403, {});
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors.headers });
    }
    if (url.pathname === "/health" && request.method === "GET") {
      return jsonResponse({ ok: true, service: "private-documents" }, 200, cors.headers);
    }

    try {
      if (url.pathname === "/v1/files/content" && request.method === "GET") {
        return await handleContent(request, url, env, cors.headers);
      }
      if (url.pathname === "/v1/files/upload" && request.method === "POST") {
        return jsonResponse(await handleUpload(request, url, env), 201, cors.headers);
      }
      if (url.pathname === "/v1/files/download" && request.method === "GET") {
        return jsonResponse(await handleDownloadLink(request, url, env), 200, cors.headers);
      }
      if (url.pathname === "/v1/files/delete" && request.method === "POST") {
        return jsonResponse(await handleDelete(request, env), 200, cors.headers);
      }
      return jsonResponse({ error: "Rota não encontrada." }, 404, cors.headers);
    } catch (error) {
      if (error instanceof ApiError) {
        return jsonResponse({ error: error.message }, error.status, cors.headers);
      }
      // Não registrar tokens, payloads de arquivos ou dados clínicos.
      console.error("Falha no serviço de arquivos privados.");
      return jsonResponse({ error: "Falha no serviço de arquivos privados." }, 500, cors.headers);
    }
  },
};
