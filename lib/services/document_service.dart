import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/patient_document_model.dart';

class DocumentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- CONFIGURAÇÃO CLOUDINARY ---
  // Preencha com os dados do seu painel Cloudinary
  final String cloudName = "dbbh601ay"; 
  final String uploadPreset = "dbbh601ay"; 
  // -------------------------------

  // Upload Híbrido (Web e Mobile) para Cloudinary
  // Retorna a URL do arquivo salvo
  Future<String?> uploadFile({
    File? file,
    Uint8List? bytes,
    required String fileName,
  }) async {
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
        
        // Retorna a URL segura (https) gerada pelo Cloudinary
        return jsonMap['secure_url'];
      } else {
        print("Erro Cloudinary: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Erro no upload: $e");
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
  }) async {
    String fileType = ['.jpg', '.jpeg', '.png', '.webp'].contains(ext.toLowerCase()) ? 'image' : 'document';

    final doc = PatientDocumentModel(
      id: '',
      title: title,
      category: category,
      url: url,
      path: '', // Não usamos path no Cloudinary da mesma forma
      fileType: fileType,
      extension: ext,
      sizeBytes: 0, // Cloudinary não devolve size fácil no upload simples, mas não é crítico
      uploadedAt: DateTime.now(),
      uploadedBy: uploaderName,
    );

    await _db.collection('patients').doc(patientId).collection('docs').add(doc.toMap());
  }

  // Deleta apenas do banco de dados (O arquivo fica no Cloudinary, mas como é grátis e ilimitado praticamente, não tem problema)
  Future<void> deleteDocument(String patientId, String docId) async {
    await _db.collection('patients').doc(patientId).collection('docs').doc(docId).delete();
  }

  Stream<List<PatientDocumentModel>> getDocs(String patientId, {String? categoryFilter}) {
    Query query = _db.collection('patients').doc(patientId).collection('docs').orderBy('uploadedAt', descending: true);
    
    if (categoryFilter != null && categoryFilter != 'Todos') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query.snapshots().map((s) => s.docs.map((d) => PatientDocumentModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }
}