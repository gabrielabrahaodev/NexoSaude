/// Controle de acesso ao menu lateral por usuário.
///
/// Fonte de verdade: campo `menuAccess` (`Map<String, bool>`) no doc
/// `users/{uid}`. Ausente = tudo visível. `false` esconde aquele item.
/// Owner ignora restrições (sempre tudo visível).
class MenuAccess {
  /// Chave estável por item de menu (usada no Firestore).
  static const List<String> keys = [
    'dashboard',
    'agenda',
    'atendimento',
    'pacientes',
    'laboratorio',
    'financeiro',
    'relatorios',
    'noticias',
    'cobrancas',
    'clinicas',
    'funcionarios',
    'gestao',
    'fluxo',
    'master',
  ];

  /// Índice em `MainWebDashboard._screens` por chave.
  static const Map<String, int> keyIndex = {
    'dashboard': 0,
    'agenda': 1,
    'pacientes': 2,
    'laboratorio': 3,
    'financeiro': 4,
    'relatorios': 5,
    'noticias': 6,
    'cobrancas': 7,
    'clinicas': 8,
    'funcionarios': 9,
    'gestao': 10,
    'fluxo': 11,
    'atendimento': 12,
    'master': 13,
  };

  /// Índice → chave (inverso de [keyIndex]).
  static Map<int, String> get indexKey =>
      {for (final e in keyIndex.entries) e.value: e.key};

  /// Chaves configuráveis por tipo de clínica: espelha o menu lateral —
  /// o que não aparece no menu do tipo não aparece no controle de acesso.
  /// Psico esconde `laboratorio`; dental (e demais) esconde `fluxo`.
  static List<String> keysForClinicType(String? clinicType) {
    if (clinicType == 'psychology') {
      return keys.where((k) => k != 'laboratorio').toList();
    }
    return keys.where((k) => k != 'fluxo').toList();
  }

  /// Rótulo pt-BR por chave (telas de configuração).
  static const Map<String, String> labels = {
    'dashboard': 'Dashboard',
    'agenda': 'Agenda',
    'atendimento': 'Atendimento',
    'pacientes': 'Pacientes',
    'laboratorio': 'Laboratório',
    'financeiro': 'Financeiro',
    'relatorios': 'Relatórios',
    'noticias': 'Notícias',
    'cobrancas': 'Cobranças',
    'clinicas': 'Clínicas',
    'funcionarios': 'Funcionários',
    'gestao': 'Gestão',
    'fluxo': 'Fluxo Terapêutico',
    'master': 'Master',
  };

  /// Pode exibir o item? Puro e testado.
  static bool canShow({
    required bool isOwner,
    required String menuKey,
    Map<String, bool>? access,
  }) {
    if (isOwner) return true;
    if (access == null) return true;
    return access[menuKey] ?? true;
  }

  /// Normaliza mapa vindo do Firestore (dynamic → bool, só chaves válidas).
  static Map<String, bool> parse(dynamic raw) {
    final out = <String, bool>{};
    if (raw is Map) {
      for (final k in keys) {
        final v = raw[k];
        if (v is bool) out[k] = v;
      }
    }
    return out;
  }
}
