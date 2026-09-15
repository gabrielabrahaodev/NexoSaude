import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/clinic_capabilities.dart';
import '../../services/session_manager.dart';

// IMPORTS DAS TELAS
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
import '../leads/leads_dashboard_screen.dart'; 

// --- NOVO IMPORT: TELA DE PSICOLOGIA ---
import '../patients/psychology/psychology_kanban_board.dart'; 
import '../psychology/psychology_schedule_list_screen.dart';

import '../../main.dart'; 

class MainWebDashboard extends StatefulWidget {
  const MainWebDashboard({super.key});

  @override
  State<MainWebDashboard> createState() => _MainWebDashboardState();
}

class _MainWebDashboardState extends State<MainWebDashboard> {
  int _selectedIndex = 0;
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
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() => _userRole = doc.data()?['role']);
        }
      } catch (e) {
        debugPrint("Erro ao buscar role: $e");
      }
    }
  }

  // Lista de telas atualizada com o Kanban no final
  List<Widget> get _screens => [
    AgendaManagerScreen(key: ValueKey(_currentClinicId)),      // 0
    PatientListScreen(key: ValueKey(_currentClinicId)),        // 1
    LeadsDashboardScreen(key: ValueKey(_currentClinicId)),     // 2
    ClinicLabScreen(key: ValueKey(_currentClinicId)),          // 3
    FinancialReportScreen(key: ValueKey(_currentClinicId)),    // 4
    ReportsScreen(key: ValueKey(_currentClinicId)),            // 5
    OrthoNewsScreen(),                                         // 6
    CollectionsScreen(key: ValueKey(_currentClinicId)),        // 7
    
    // ÁREA RESTRITA
    ClinicManagementScreen(key: ValueKey(_currentClinicId)),   // 8
    EmployeeManagerScreen(key: ValueKey(_currentClinicId)),    // 9
    OperationsManagerScreen(key: ValueKey(_currentClinicId)),  // 10
    
    // --- TELA ESPECIALIZADA ---
    PsychologyKanbanBoard(key: ValueKey('$_currentClinicId-psy-kanban')), // 11

    // --- NOVA TELA: AGENDAS PSICOLOGIA ---
    PsychologyScheduleListScreen(key: ValueKey('$_currentClinicId-psy-sched')), // 12
  ];

  void _onMenuSelect(int index) {
    setState(() => _selectedIndex = index);
    if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _logout() async {
    SessionManager().clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  Widget _buildClinicSelector(bool isCompact) {
    if (_userRole != 'owner') return const SizedBox.shrink();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clinics')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
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

        if (isCompact) {
          return IconButton(
            icon: const Icon(Icons.change_circle, color: Color(0xFF1E88E5)), 
            tooltip: "Trocar Clínica",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expanda o menu para trocar de clínica.")));
            },
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
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
    final bgMenuColor = Colors.white;
    final bgContentColor = const Color(0xFFF5F7FA); 
    final highlightColor = const Color(0xFFE3F2FD); 
    final primaryColor = const Color(0xFF1E88E5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 900;
        
        if (isMobile) {
          return Scaffold(
            backgroundColor: bgContentColor,
            appBar: AppBar(
              title: const Text("OdontoControle Mobile", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 1,
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            drawer: Drawer(
              width: 280,
              backgroundColor: bgMenuColor,
              child: _buildMenuContent(false, highlightColor, primaryColor),
            ),
            body: _screens[_selectedIndex],
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
                  child: _screens[_selectedIndex],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuContent(bool isCompact, Color highlightColor, Color primaryColor) {
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
                  child: Image.asset('assets/dra.png', height: isCompact ? 40 : 80, width: isCompact ? 40 : 80, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 15),
              if (!isCompact) ...[
                Text("ODONTOCONTROLE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 1.5), textAlign: TextAlign.center),
              ]
            ],
          ),
        ),

        // SELETOR
        if (_userRole == 'owner') ...[
          _buildClinicSelector(isCompact),
          const SizedBox(height: 10),
          if (!isCompact) const Divider(height: 1),
        ],
        
        // --- ITENS DO MENU ---
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildMenuItem(0, "Agenda", Icons.calendar_today_outlined, highlightColor, primaryColor, isCompact),
                _buildMenuItem(1, "Pacientes", Icons.people_outline, highlightColor, primaryColor, isCompact),
                
                // LEADs
                _buildMenuItem(2, "Novos Leads", Icons.filter_alt_outlined, highlightColor, Colors.orange[800]!, isCompact),

                // --- ITEM CONDICIONAL PARA PSICOLOGIA ---
                if (ClinicCapabilities.ofType(_currentClinicType)
                    .canShowTherapeuticFlow)
                  _buildMenuItem(11, "Fluxo Terapêutico", Icons.psychology,
                      highlightColor, Colors.purple, isCompact),
                if (ClinicCapabilities.ofType(_currentClinicType)
                    .canUseMonthlyPackages)
                  _buildMenuItem(12, "Agendas Psicologia",
                      Icons.calendar_month, highlightColor, Colors.purple,
                      isCompact),
                // ----------------------------------------

                _buildMenuItem(3, "Laboratório", Icons.science, highlightColor, primaryColor, isCompact),
                _buildMenuItem(4, "Financeiro", Icons.credit_card_outlined, highlightColor, primaryColor, isCompact),
                _buildMenuItem(5, "Relatórios", Icons.bar_chart_outlined, highlightColor, primaryColor, isCompact),
                _buildMenuItem(6, "Notícias", Icons.newspaper, highlightColor, primaryColor, isCompact),
                _buildMenuItem(7, "Cobranças", Icons.chat, highlightColor, Colors.green, isCompact),

                // DONO
                if (_userRole == 'owner') ...[
                  const Divider(height: 30, thickness: 1), 
                  _buildMenuItem(8, "Clínicas", Icons.store_mall_directory, highlightColor, primaryColor, isCompact),
                  _buildMenuItem(9, "Funcionários", Icons.badge_outlined, highlightColor, primaryColor, isCompact),
                ],

                // GESTÃO
                if (_userRole == 'owner' || _userRole == 'recepcionista') ...[
                  if (_userRole != 'owner') const Divider(height: 30, thickness: 1),
                  _buildMenuItem(10, "Gestão", Icons.settings_applications, highlightColor, primaryColor, isCompact),
                ],
              ],
            ),
          ),
        ),

        // SAIR (Mantido igual)
        Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 20),
          child: isCompact 
            ? IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.red), tooltip: "Sair")
            : OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Sair do Sistema"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[400],
                   side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
        )
      ],
    );
  }

  Widget _buildMenuItem(int index, String title, IconData icon, Color highlightColor, Color primaryColor, bool isCompact) {
    bool isSelected = _selectedIndex == index;
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
                    Text(title, style: TextStyle(color: isSelected ? primaryColor : Colors.grey[700], fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 15)),
                    if (isSelected) const Spacer(),
                    if (isSelected) Container(width: 6, height: 6, decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle))
                  ],
                ),
          ),
        ),
      ),
    );
  }
}