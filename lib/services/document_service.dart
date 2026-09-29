import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/patient_document_model.dart';

/// Resultado do upload: URL pública + identificadores para destroy remoto.
typedef CloudUpload = ({String url, String? publicId, String resourceType});

/// Validação pré-upload (espelha as travas do preset unsigned).
/// Pura e testada. Retorna a mensagem de erro ou null se ok.
String? validateUpload({required String fileName, required int sizeBytes}) {
  const maxBytes = 10 * 1024 * 1024;
  const allowed = {'jpg', 'jpeg', 'png', 'webp', 'pdf'};
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  if (!allowed.contains(ext)) {
    return "Tipo não permitido (só JPG, PNG, WEBP ou PDF).";
  }
  if (sizeBytes <= 0) return "Arquivo vazio.";
  if (sizeBytes > maxBytes) {
    return "Arquivo acima de 10MB.";
  }
  return null;
}

class DocumentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- CONFIGURAÇÃO CLOUDINARY ---
  // Preencha com os dados do seu painel Cloudinary
  final String cloudName = "dbbh601ay"; 
  final String uploadPreset = "dbbh601ay"; 
  // -------------------------------

  // Upload Híbrido (Web e Mobile) para Cloudinary
  // Retorna URL + public_id/resource_type (para destroy remoto depois)
  Future<CloudUpload?> uploadFile({
    File? file,
    Uint8List? bytes,
    required String fileName,
  }) async {
    final size = kIsWeb
        ? (bytes?.length ?? 0)
        : ((file != null && file.existsSync()) ? file.lengthSync() : 0);
    final blocked = validateUpload(fileName: fileName, sizeBytes: size);
    if (blocked != null) throw Exception(blocked);

    var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
    var request = http.MultipartRequest("POST", uri);

    // Configurações obrigatórias
    request.fields['upload_preset'] = uploadPreset;
    request.fields['resource_type'] = "auto"; // Aceita imagem e pdf

    // Anexa o arquivo
    if (kIsWeb) {
      if (bytes == null) throw Exception("Bytes obrigatórios na Web");
      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        bytes, 
        filename: fileName
      ));
    } else {
      if (file == null) throw Exception("Arquivo obrigatório no Mobile");
      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        file.path
      ));
    }

    try {
      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonMap = jsonDecode(responseString);

        // Retorna a URL segura + identificadores para destroy remoto
        return (
          url: '${jsonMap['secure_url']}',
          publicId: jsonMap['public_id']?.toString(),
          resourceType:
              jsonMap['resource_type']?.toString() ?? 'image',
        );
      } else {
        debugPrint("Erro Cloudinary: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Erro no upload: $e");
      return null;
    }
  }

  // Salva os dados no Firestore (Igual ao anterior)
  Future<void> saveMetadata({
    required String clinicId,
    required String patientId,
    required String url,
    required String title,
    required String category,
    required String ext,
    required String uploaderName,
    String? publicId,
    String? resourceType,
  }) async {
    String fileType = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext.toLowerCase()) ? 'image' : 'document';

    final doc = PatientDocumentModel(
      id: '',
      title: title,
      category: category,
      url: url,
      path: '', // Não usamos path no Cloudinary da mesma forma
      publicId: publicId,
      resourceType: resourceType,
      fileType: fileType,
      extension: ext,
      sizeBytes: 0, // Cloudinary não devolve size fácil no upload simples, mas não é crítico
      uploadedAt: DateTime.now(),
      uploadedBy: uploaderName,
    );

    await _db.collection('patients').doc(patientId).collection('docs').add(doc.toMap());
  }

  /// Destroy remoto DESABILITADO (plano Spark, sem Functions).
  /// O binário permanece no Cloudinary como órfão (limpeza manual ocasional
  /// pelo painel). A exclusão remove só os metadados do Firestore.
  /// Retorna sempre false (= remoto não removido).
  Future<bool> deleteRemoteFile({
    required String clinicId,
    required String? publicId,
    String resourceType = 'image',
  }) async {
    return false;
  }

  /// Limpeza remota em lote (ex.: cascata de paciente). No plano Spark o
  /// destroy é desabilitado: só registra quantos órfãos ficaram na nuvem.
  Future<void> purgePatientFiles({
    required String clinicId,
    required List<Map<String, dynamic>> docs,
  }) async {
    final withRemote =
        docs.where((d) => '${d['publicId'] ?? ''}'.isNotEmpty).length;
    if (withRemote > 0) {
      debugPrint('Cloudinary: $withRemote arquivo(s) mantidos como órfãos '
          '(destroy desabilitado no plano Spark).');
    }
  }

  /// Deleta metadata + tenta o remoto (sem credenciais, só Firestore).
  Future<void> deleteDocument(
    String patientId,
    String docId, {
    String? clinicId,
    String? publicId,
    String? resourceType,
  }) async {
    if (clinicId != null) {
      await deleteRemoteFile(
        clinicId: clinicId,
        publicId: publicId,
        resourceType: resourceType ?? 'image',
      );
    }
    await _db
        .collection('patients')
        .doc(patientId)
        .collection('docs')
        .doc(docId)
        .delete();
  }

  Stream<List<PatientDocumentModel>> getDocs(String patientId, {String? categoryFilter}) {
    Query query = _db.collection('patients').doc(patientId).collection('docs').orderBy('uploadedAt', descending: true);
    
    if (categoryFilter != null && categoryFilter != 'Todos') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query.snapshots().map((s) => s.docs.map((d) => PatientDocumentModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }
}