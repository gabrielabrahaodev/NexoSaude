import 'package:flutter/material.dart';
import '../../../ui/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/tooth_model.dart';
import '../../../ui/odontogram/tooth_widget.dart';

class OdontogramScreen extends StatefulWidget {
  final String? patientId;
  const OdontogramScreen({super.key, this.patientId});

  @override
  State<OdontogramScreen> createState() => _OdontogramScreenState();
}

class _OdontogramScreenState extends State<OdontogramScreen> {
  List<ToothModel> teeth = [];
  bool _isLoading = true;
  final TransformationController _transformationController = TransformationController();
  bool _hasInitialFit = false; // Controle para ajustar o zoom apenas na primeira vez

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.patientId == null) {
      _initDefaultTeeth();
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .collection('clinical_data')
          .doc('odontogram')
          .get();

      if (doc.exists && doc.data() != null && doc.data()!['teeth'] != null) {
        List<dynamic> savedList = doc.data()!['teeth'];
        setState(() {
          teeth = savedList.map((m) => ToothModel.fromMap(m)).toList();
          _isLoading = false;
        });
      } else {
        _initDefaultTeeth();
      }
    } catch (e) {
      _initDefaultTeeth();
    }
  }

  void _initDefaultTeeth() {
    setState(() {
      teeth = _generateAdultTeeth();
      _isLoading = false;
    });
  }

  // ... (MANTENHA OS MÉTODOS _saveOdontogram, _generateAdultTeeth, _onFaceTap e auxiliares IGUAIS) ...
  Future<void> _saveOdontogram() async {
    // ... (Código de salvar igual ao anterior)
    if (widget.patientId == null) return;
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> dataToSave = teeth.map((t) => t.toMap()).toList();
      await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).collection('clinical_data').doc('odontogram').set({'teeth': dataToSave, 'lastUpdate': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salvo com sucesso!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ToothModel> _generateAdultTeeth() {
    List<ToothModel> list = [];
    for (int i = 8; i >= 1; i--) list.add(ToothModel(id: 10 + i));
    for (int i = 1; i <= 8; i++) list.add(ToothModel(id: 20 + i));
    for (int i = 8; i >= 1; i--) list.add(ToothModel(id: 40 + i));
    for (int i = 1; i <= 8; i++) list.add(ToothModel(id: 30 + i));
    return list;
  }
  
  void _onFaceTap(ToothModel tooth, ToothFace face) {
    // ... (Copie a lógica do _onFaceTap anterior)
      if (tooth.isImplantDone && face != ToothFace.root && face != ToothFace.occlusal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dente com Implante: Ações nas faces estão bloqueadas.")));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Dente ${tooth.id} - ${_getFaceName(face)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (face == ToothFace.root) _buildRootActions(tooth),
                  if (face == ToothFace.occlusal) _buildOcclusalActions(tooth),
                  if (face != ToothFace.root) _buildStandardActions(tooth, face),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Replicando métodos auxiliares para garantir que o código compile
  Widget _buildRootActions(ToothModel tooth) {
    String? status = tooth.facesStatus[ToothFace.root.name];
    return Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
      _buildActionButton("Saudável/Limpar", Colors.grey, null, Icons.cleaning_services, tooth, ToothFace.root),
      _buildActionButton("A Realizar Endodontia", Colors.pinkAccent, 'endo_planned', Icons.medical_services, tooth, ToothFace.root),
      if (status == 'endo_planned' || status == 'endo_done') _buildActionButton("Endodontia Realizada", Colors.black, 'endo_done', Icons.check_circle, tooth, ToothFace.root),
      _buildActionButton("A Realizar Implante", Colors.purpleAccent, 'implant_planned', Icons.construction, tooth, ToothFace.root),
      if (status == 'implant_planned' || status == 'implant_done') _buildActionButton("Implante Realizado", Colors.grey, 'implant_done', Icons.verified, tooth, ToothFace.root),
    ]);
  }
  Widget _buildOcclusalActions(ToothModel tooth) {
    String? status = tooth.facesStatus[ToothFace.occlusal.name];
    return Column(children: [
          const Text("Prótese / Coroa", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)), const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
           _buildActionButton("A Realizar Coroa", Colors.orangeAccent, 'crown_planned', Icons.star_border, tooth, ToothFace.occlusal),
           if (status == 'crown_planned' || status == 'crown_done' || tooth.isImplantDone) _buildActionButton("Coroa Realizada", Colors.teal, 'crown_done', Icons.star, tooth, ToothFace.occlusal),
        ]), const Divider(height: 30), const Text("Ações Padrão", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 10),
    ]);
  }
  Widget _buildStandardActions(ToothModel tooth, ToothFace face) {
    if (tooth.isCrownDone && face == ToothFace.occlusal) return const Text("Coroa instalada. Ações padrão bloqueadas.");
    return Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
      _buildActionButton("Saudável", Colors.grey, null, Icons.cleaning_services, tooth, face),
      _buildActionButton("Cárie/Lesão", Colors.redAccent, 'issue', Icons.warning, tooth, face),
      _buildActionButton("Restaurado", Colors.blueAccent, 'restored', Icons.check_circle, tooth, face),
      _buildActionButton("A Realizar", Colors.orange, 'planned', Icons.next_plan, tooth, face),
      if (face == ToothFace.occlusal) _buildActionButton("Extrair Dente", Colors.black, 'missing', Icons.close, tooth, face),
    ]);
  }
  Widget _buildActionButton(String label, Color color, String? newStatus, IconData icon, ToothModel tooth, ToothFace face) {
    return InkWell(onTap: () { setState(() {
          if (newStatus == 'implant_done' && face == ToothFace.root) { tooth.facesStatus.removeWhere((key, val) => key != ToothFace.root.name); tooth.facesStatus[ToothFace.root.name] = newStatus!; }
          else if (newStatus == 'crown_done' && face == ToothFace.occlusal) { tooth.facesStatus.removeWhere((key, val) => key != ToothFace.root.name && key != ToothFace.occlusal.name); tooth.facesStatus[ToothFace.occlusal.name] = newStatus!; }
          else if (newStatus == 'missing') { for (var f in ToothFace.values) tooth.facesStatus[f.name] = 'missing'; } 
          else if (newStatus == null) { tooth.facesStatus.remove(face.name); if (tooth.isMissing) tooth.facesStatus.clear(); } 
          else { tooth.facesStatus[face.name] = newStatus; }
        }); Navigator.pop(context); },
      child: Column(children: [CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color)), const SizedBox(height: 5), Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)]),
    );
  }
  String _getFaceName(ToothFace face) { switch (face) { case ToothFace.root: return "Raiz"; case ToothFace.occlusal: return "Oclusal/Centro"; case ToothFace.mesial: return "Mesial"; case ToothFace.distal: return "Distal"; case ToothFace.vestibular: return "Vestibular"; case ToothFace.lingual: return "Lingual"; } }
  Widget _buildLegend() {
    const items = [
      [Colors.pinkAccent, "Endo (Planej.)"],
      [Colors.black, "Endo (Realiz.)"],
      [Colors.purpleAccent, "Implante (Planej.)"],
      [Colors.grey, "Implante (Realiz.)"],
      [Colors.orangeAccent, "Coroa (Planej.)"],
      [Colors.teal, "Coroa (Realiz.)"],
      [Colors.redAccent, "Cárie"],
      [Colors.blueAccent, "Restaurado"],
      [Colors.orange, "A Realizar (Face)"],
      [Colors.black87, "Extraído"],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              _legendItem(items[i][0] as Color, items[i][1] as String),
            ],
          ],
        ),
      ),
    );
  }
  Widget _legendItem(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 10))]);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final q1 = teeth.where((t) => t.id >= 11 && t.id <= 18).toList();
    final q2 = teeth.where((t) => t.id >= 21 && t.id <= 28).toList();
    final q4 = teeth.where((t) => t.id >= 41 && t.id <= 48).toList();
    final q3 = teeth.where((t) => t.id >= 31 && t.id <= 38).toList();
    
    const double toothSize = 50.0;
    // Largura estimada do conteúdo (16 dentes * 50px + espaçamentos)
    const double contentWidth = 1000.0; 

    return Scaffold(
      appBar: AppBar(
        title: const Text("Odontograma"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong), 
            tooltip: "Ajustar à Tela",
            // Ação manual de reset
            onPressed: () {
               final screenWidth = MediaQuery.of(context).size.width;
               final scale = screenWidth / contentWidth;
               // Limita o zoom out para não ficar microscópico, e o zoom in para 1.0
               final finalScale = scale.clamp(0.3, 1.0);
               _transformationController.value = Matrix4.identity()..scale(finalScale);
            }
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveOdontogram)
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              // LayoutBuilder é vital para pegar o tamanho da tela na hora de desenhar
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // --- LÓGICA DE AUTO-ZOOM (Executa só 1 vez) ---
                  if (!_hasInitialFit) {
                    // Calculamos: "Quanto eu preciso diminuir o conteúdo para caber nesta largura?"
                    // Se a tela tem 400px e o conteúdo 1000px, o scale deve ser 0.4
                    final double scale = constraints.maxWidth / contentWidth;
                    
                    // Só aplicamos se a tela for menor que o conteúdo (Mobile)
                    if (scale < 1.0) {
                      // Usamos addPostFrameCallback para não dar erro de build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _transformationController.value = Matrix4.identity()..scale(scale);
                      });
                    }
                    _hasInitialFit = true;
                  }

                  return InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.1, 
                    maxScale: 4.0,
                    constrained: false, // Permite conteúdo maior que a tela
                    boundaryMargin: const EdgeInsets.all(100),
                    child: ConstrainedBox(
                      // Força o container a ter no mínimo o tamanho da tela (para centralizar se for pequeno)
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("SUPERIOR", style: TextStyle(letterSpacing: 2, color: Colors.grey)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(children: q1.map((t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ToothWidget(tooth: t, size: toothSize, onFaceTap: _onFaceTap))).toList()),
                                  const SizedBox(width: 40),
                                  Row(children: q2.map((t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ToothWidget(tooth: t, size: toothSize, onFaceTap: _onFaceTap))).toList()),
                                ]
                              ),
                              const SizedBox(height: 40),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(children: q4.map((t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ToothWidget(tooth: t, size: toothSize, onFaceTap: _onFaceTap))).toList()),
                                  const SizedBox(width: 40),
                                  Row(children: q3.map((t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ToothWidget(tooth: t, size: toothSize, onFaceTap: _onFaceTap))).toList()),
                                ]
                              ),
                              const SizedBox(height: 10),
                              const Text("INFERIOR", style: TextStyle(letterSpacing: 2, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              ),
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.yellow[100],
            child: const Text("Dica: Use movimento de pinça (dois dedos) para dar Zoom e arraste para mover", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.brown)),
          ),

          _buildLegend(),
        ],
      ),
    );
  }
}