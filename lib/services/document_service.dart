import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/patient_document_model.dart';

/// Resultado do upload: URL pública + identificadores para destroy remoto.
typedef CloudUpload = ({String url, String? publicId, String resourceType});

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

  /// Credenciais de destroy em
  /// `clinics/{clinicId}/settings/integrations/cloudinary`
  /// (`{apiKey, apiSecret}`). Ausente = pula o remoto (só Firestore).
  /// Nota: qualquer usuário autenticado lê `settings/**` (ver
  /// firestore.rules) — para segredo forte, mover o destroy p/ Function.
  Future<Map<String, String>?> _destroyCredentials(
      String clinicId) async {
    try {
      final doc = await _db
          .collection('clinics')
          .doc(clinicId)
          .collection('settings')
          .doc('integrations')
          .collection('cloudinary')
          .doc('config')
          .get();
      final data = doc.data();
      final key = data?['apiKey']?.toString() ?? '';
      final secret = data?['apiSecret']?.toString() ?? '';
      if (key.isEmpty || secret.isEmpty) return null;
      return {'apiKey': key, 'apiSecret': secret};
    } catch (_) {
      return null;
    }
  }

  /// Destroy remoto no Cloudinary (assinado). Retorna true se removeu.
  Future<bool> deleteRemoteFile({
    required String clinicId,
    required String? publicId,
    String resourceType = 'image',
  }) async {
    if (publicId == null || publicId.isEmpty) return false;
    final creds = await _destroyCredentials(clinicId);
    if (creds == null) {
      debugPrint('Cloudinary: sem credenciais de destroy; pulando remoto.');
      return false;
    }
    try {
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final toSign =
          'public_id=$publicId&timestamp=$timestamp${creds['apiSecret']}';
      final signature = sha1.convert(utf8.encode(toSign)).toString();
      final response = await http.post(
        Uri.parse(
            'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy'),
        body: {
          'public_id': publicId,
          'api_key': creds['apiKey']!,
          'timestamp': timestamp,
          'signature': signature,
        },
      );
      if (response.statusCode == 200 &&
          jsonDecode(response.body)['result'] == 'ok') {
        return true;
      }
      debugPrint('Cloudinary destroy falhou: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Cloudinary destroy erro: $e');
      return false;
    }
  }

  /// Limpeza remota em lote (ex.: cascata de paciente). Ignora docs
  /// sem `publicId` (uploads antigos) e segue mesmo se algum falhar.
  Future<void> purgePatientFiles({
    required String clinicId,
    required List<Map<String, dynamic>> docs,
  }) async {
    for (final data in docs) {
      await deleteRemoteFile(
        clinicId: clinicId,
        publicId: data['publicId']?.toString(),
        resourceType: data['resourceType']?.toString() ?? 'image',
      );
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