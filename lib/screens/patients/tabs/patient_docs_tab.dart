import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';

// Importações do seu projeto
import '../../../services/document_service.dart';
import '../../../services/session_manager.dart';
import '../../../models/patient_document_model.dart';

class PatientDocsTab extends StatefulWidget {
  final String patientId;
  const PatientDocsTab({super.key, required this.patientId});

  @override
  State<PatientDocsTab> createState() => _PatientDocsTabState();
}

class _PatientDocsTabState extends State<PatientDocsTab> {
  final DocumentService _docService = DocumentService();
  final List<String> _categories = ["Todos", "Exames", "Radiografias", "Documentos Pessoais", "Contratos", "Fotos", "Outros"];
  String _selectedCategory = "Todos";
  
  bool _isUploading = false;

  // --- SELEÇÃO DE ARQUIVOS ---
  Future<void> _pickFile(bool isCamera) async {
    File? fileMobile;
    Uint8List? fileBytes;
    String fileName = "";

    if (isCamera) {
      final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera);
      if (photo != null) {
        fileName = "Foto_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.jpg";
        fileBytes = await photo.readAsBytes();
        if (!kIsWeb) fileMobile = File(photo.path);
      }
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result != null) {
        PlatformFile pFile = result.files.single;
        fileName = pFile.name;
        if (kIsWeb) fileBytes = pFile.bytes;
        else if (pFile.path != null) fileMobile = File(pFile.path!);
      }
    }

    if ((fileMobile != null || fileBytes != null) && mounted) {
      _showCategorizationDialog(fileMobile, fileBytes, fileName);
    }
  }

  void _showCategorizationDialog(File? fileMobile, Uint8List? fileBytes, String defaultName) {
    final nameCtrl = TextEditingController(text: defaultName);
    String category = "Exames"; 

    int size = 0;
    if (fileBytes != null) size = fileBytes.length;
    else if (fileMobile != null) size = fileMobile.lengthSync();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Novo Documento"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Nome do Arquivo", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: "Categoria", border: OutlineInputBorder()),
                    items: _categories.where((c) => c != "Todos").map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setStateDialog(() => category = val!),
                  ),
                  const SizedBox(height: 10),
                  Text("Tamanho aprox: ${(size / 1024).toStringAsFixed(0)} KB", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startUpload(fileMobile, fileBytes, nameCtrl.text, category);
                  },
                  child: const Text("ENVIAR"),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _startUpload(File? fileMobile, Uint8List? fileBytes, String name, String category) async {
    final clinicId = SessionManager().currentClinicId;
    if (clinicId == null) return;

    setState(() => _isUploading = true);
    
    try {
      String? uploadedUrl = await _docService.uploadFile(
        file: fileMobile,
        bytes: fileBytes,
        fileName: name,
      );

      if (uploadedUrl == null) throw Exception("Falha no upload para nuvem.");

      String ext = ".${name.split('.').last}";
      if (!name.contains('.')) ext = ".pdf"; 

      await _docService.saveMetadata(
        clinicId: clinicId,
        patientId: widget.patientId,
        url: uploadedUrl,
        title: name,
        category: category,
        ext: ext,
        uploaderName: "Usuario", 
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload concluído!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _openFile(String url, String fileType) async {
    // Se for imagem, abre no visualizador interno
    if (fileType == 'image') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        backgroundColor: Colors.black,
        body: PhotoView(imageProvider: NetworkImage(url)),
      )));
    } else {
      // Se for PDF ou DOC, abre no navegador/app externo
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : () {
          showModalBottomSheet(context: context, builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Tirar Foto"), onTap: () { Navigator.pop(ctx); _pickFile(true); }),
              ListTile(leading: const Icon(Icons.attach_file), title: const Text("Buscar Arquivo"), onTap: () { Navigator.pop(ctx); _pickFile(false); }),
            ],
          ));
        },
        child: _isUploading 
          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) 
          : const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Filtros (Chips)
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _categories.map((cat) {
                  bool isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSel,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                      backgroundColor: Colors.grey[100],
                      selectedColor: Colors.blue[100],
                      labelStyle: TextStyle(color: isSel ? Colors.blue[900] : Colors.black87),
                      checkmarkColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSel ? Colors.blue : Colors.transparent)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Lista de Documentos (ListView em vez de GridView)
          Expanded(
            child: StreamBuilder<List<PatientDocumentModel>>(
              stream: _docService.getDocs(widget.patientId, categoryFilter: _selectedCategory),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // Dica visual para o problema do índice
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text("Erro ao carregar.\nVerifique o console para criar o índice do Firebase.\nErro: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ));
                }

                int uploadCount = _isUploading ? 1 : 0; 
                int docCount = snapshot.hasData ? snapshot.data!.length : 0;
                
                if (uploadCount == 0 && docCount == 0) {
                  return const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 48, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Nenhum documento encontrado.", style: TextStyle(color: Colors.grey)),
                    ],
                  ));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: uploadCount + docCount,
                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    // Item de Loading
                    if (_isUploading && index == 0) {
                      return _buildUploadingTile();
                    }
                    
                    final docIndex = _isUploading ? index - 1 : index;
                    final doc = snapshot.data![docIndex];
                    return _buildDocTile(doc);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUploadingTile() {
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: const ListTile(
        leading: SizedBox(
          width: 24, height: 24, 
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text("Enviando documento...", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDocTile(PatientDocumentModel doc) {
    // Define ícone e cor baseado na extensão/tipo
    IconData icon;
    Color color;
    
    if (doc.fileType == 'image') {
      icon = Icons.image;
      color = Colors.purple;
    } else if (doc.extension.contains('pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (doc.extension.contains('doc')) {
      icon = Icons.description;
      color = Colors.blue;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          doc.title, 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
              child: Text(doc.category, style: TextStyle(fontSize: 10, color: Colors.grey[800])),
            ),
            const SizedBox(width: 8),
            Text(DateFormat('dd/MM/yyyy HH:mm').format(doc.uploadedAt), style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            if (value == 'open') _openFile(doc.url, doc.fileType);
            if (value == 'delete') _confirmDelete(doc);
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text("Visualizar")])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Excluir", style: TextStyle(color: Colors.red))])),
          ],
        ),
        onTap: () => _openFile(doc.url, doc.fileType),
      ),
    );
  }

  void _confirmDelete(PatientDocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir"),
        content: Text("Deseja apagar '${doc.title}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _docService.deleteDocument(widget.patientId, doc.id);
            }, 
            child: const Text("Excluir", style: TextStyle(color: Colors.red))
          )
        ],
      )
    );
  }
}