import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Upload direto unsigned ao Cloudinary está desativado de propósito.
  /// O preset/URL do Cloudinary fica visível no navegador, e não é seguro
  /// para documentos clínicos sem endpoint assinado/autenticado no servidor.
  /// Os registros antigos continuam legíveis pelos seus metadados; esta trava
  /// só impede a criação de novos uploads públicos.
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

    throw StateError(
      'Upload temporariamente bloqueado por segurança. Documentos clínicos '
      'precisam de um endpoint de upload autenticado/assinado; não envie '
      'dados reais até essa integração ser configurada.',
    );
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
    final ref = _db
        .collection('patients')
        .doc(patientId)
        .collection('docs')
        .doc(docId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;
    final data = snapshot.data() ?? <String, dynamic>{};
    final storedUrl = '${data['url'] ?? ''}';
    final storedPublicId = publicId ?? data['publicId']?.toString();
    final isCloudinary = storedUrl.contains('cloudinary.com') ||
        (storedPublicId ?? '').isNotEmpty;

    if (isCloudinary) {
      final removed = await deleteRemoteFile(
        clinicId: clinicId ?? '',
        publicId: storedPublicId,
        resourceType: resourceType ?? data['resourceType']?.toString() ?? 'image',
      );
      if (!removed) {
        throw StateError(
          'O arquivo remoto ainda não foi apagado. Os metadados foram '
          'preservados para não indicar uma exclusão que não ocorreu. '
          'A remoção física precisa ser feita por um processo administrativo autenticado.',
        );
      }
    }
    await ref.delete();
  }

  Stream<List<PatientDocumentModel>> getDocs(String patientId, {String? categoryFilter}) {
    Query query = _db.collection('patients').doc(patientId).collection('docs').orderBy('uploadedAt', descending: true);
    
    if (categoryFilter != null && categoryFilter != 'Todos') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query.snapshots().map((s) => s.docs.map((d) => PatientDocumentModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }
}