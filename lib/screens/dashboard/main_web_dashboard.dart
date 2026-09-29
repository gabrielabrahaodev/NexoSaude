import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import '../../services/clinic_capabilities.dart';
import '../../services/menu_access.dart';
import '../../services/pending_counts.dart';
import '../../services/session_manager.dart';
import '../../services/theme_controller.dart';
import '../../ui/app_theme.dart';

// IMPORTS DAS TELAS
import 'kpi_dashboard_screen.dart';
import '../agenda/agenda_manager_screen.dart'; 
import '../financial/financial_report_screen.dart'; 
import '../reports/reports_screen.dart'; 
import '../patients/patient_list_screen.dart';
import '../news/ortho_news_screen.dart'; 
import '../clinics/clinic_management_screen.dart'; 
import '../employees/employee_manager_screen.dart';
import '../operations/operations_manager_screen.dart';
import '../lab/clinic_lab_screen.dart';
import '../financial/collections_screen.dart';

// --- TELA DE PSICOLOGIA ---
import '../patients/psychology/psychology_kanban_board.dart';

// --- MODO ATENDIMENTO ---
import '../care/care_day_screen.dart';

// --- MASTER (dono da plataforma) ---
import '../master/master_screen.dart';

// --- BACKUP (dono da clínica) ---
import '../admin/export_screen.dart';

import '../../main.dart';
import '../../utils/display.dart'; 

class MainWebDashboard extends StatefulWidget {
  const MainWebDashboard({super.key});

  @override
  State<MainWebDashboard> createState() => _MainWebDashboardState();
}

