export const MAX_FILE_BYTES = 10 * 1024 * 1024;

const EXTENSIONS = new Set(["jpg", "jpeg", "png", "webp", "pdf"]);

export function validateDocumentFile(fileName, input) {
  if (!(input instanceof Uint8Array)) {
    throw new TypeError("O conteúdo do arquivo é inválido.");
  }
  if (input.byteLength <= 0) {
    throw new Error("O arquivo está vazio.");
  }
  if (input.byteLength > MAX_FILE_BYTES) {
    throw new Error("O arquivo excede o limite de 10 MB.");
  }

  const baseName = String(fileName || "").split(/[\\/]/).pop() || "";
  const extension = baseName.includes(".")
    ? baseName.split(".").pop().toLowerCase()
    : "";
  if (!EXTENSIONS.has(extension)) {
    throw new Error("Tipo não permitido. Envie JPG, PNG, WEBP ou PDF.");
  }

  const starts = (signature) =>
    signature.every((byte, index) => input[index] === byte);
  let contentType = "";
  if (starts([0xff, 0xd8, 0xff])) contentType = "image/jpeg";
  else if (starts([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    contentType = "image/png";
  } else if (
    input.length >= 12 &&
    starts([0x52, 0x49, 0x46, 0x46]) &&
    String.fromCharCode(...input.slice(8, 12)) === "WEBP"
  ) {
    contentType = "image/webp";
  } else if (String.fromCharCode(...input.slice(0, 5)) === "%PDF-") {
    contentType = "application/pdf";
  }

  const expected = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    webp: "image/webp",
    pdf: "application/pdf",
  }[extension];
  if (!contentType || contentType !== expected) {
    throw new Error("O conteúdo do arquivo não corresponde à extensão informada.");
  }

  return {
    extension,
    contentType,
    sizeBytes: input.byteLength,
  };
}
