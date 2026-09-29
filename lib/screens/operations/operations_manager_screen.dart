import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/menu_access.dart';
import '../../services/session_manager.dart';
import '../../ui/app_theme.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Gestão Operacional",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        bottom: tabs.isEmpty
            ? null
            : TabBar(
                controller: _controller(tabs.length),
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primary,
                isScrollable:
                    true, // Adicionado scroll caso a tela seja pequena
                tabs: tabs,
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : tabs.isEmpty
              ? const Center(
                  child: Text(
                      "Nenhuma aba liberada para seu usuário. Fale com o proprietário."))
              : TabBarView(
                  controller: _controller(tabs.length),
                  children: bodies,
                ),
    );
  }
}
