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
    'exportar',
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
    'exportar': 14,
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
    'exportar': 'Exportar backup',
    // Sub-chaves: abas e seções da Gestão (sem índice de menu).
    'g_proc': 'Gestão: Procedimentos',
    'g_estoque': 'Gestão: Estoque',
    'g_forn': 'Gestão: Fornecedores',
    'g_cart': 'Gestão: Cartões',
    'g_config': 'Gestão: Configurações',
    'g_pix': 'Gestão: Pix da clínica',
    'g_grade': 'Gestão: Grade de horários',
    'g_acesso': 'Gestão: Controle de acesso',
    'g_clinica': 'Gestão: Dados da clínica',
  };

  /// Abas da Gestão filtráveis (ordem = TabBar).
  static const List<String> gestaoTabKeys = [
    'g_proc',
    'g_estoque',
    'g_forn',
    'g_cart',
    'g_config',
  ];

  /// Seções sensíveis dentro de Configurações.
  static const List<String> gestaoSectionKeys = [
    'g_pix',
    'g_grade',
    'g_acesso',
    'g_clinica',
  ];

  /// Pode exibir o item? Puro e testado.
  ///
  /// Defaults por papel espelham os cadeados antigos do menu lateral:
  /// sem mapa, cada papel vê exatamente o que via antes — e o owner
  /// passa a ajustar por usuário. Mapa explícito sempre vence o default.
  static bool canShow({
    required bool isOwner,
    String? role,
    required String menuKey,
    Map<String, bool>? access,
  }) {
    // Master é trava dupla: só superadmin, com opt-out no mapa.
    if (menuKey == 'master') {
      if (_normRole(role) != 'superadmin') return false;
      if (access != null && access.containsKey('master')) {
        return access['master']!;
      }
      return true;
    }
    if (isOwner) return true;
    if (access != null && access.containsKey(menuKey)) {
      return access[menuKey]!;
    }
    return defaultFor(role: role, menuKey: menuKey);
  }

  /// Default por papel quando o mapa não diz nada sobre a chave.
  static bool defaultFor({String? role, required String menuKey}) {
    switch (menuKey) {
      case 'master':
        return _normRole(role) == 'superadmin';
      case 'exportar':
        // Backup: somente owner (a tela também guarda sozinha).
        return false;
      case 'gestao':
        return _normRole(role) == 'recepcionista';
      case 'clinicas':
      case 'funcionarios':
        return false;
      // Seções sensíveis do Config: só owner por padrão (liberável).
      case 'g_pix':
      case 'g_grade':
      case 'g_acesso':
      case 'g_clinica':
        return _normRole(role) == 'owner';
      default:
        // Itens operacionais + abas da Gestão: visíveis por padrão.
        return true;
    }
  }

  static String _normRole(String? role) =>
      (role ?? '').toLowerCase().trim();

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
