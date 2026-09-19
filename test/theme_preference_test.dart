import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_controle/services/theme_controller.dart';

void main() {
  group('ThemeController.resolveTheme', () {
    test('preferência do usuário vence a do aparelho', () {
      expect(
        ThemeController.resolveTheme(
            userPref: 'dark', devicePref: 'light'),
        isTrue,
      );
      expect(
        ThemeController.resolveTheme(
            userPref: 'light', devicePref: 'dark'),
        isFalse,
      );
    });

    test('sem preferência do usuário, vale a do aparelho', () {
      expect(
        ThemeController.resolveTheme(devicePref: 'dark'),
        isTrue,
      );
      expect(
        ThemeController.resolveTheme(devicePref: 'light'),
        isFalse,
      );
    });

    test('sem nada, claro', () {
      expect(ThemeController.resolveTheme(), isFalse);
    });

    test('valor inválido do usuário cai no aparelho', () {
      expect(
        ThemeController.resolveTheme(
            userPref: 'banana', devicePref: 'dark'),
        isTrue,
      );
    });
  });
}
