import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/document_service.dart';

void main() {
  group('validateUpload', () {
    test('aceita jpg/png/pdf até 10MB', () {
      expect(validateUpload(fileName: 'doc.pdf', sizeBytes: 1000), isNull);
      expect(
          validateUpload(fileName: 'foto.JPG', sizeBytes: 10 * 1024 * 1024),
          isNull);
    });

    test('barra tipo proibido, vazio e acima do limite', () {
      expect(validateUpload(fileName: 'video.mp4', sizeBytes: 1000),
          isNotNull);
      expect(validateUpload(fileName: 'semext', sizeBytes: 1000), isNotNull);
      expect(validateUpload(fileName: 'a.pdf', sizeBytes: 0), isNotNull);
      expect(
          validateUpload(
              fileName: 'a.pdf', sizeBytes: 10 * 1024 * 1024 + 1),
          isNotNull);
    });
  });
}