class _MainWebDashboardState extends State<MainWebDashboard> {
  // Tela inicial: Agenda (índice 1 em _screens).
  int _selectedIndex = 1;
  String? _userRole;
  String? _currentClinicId; 
  String? _currentClinicType; // <--- NOVO ESTADO: Tipo da clínica atual

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _currentClinicId = SessionManager().currentClinicId;
    _currentClinicType = SessionManager().clinicType;
    // Tenta carregar o tipo se já houver algo na sessão (opcional, pois o StreamBuilder atualiza depois)
    _checkAppVersion();
  }

  /// PWA: compara a versão instalada (localStorage) com a publicada.
  /// Diferente = mostra "Atualizar" que recarrega limpo (sem Ctrl+F5).
  Future<void> _checkAppVersion() async {
    if (!kIsWeb) return;
    try {
      final res = await http
          .get(Uri.parse(
              'version.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final current =
          (jsonDecode(res.body) as Map)['version']?.toString() ?? '';
      if (current.isEmpty) return;
      final stored =
          html.window.localStorage['nexosaude_app_version'];
      if (stored == null || stored.isEmpty) {
        html.window.localStorage['nexosaude_app_version'] = current;
        return;
      }
      if (stored != current && mounted) {
        final update = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text("Nova versão disponível"),
            content: const Text(
                "O NexoSaúde foi atualizado. Recarregue para usar a versão nova."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Depois"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Atualizar agora"),
              ),
            ],
          ),
        );
        if (update == true) {
          html.window.localStorage['nexosaude_app_version'] = current;
          html.window.location.reload();
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _userRole = data?['role'];
            _menuAccess = MenuAccess.parse(data?['menuAccess']);
            final allowed = data?['allowedClinics'];
            _allowedClinicIds = allowed is List
                ? allowed.map((e) => e.toString()).toList()
                : const [];
          });
        }
      } catch (e) {
        debugPrint("Erro ao buscar role: $e");
      }
    }
  }

  /// Clínicas que o usuário pode acessar (troca no seletor).
  List<String> _allowedClinicIds = [];

  /// Mostra o seletor p/ owner ou quem tem +1 clínica liberada.
  bool get _canSwitchClinic =>
      _userRole == 'owner' || _allowedClinicIds.length > 1;

  Map<String, bool>? _menuAccess;

  /// Scroll do menu lateral (acompanha a expansão do Administração).
  final ScrollController _menuScroll = ScrollController();

  @override
  void dispose() {
    _menuScroll.dispose();
    super.dispose();
  }

  /// Após expandir o Administração, rola até o fim p/ mostrar os subitens.
  void _scrollMenuToEnd() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!_menuScroll.hasClients) return;
      _menuScroll.animateTo(
        _menuScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // Sino de pendências: streams recriados só ao trocar de clínica/role
  // (broadcast: Agenda e Atendimento compartilham sem duplicar leitura).
  Stream<int>? _remarcarStream;
  Stream<int>? _avisoStream;
  String? _pendingScope;

  bool get _isProfessional {
    final role = (_userRole ?? '').toLowerCase();
    return role.contains('dentist') ||
        role == 'dentista' ||
        role == 'psicologo';
  }

  void _ensurePendingStreams() {
    final cid = _currentClinicId;
    final scope = '$cid|$_userRole';
    if (cid == null || scope == _pendingScope) return;
    _pendingScope = scope;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    var q = FirebaseFirestore.instance
        .collection('appointments')
        .where('clinicId', isEqualTo: cid)
        .where('status', isEqualTo: 'remarcar');
    if (_isProfessional && uid != null) {
      q = q.where('dentistId', isEqualTo: uid);
    }
    _remarcarStream = q.snapshots().map((s) => countRemarcar(
        s.docs.map((d) => d.data()).toList())).asBroadcastStream();
    _avisoStream = FirebaseFirestore.instance
        .collection('financial')
        .where('clinicId', isEqualTo: cid)
        .where('status', whereIn: ['pendente', 'pending'])
        .snapshots()
        .map((s) => countAvisos(
            s.docs.map((d) => d.data()).toList()))
        .asBroadcastStream();
  }

  /// Visibilidade do item de menu p/ o usuário atual (aba Configurações).
  /// Owner vê tudo (menos Master); defaults por papel em `MenuAccess`.
  bool _canShow(String menuKey) => MenuAccess.canShow(
        isOwner: _userRole == 'owner',
        role: _userRole,
        menuKey: menuKey,
        access: _menuAccess,
      );

  /// Índice efetivo: se a tela atual foi escondida do usuário, cai no Dashboard.
  int get _effectiveIndex {
    final key = MenuAccess.indexKey[_selectedIndex];
    if (key != null && !_canShow(key)) return 0;
    return _selectedIndex;
  }

  // Lista de telas (índices fixos; o MENU ordena/filtra por tipo de clínica)
  List<Widget> get _screens => [
    KpiDashboardScreen(                                            // 0
      key: ValueKey(_currentClinicId),
      onNavigate: _onMenuSelect,
    ),
    AgendaManagerScreen(key: ValueKey(_currentClinicId)),      // 1
    PatientListScreen(key: ValueKey(_currentClinicId)),        // 2
    ClinicLabScreen(key: ValueKey(_currentClinicId)),          // 3
    FinancialReportScreen(key: ValueKey(_currentClinicId)),    // 4
    ReportsScreen(key: ValueKey(_currentClinicId)),            // 5
    OrthoNewsScreen(),                                         // 6
    CollectionsScreen(key: ValueKey(_currentClinicId)),        // 7

    // ÁREA RESTRITA
    ClinicManagementScreen(key: ValueKey(_currentClinicId)),   // 8
    EmployeeManagerScreen(key: ValueKey(_currentClinicId)),    // 9
    OperationsManagerScreen(key: ValueKey(_currentClinicId)),  // 10

    // --- TELA ESPECIALIZADA (psicologia) ---
    PsychologyKanbanBoard(key: ValueKey('$_currentClinicId-psy-kanban')), // 11

    // --- MODO ATENDIMENTO (profissional) ---
    CareDayScreen(key: ValueKey('$_currentClinicId-care-day')), // 12

    // --- MASTER (dono da plataforma) ---
    MasterScreen(key: const ValueKey('master')), // 13

    // --- BACKUP (dono da clínica) ---
    const ExportScreen(), // 14
  ];

  void _onMenuSelect(int index) {
    setState(() => _selectedIndex = index);
    if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _logout() async {
    SessionManager().clear();
    ThemeController().clearUser(); // volta ao tema do aparelho
    await FirebaseAuth.instance.signOut();
    if (kIsWeb) {
      // PC compartilhado: limpa o cache local. O reload é obrigatório:
      // terminate() inutiliza o singleton do Firestore na sessão, e só
      // um boot novo o ressuscita limpo para o próximo login.
      // Best-effort, nunca trava a saída.
      try {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
      } catch (_) {}
      html.window.location.reload();
      return;
    }
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  Widget _buildClinicSelector(bool isCompact) {
    if (!_canSwitchClinic) return const SizedBox.shrink();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // Owner: unidades dele. Demais: clínicas liberadas (máx 10 no whereIn).
    final ids = _allowedClinicIds.take(10).toList();
    final stream = _userRole == 'owner'
        ? FirebaseFirestore.instance
            .collection('clinics')
            .where('ownerId', isEqualTo: user.uid)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('clinics')
            .where(FieldPath.documentId, whereIn: ids)
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 20, child: LinearProgressIndicator());
        
        final clinics = snapshot.data!.docs;
        if (clinics.isEmpty) return const SizedBox.shrink();

        bool currentIdExists = clinics.any((doc) => doc.id == _currentClinicId);

        if (_currentClinicId == null || !currentIdExists) {
           final firstClinic = clinics.first;
           _currentClinicId = firstClinic.id;
           
           final data = firstClinic.data() as Map<String, dynamic>;
           final type = data['type'] ?? 'dental'; 
           _currentClinicType = type; // Atualiza estado local

            Future.microtask(() {
              SessionManager().setClinic(firstClinic.id, data['name'], type);
              if (mounted) setState(() {}); 
            });
        }

        // Uma só: nada para trocar.
        if (clinics.length <= 1) return const SizedBox.shrink();

        if (isCompact) {
          return IconButton(
            icon: const Icon(Icons.change_circle, color: Color(0xFF1E88E5)), 
            tooltip: "Trocar Clínica",
            onPressed: () {
              toast(context, "Expanda o menu para trocar de clínica.");
            },
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
            ]
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentClinicId,
              isExpanded: true,
              hint: const Text("Selecione a Clínica"),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E88E5)),
              items: clinics.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    data['name'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (newClinicId) {
                if (newClinicId != null) {
                  final selectedDoc = clinics.firstWhere((d) => d.id == newClinicId);
                  final data = selectedDoc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'dental'; 

                  setState(() {
                    _currentClinicId = newClinicId;
                    _currentClinicType = type; // <--- ATUALIZA TIPO PARA MUDAR O MENU
                    SessionManager().setClinic(newClinicId, data['name'], type);
                    // Seleção atual pode ter sumido do menu do novo tipo
                    // (ex.: Laboratório oculto na psico, Fluxo só na psico)
                    final nowPsy =
                        ClinicCapabilities.ofType(type).isPsychology;
                    if ((nowPsy && _selectedIndex == 3) ||
                        (!nowPsy && _selectedIndex == 11)) {
                      _selectedIndex = 0;
                    }
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Acessando: ${data['name']} (${type.toUpperCase()})"), 
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFF1E88E5),
                    )
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Layout responsivo mantido...
    final bgMenuColor = AppColors.surface;
    final bgContentColor = AppColors.background; 
    final highlightColor = const Color(0xFFE3F2FD); 
    final primaryColor = const Color(0xFF1E88E5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 900;
        
        if (isMobile) {
          return Scaffold(
            backgroundColor: bgContentColor,
            appBar: AppBar(
              title: const Text("NexoSaúde", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: AppColors.surface,
              elevation: 1,
              iconTheme: const IconThemeData(),
            ),
            drawer: Drawer(
              width: 280,
              backgroundColor: bgMenuColor,
              child: _buildMenuContent(false, highlightColor, primaryColor),
            ),
            body: _screens[_effectiveIndex],
          );
        }

        final bool isCompactDesktop = constraints.maxWidth < 1100;
        final double sidebarWidth = isCompactDesktop ? 80.0 : 260.0;

        return Scaffold(
          backgroundColor: bgContentColor,
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: sidebarWidth,
                color: bgMenuColor,
                child: _buildMenuContent(isCompactDesktop, highlightColor, primaryColor),
              ),
              Container(width: 1, color: Colors.grey[200]),
              Expanded(
                child: Container(
                  color: bgContentColor,
                  child: _screens[_effectiveIndex],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuContent(bool isCompact, Color highlightColor, Color primaryColor) {
    _ensurePendingStreams();
    return Column(
      children: [
        // CABEÇALHO (Mantido igual)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(vertical: isCompact ? 20 : 30, horizontal: isCompact ? 10 : 20),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: isCompact ? 5 : 15, offset: const Offset(0, 5))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isCompact ? 10 : 20),
                  child: Image.asset('assets/avatar.png', height: isCompact ? 40 : 80, width: isCompact ? 40 : 80, fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ),

        // SELETOR (owner ou multi-clínica; some sozinho se só há uma).
        if (_canSwitchClinic) ...[
          _buildClinicSelector(isCompact),
          const SizedBox(height: 10),
          if (!isCompact) const Divider(height: 1),
        ],
        
        // --- ITENS DO MENU (ordem visual: Agenda, Pacientes, Dashboard...) ---
        // Índices = posição em _screens (não muda por tipo).
        // Psico: Agenda, Pacientes, Dashboard, Atendimento, Cobranças,
        // Fluxo Terapêutico, Financeiro, Relatórios (+ Notícias); Laboratório oculto.
        // Dental: Agenda, Pacientes, Dashboard + ordem original do resto
        // (Fluxo aparece só na psico).
        Expanded(
          child: SingleChildScrollView(
            controller: _menuScroll,
            child: Column(
              children: [
                const SizedBox(height: 10),
                if (ClinicCapabilities.ofType(_currentClinicType)
                    .isPsychology) ...[
                  if (_canShow('agenda')) _buildMenuItem(1, "Agenda", Icons.calendar_today_outlined, highlightColor, primaryColor, isCompact, badge: _remarcarStream),
                  if (_canShow('pacientes')) _buildMenuItem(2, "Pacientes", Icons.people_outline, highlightColor, primaryColor, isCompact),
                  if (_canShow('dashboard')) _buildMenuItem(0, "Dashboard", Icons.dashboard_outlined, highlightColor, primaryColor, isCompact),
                  if (_canShow('atendimento')) _buildMenuItem(12, "Atendimento", Icons.medical_services_outlined, highlightColor, primaryColor, isCompact,),
                  if (_canShow('cobrancas')) _buildMenuItem(7, "Cobranças", Icons.chat, highlightColor, Colors.green, isCompact, badge: _avisoStream),
                  if (_canShow('fluxo')) _buildMenuItem(11, "Fluxo Terapêutico", Icons.psychology,
                      highlightColor, Colors.purple, isCompact),
                  if (_canShow('financeiro')) _buildMenuItem(4, "Financeiro", Icons.credit_card_outlined, highlightColor, primaryColor, isCompact),
                  if (_canShow('relatorios')) _buildMenuItem(5, "Relatórios", Icons.bar_chart_outlined, highlightColor, primaryColor, isCompact),
                  if (_canShow('noticias')) _buildMenuItem(6, "Notícias", Icons.newspaper, highlightColor, primaryColor, isCompact),
                ] else ...[
                  if (_canShow('agenda')) _buildMenuItem(1, "Agenda", Icons.calendar_today_outlined, highlightColor, primaryColor, isCompact, badge: _remarcarStream),
                  if (_canShow('pacientes')) _buildMenuItem(2, "Pacientes", Icons.people_outline, highlightColor, primaryColor, isCompact),
                  if (_canShow('dashboard')) _buildMenuItem(0, "Dashboard", Icons.dashboard_outlined, highlightColor, primaryColor, isCompact),
                  if (_canShow('atendimento')) _buildMenuItem(12, "Atendimento", Icons.medical_services_outlined, highlightColor, primaryColor, isCompact,),

                  // --- ITEM CONDICIONAL PARA PSICOLOGIA ---
                  if (ClinicCapabilities.ofType(_currentClinicType)
                      .canShowTherapeuticFlow && _canShow('fluxo'))
                    _buildMenuItem(11, "Fluxo Terapêutico", Icons.psychology,
                        highlightColor, Colors.purple, isCompact),
                  // ----------------------------------------

                  if (_canShow('laboratorio')) _buildMenuItem(3, "Laboratório", Icons.science, highlightColor, primaryColor, isCompact),
                  if (_canShow('financeiro')) _buildMenuItem(4, "Financeiro", Icons.credit_card_outlined, highlightColor, primaryColor, isCompact),
                  if (_canShow('relatorios')) _buildMenuItem(5, "Relatórios", Icons.bar_chart_outlined, highlightColor, primaryColor, isCompact),
                  if (_canShow('noticias')) _buildMenuItem(6, "Notícias", Icons.newspaper, highlightColor, primaryColor, isCompact),
                  if (_canShow('cobrancas')) _buildMenuItem(7, "Cobranças", Icons.chat, highlightColor, Colors.green, isCompact, badge: _avisoStream),
                ],

                // ADMINISTRAÇÃO (DONO/MASTER/GESTÃO via controle de acesso).
                // Expandida: grupo recolhível; rail compacto: ícones avulsos.
                if (_canShow('clinicas') ||
                    _canShow('funcionarios') ||
                    _canShow('master') ||
                    _canShow('exportar') ||
                    _canShow('gestao')) ...[
                  const Divider(height: 30, thickness: 1),
                  if (!isCompact)
                    ExpansionTile(
                      leading: const Icon(
                          Icons.manage_accounts_outlined,
                          color: Colors.grey),
                      title: const Text("Administração",
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                      initiallyExpanded: false,
                      onExpansionChanged: (open) {
                        if (open) _scrollMenuToEnd();
                      },
                      childrenPadding:
                          const EdgeInsets.only(left: 12),
                      children: [
                        if (_canShow('clinicas'))
                          _buildMenuItem(
                              8,
                              "Clínicas",
                              Icons.store_mall_directory,
                              highlightColor,
                              primaryColor,
                              false),
                        if (_canShow('funcionarios'))
                          _buildMenuItem(
                              9,
                              "Funcionários",
                              Icons.badge_outlined,
                              highlightColor,
                              primaryColor,
                              false),
                        if (_canShow('master'))
                          _buildMenuItem(
                              13,
                              "Master",
                              Icons.admin_panel_settings_outlined,
                              highlightColor,
                              primaryColor,
                              false),
                        if (_canShow('gestao'))
                          _buildMenuItem(
                              10,
                              "Gestão",
                              Icons.settings_applications,
                              highlightColor,
                              primaryColor,
                              false),
                        if (_canShow('exportar'))
                          _buildMenuItem(
                              14,
                              "Exportar",
                              Icons.download_outlined,
                              highlightColor,
                              primaryColor,
                              false),
                      ],
                    ),
                  if (isCompact) ...[
                    if (_canShow('clinicas'))
                      _buildMenuItem(
                          8,
                          "Clínicas",
                          Icons.store_mall_directory,
                          highlightColor,
                          primaryColor,
                          true),
                    if (_canShow('funcionarios'))
                      _buildMenuItem(
                          9,
                          "Funcionários",
                          Icons.badge_outlined,
                          highlightColor,
                          primaryColor,
                          true),
                    if (_canShow('master'))
                      _buildMenuItem(
                          13,
                          "Master",
                          Icons.admin_panel_settings_outlined,
                          highlightColor,
                          primaryColor,
                          true),
                    if (_canShow('gestao'))
                      _buildMenuItem(
                          10,
                          "Gestão",
                          Icons.settings_applications,
                          highlightColor,
                          primaryColor,
                          true),
                    if (_canShow('exportar'))
                      _buildMenuItem(
                          14,
                          "Exportar",
                          Icons.download_outlined,
                          highlightColor,
                          primaryColor,
                          true),
                  ],
                ],
              ],
            ),
          ),
        ),

        // USUÁRIO LOGADO + SAIR (lado a lado)
        Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 20),
          child: _buildUserFooter(isCompact),
        )
      ],
    );
  }

  /// Nome exibido no card (sessão; fallback e-mail do Auth).
  String _displayUserName() {
    final n = (SessionManager().userName ?? '').trim();
    if (n.isNotEmpty) return n;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return email.isNotEmpty ? email : 'Usuário';
  }

  /// Linha única: avatar + nome (1 linha) + sair. Tooltip leva papel • clínica.
  String _displayUserSub() {
    return [
      if ((_userRole ?? '').isNotEmpty) _userRole!,
      if ((SessionManager().currentClinicName ?? '').isNotEmpty)
        SessionManager().currentClinicName!,
    ].join(' • ');
  }

  /// Card compacto de apresentação (avatar + nome + papel • clínica).
  Widget _buildUserCard(String name, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Botão sair quadrado, mesma altura do card.
  Widget _buildLogoutSideButton(String detail) {
    return Tooltip(
      message: "Sair ($detail)",
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.red.withValues(alpha: 0.5)),
          ),
          child: Icon(Icons.logout,
              size: 18, color: Colors.red[400]),
        ),
      ),
    );
  }

  Widget _buildUserFooter(bool isCompact) {
    final name = _displayUserName();
    final sub = _displayUserSub();
    final detail = sub.isNotEmpty ? '$name — $sub' : name;
    if (isCompact) {
      return IconButton(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: Colors.red),
        tooltip: "Sair ($detail)",
      );
    }
    // Card + sair lado a lado (uma linha só).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildUserCard(name, sub)),
          const SizedBox(width: 8),
          _buildLogoutSideButton(detail),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, String title, IconData icon, Color highlightColor, Color primaryColor, bool isCompact, {Stream<int>? badge}) {    bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
           _onMenuSelect(index);
        },
        child: Tooltip(
          message: title,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 15, vertical: 4), 
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: isCompact ? 0 : 15),
            decoration: BoxDecoration(color: isSelected ? highlightColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: isCompact 
              ? Center(child: Icon(icon, color: isSelected ? primaryColor : Colors.grey[600], size: 24))
              : Row(
                  children: [
                    Icon(icon, color: isSelected ? primaryColor : Colors.grey[600], size: 22),
                    const SizedBox(width: 15),
                    Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(color: isSelected ? primaryColor : Colors.grey[700], fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 15))),
                    if (badge != null)
                      StreamBuilder<int>(
                        stream: badge,
                        builder: (context, snap) {
                          final n = snap.data ?? 0;
                          if (n <= 0) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text("$n",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    if (isSelected) Container(width: 6, height: 6, decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle))
                  ],
                ),
          ),
        ),
      ),
    );
  }
}