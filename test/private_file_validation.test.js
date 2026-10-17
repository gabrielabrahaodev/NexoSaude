const test = require('node:test');
const assert = require('node:assert/strict');

(async () => {
  const { validateDocumentFile, MAX_FILE_BYTES } =
    await import('../workers/private-documents/src/validation.js');

  const fixtures = [
    ['arquivo.jpg', [0xff, 0xd8, 0xff, 0x00], 'image/jpeg'],
    ['arquivo.png', [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 'image/png'],
    ['arquivo.webp', [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50], 'image/webp'],
    ['arquivo.pdf', Array.from(Buffer.from('%PDF-1.7')), 'application/pdf'],
  ];

  test('aceita os quatro tipos permitidos pelo conteúdo real', () => {
    for (const [name, bytes, contentType] of fixtures) {
      assert.equal(validateDocumentFile(name, new Uint8Array(bytes)).contentType, contentType);
    }
  });

  test('não confia na extensão: HTML renomeado para PDF é negado', () => {
    assert.throws(
      () => validateDocumentFile('inocente.pdf', new Uint8Array(Buffer.from('<script>alert(1)</script>'))),
      /não corresponde/
    );
  });

  test('nega extensão executável e arquivos vazios', () => {
    assert.throws(() => validateDocumentFile('malware.html', new Uint8Array([1])), /Tipo não permitido/);
    assert.throws(() => validateDocumentFile('vazio.pdf', new Uint8Array()), /vazio/);
  });

  test('nega arquivos maiores que 10 MB', () => {
    assert.throws(
      () => validateDocumentFile('grande.pdf', new Uint8Array(MAX_FILE_BYTES + 1)),
      /10 MB/
    );
  });
})();
