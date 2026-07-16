import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import 'tabs/procedures_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/suppliers_tab.dart'; // Importe a nova aba
import 'tabs/card_fees_tab.dart';

class OperationsManagerScreen extends StatefulWidget {
  const OperationsManagerScreen({super.key});

  @override
  State<OperationsManagerScreen> createState() => _OperationsManagerScreenState();
}

class _OperationsManagerScreenState extends State<OperationsManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // AUMENTADO PARA 3 ABAS
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Gestão Operacional", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          isScrollable: true, // Adicionado scroll caso a tela seja pequena
          tabs: const [
            Tab(text: "PROCEDIMENTOS", icon: Icon(Icons.list_alt)),
            Tab(text: "ESTOQUE", icon: Icon(Icons.inventory_2_outlined)),
            // NOVA ABA
            Tab(text: "FORNECEDORES", icon: Icon(Icons.people_alt_outlined)),
            Tab(text: "CARTÕES", icon: Icon(Icons.payment)), // Nova Aba
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ProceduresTab(),
          InventoryTab(),
          // NOVA ABA
          SuppliersTab(),
          CardFeesTab(), // Nova Tela
        ],
      ),
    );
  }
}