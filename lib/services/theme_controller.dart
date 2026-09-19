import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, debugPrint, kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../ui/app_theme.dart';

/// Tema claro/escuro como **preferência do usuário**.
///
/// Fonte de verdade: `user_prefs/{uid}` (`{themeMode: 'dark'|'light'}`),
/// vale em qualquer aparelho. Sem preferência salva = **claro**.
/// Logout volta para claro. O `localStorage` serve só p/ o primeiro
/// paint antes do login. Offline/erro: mantém o atual.
///
/// Troca via `ThemeController().setDark(bool)` — sincroniza
/// `AppColors.isDark` e notifica o `MaterialApp` (ver `main.dart`).
/// `loadForUser` roda no `RoleCheckScreen`; `clearUser` no logout.
class ThemeController extends ChangeNotifier {
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal() {
    _loadDevice();
  }

  static const _storageKey = 'odonto_theme';

  bool _isDark = false;
  bool get isDark => _isDark;

  String? _uid;

  /// Ordem: preferência do usuário > aparelho > claro. Puro e testado.
  static bool resolveTheme({String? userPref, String? devicePref}) {
    if (userPref == 'dark') return true;
    if (userPref == 'light') return false;
    return devicePref == 'dark';
  }

  String? _devicePref() {
    try {
      if (kIsWeb) return html.window.localStorage[_storageKey];
    } catch (_) {}
    return null;
  }

  void _loadDevice() {
    _isDark = resolveTheme(devicePref: _devicePref());
    AppColors.isDark = _isDark;
  }

  void _apply(bool value) {
    _isDark = value;
    AppColors.isDark = value;
    notifyListeners();
  }

  /// Carrega a preferência do usuário (pós-login). Sem nada salvo = claro.
  Future<void> loadForUser(String uid) async {
    _uid = uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_prefs')
          .doc(uid)
          .get();
      final pref = doc.data()?['themeMode']?.toString();
      if (pref == 'dark' || pref == 'light') {
        _apply(pref == 'dark');
        return;
      }
      debugPrint('ThemeController: sem preferência salva, usando claro.');
    } catch (e) {
      // Causa nº 1: rules `user_prefs` ainda não publicadas
      // (firebase deploy --only firestore:rules) → PERMISSION_DENIED.
      debugPrint('ThemeController.loadForUser falhou: $e');
    }
    _apply(false);
  }

  /// Retorna true se salvou na nuvem (ou não havia usuário).
  Future<bool> setDark(bool value) async {
    _apply(value);
    try {
      if (kIsWeb) {
        html.window.localStorage[_storageKey] = value ? 'dark' : 'light';
      }
      final uid = _uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('user_prefs')
            .doc(uid)
            .set({'themeMode': value ? 'dark' : 'light'},
                SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      debugPrint('ThemeController.setDark não salvou na nuvem: $e');
      return false;
    }
  }

  /// Logout: esquece o usuário e MANTÉM o último tema escolhido
  /// (a tela de login reflete o `localStorage`).
  void clearUser() {
    _uid = null;
    try {
      if (kIsWeb) {
        html.window.localStorage[_storageKey] =
            _isDark ? 'dark' : 'light';
      }
    } catch (_) {}
  }
}
