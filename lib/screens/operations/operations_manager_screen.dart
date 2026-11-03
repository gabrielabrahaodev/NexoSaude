import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/menu_access.dart';
import '../../services/session_manager.dart';
import 'clinical_operations_style.dart';
import 'tabs/procedures_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/suppliers_tab.dart'; // Importe a nova aba
import 'tabs/card_fees_tab.dart';
import 'tabs/settings_tab.dart';

class OperationsManagerScreen extends StatefulWidget {
  const OperationsManagerScreen({super.key});

  @override
  State<OperationsManagerScreen> createState() => _OperationsManagerScreenState();
}

class _OperationsManagerScreenState extends State<OperationsManagerScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  Map<String, bool>? _access;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  /// Mapa do usuário atual (1 leitura). Owner ignora (ver `MenuAccess`).
  Future<void> _loadAccess() async {
    Map<String, bool>? access;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        access = MenuAccess.parse(doc.data()?['menuAccess']);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _access = access;
      _loading = false;
    });
  }

  bool _canTab(String key) => MenuAccess.canShow(
        isOwner: SessionManager().isOwner,
        role: SessionManager().userRole,
        menuKey: key,
        access: _access,
      );

  List<Tab> get _tabs => [
        if (_canTab('g_proc'))
          const Tab(text: "PROCEDIMENTOS", icon: Icon(Icons.list_alt)),
        if (_canTab('g_estoque'))
          const Tab(
              text: "ESTOQUE", icon: Icon(Icons.inventory_2_outlined)),
        // NOVA ABA
        if (_canTab('g_forn'))
          const Tab(
              text: "FORNECEDORES",
              icon: Icon(Icons.people_alt_outlined)),
        if (_canTab('g_cart'))
          const Tab(text: "CARTÕES", icon: Icon(Icons.payment)), // Nova Aba
        if (_canTab('g_config'))
          const Tab(
              text: "CONFIGURAÇÕES",
              icon: Icon(Icons.settings_outlined)),
      ];

  List<Widget> get _bodies => [
        if (_canTab('g_proc')) const ProceduresTab(),
        if (_canTab('g_estoque')) const InventoryTab(),
        // NOVA ABA
        if (_canTab('g_forn')) const SuppliersTab(),
        if (_canTab('g_cart')) const CardFeesTab(), // Nova Tela
        // Config recebe o mapa p/ portas por seção (Pix/Grade/Acesso).
        if (_canTab('g_config')) SettingsTab(tabAccess: _access),
      ];

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  TabController _controller(int length) {
    if (_tabController == null || _tabController!.length != length) {
      _tabController?.dispose();
      _tabController = TabController(length: length, vsync: this);
    }
    return _tabController!;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _loading ? const <Tab>[] : _tabs;
    final bodies = _loading ? const <Widget>[] : _bodies;
    final theme = Theme.of(context);
    final accent = ClinicalOperationsStyle.teal(context);
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: ClinicalOperationsStyle.background(context),
        cardTheme: CardThemeData(color: ClinicalOperationsStyle.panel(context), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(filled: true, fillColor: ClinicalOperationsStyle.elevated(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      ),
      child: ColoredBox(color: ClinicalOperationsStyle.background(context), child: Padding(
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NEXOSAÚDE • MÓDULO ADMINISTRATIVO / GESTÃO OPERACIONAL', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Gestão Operacional', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            Chip(label: Text(SessionManager().currentClinicName ?? 'Unidade ativa', style: TextStyle(color: accent)), backgroundColor: accent.withValues(alpha: .12), side: BorderSide.none),
          ]),
          const SizedBox(height: 8),
          Text('Controle central de catálogo de procedimentos, suprimentos, parceiros, adquirentes e permissões de perfil.', style: TextStyle(color: ClinicalOperationsStyle.muted(context), height: 1.5)),
          const SizedBox(height: 24),
          if (tabs.isNotEmpty) Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ClinicalOperationsStyle.panel(context), borderRadius: BorderRadius.circular(24)),
            child: TabBar(controller: _controller(tabs.length), isScrollable: true, tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
              labelColor: accent, unselectedLabelColor: ClinicalOperationsStyle.muted(context),
              indicator: BoxDecoration(color: ClinicalOperationsStyle.elevated(context), borderRadius: BorderRadius.circular(16)),
              tabs: tabs.map((t) => Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [if (t.icon != null) ...[t.icon!, const SizedBox(width: 10)], Text(t.text ?? '')]))).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : tabs.isEmpty
            ? const Center(child: Text('Nenhuma aba liberada para seu usuário. Fale com o proprietário.'))
            : TabBarView(controller: _controller(tabs.length), children: bodies)),
        ]),
      )),
    );
  }
}
