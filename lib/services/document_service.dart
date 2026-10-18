import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/patient_document_model.dart';

typedef CloudUpload = ({
  String url,
  String? publicId,
  String resourceType,
  String path,
  int sizeBytes,
});

const String _privateFilesApiUrl =
    String.fromEnvironment('PRIVATE_FILES_API_URL');

bool requiresRemoteCloudinaryCleanup(Map<String, dynamic> metadata) {
  final url = '${metadata['url'] ?? ''}';
  final publicId = '${metadata['publicId'] ?? ''}';
  final resourceType = '${metadata['resourceType'] ?? ''}';
  return url.contains('cloudinary.com') ||
      url.startsWith('r2://') ||
      publicId.isNotEmpty ||
      resourceType == 'r2';
}

String? validateUpload({required String fileName, required int sizeBytes}) {
  const maxBytes = 10 * 1024 * 1024;
  const allowed = {'jpg', 'jpeg', 'png', 'webp', 'pdf'};
  final base = fileName.split(RegExp(r'[/\\]')).last;
  final ext = base.contains('.') ? base.split('.').last.toLowerCase() : '';
  if (!allowed.contains(ext)) {
    return 'Tipo não permitido (só JPG, PNG, WEBP ou PDF).';
  }
  if (sizeBytes <= 0) return 'Arquivo vazio.';
  if (sizeBytes > maxBytes) return 'Arquivo acima de 10MB.';
  return null;
}

class DocumentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool get isPrivateStorageConfigured {
    final uri = Uri.tryParse(_privateFilesApiUrl.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')));
  }

  Uri _apiUri(String path, [Map<String, String>? query]) {
    if (!isPrivateStorageConfigured) {
      throw StateError(
        'O armazenamento privado ainda não foi configurado. '
        'Publique o Worker e compile com PRIVATE_FILES_API_URL.',
      );
    }
    final base = _privateFilesApiUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<String> _requireIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Entre novamente para acessar arquivos.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Não foi possível validar sua sessão. Entre novamente.');
    }
    return token;
  }

  String _responseError(http.Response response) {
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['error'] is String) {
        return payload['error'] as String;
      }
    } catch (_) {}
    return 'Serviço de arquivos respondeu com HTTP ${response.statusCode}.';
  }

  Future<CloudUpload?> uploadFile({
    File? file,
    Uint8List? bytes,
    required String fileName,
    required String clinicId,
    required String patientId,
  }) async {
    final content = bytes ?? (file != null ? await file.readAsBytes() : null);
    if (content == null) throw StateError('Não foi possível ler o arquivo.');
    final blocked = validateUpload(fileName: fileName, sizeBytes: content.length);
    if (blocked != null) throw Exception(blocked);

    final token = await _requireIdToken();
    final request = http.MultipartRequest(
      'POST',
      _apiUri('/v1/files/upload', {
        'clinicId': clinicId,
        'patientId': patientId,
      }),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', content, filename: fileName),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) throw StateError(_responseError(response));
    final payload = jsonDecode(response.body);
    if (payload is! Map ||
        payload['resourceType'] != 'r2' ||
        payload['url'] is! String ||
        payload['path'] is! String ||
        payload['sizeBytes'] is! num) {
      throw StateError('Resposta inválida do armazenamento privado.');
    }
    return (
      url: payload['url'] as String,
      publicId: payload['publicId']?.toString(),
      resourceType: 'r2',
      path: payload['path'] as String,
      sizeBytes: (payload['sizeBytes'] as num).toInt(),
    );
  }

  Future<String> resolveDocumentUrl({
    required String clinicId,
    required String patientId,
    required PatientDocumentModel document,
  }) async {
    if (document.resourceType != 'r2' && !document.url.startsWith('r2://')) {
      return document.url;
    }
    final token = await _requireIdToken();
    final uri = _apiUri('/v1/files/download', {
      'clinicId': clinicId,
      'patientId': patientId,
      'documentId': document.id,
    });
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw StateError(_responseError(response));
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['url'] is! String) {
      throw StateError('Resposta inválida ao abrir o arquivo.');
    }
    return payload['url'] as String;
  }

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
    String? path,
    int sizeBytes = 0,
  }) async {
    final normalizedExt = ext.startsWith('.') ? ext.toLowerCase() : '.${ext.toLowerCase()}';
    final fileType = ['.jpg', '.jpeg', '.png', '.webp'].contains(normalizedExt)
        ? 'image'
        : 'document';

    final doc = PatientDocumentModel(
      id: '',
      title: title,
      category: category,
      url: url,
      path: path ?? '',
      publicId: publicId,
      resourceType: resourceType,
      fileType: fileType,
      extension: normalizedExt,
      sizeBytes: sizeBytes,
      uploadedAt: DateTime.now(),
      uploadedBy: uploaderName,
    );

    await _db
        .collection('patients')
        .doc(patientId)
        .collection('docs')
        .add(doc.toMap());
  }

  Future<bool> deleteRemoteFile({
    required String clinicId,
    required String? publicId,
    required String resourceType,
    required String patientId,
    required String documentId,
  }) async {
    if (resourceType != 'r2') return false;
    final token = await _requireIdToken();
    final response = await http.post(
      _apiUri('/v1/files/delete'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'clinicId': clinicId,
        'patientId': patientId,
        'documentId': documentId,
      }),
    );
    if (response.statusCode != 200) throw StateError(_responseError(response));
    final payload = jsonDecode(response.body);
    return payload is Map && payload['deleted'] == true;
  }

  Future<void> purgePatientFiles({
    required String clinicId,
    required List<Map<String, dynamic>> docs,
  }) async {
    final withRemote = docs.where(requiresRemoteCloudinaryCleanup).length;
    if (withRemote > 0) {
      throw StateError(
        'Exclusão cancelada: há $withRemote arquivo(s) em armazenamento remoto. '
        'Remova primeiro cada arquivo pelo fluxo autenticado; a cascata não '
        'apagará referências que deixariam binários órfãos.',
      );
    }
  }

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
    final storedPublicId = data['publicId']?.toString() ?? publicId;
    final actualResourceType =
        data['resourceType']?.toString() ?? resourceType ?? 'image';
    final isRemote = requiresRemoteCloudinaryCleanup({
      'url': storedUrl,
      'publicId': storedPublicId,
      'path': data['path'],
      'resourceType': actualResourceType,
    });

    if (isRemote) {
      final removed = await deleteRemoteFile(
        clinicId: clinicId ?? '',
        publicId: storedPublicId,
        resourceType: actualResourceType,
        patientId: patientId,
        documentId: docId,
      );
      if (!removed) {
        throw StateError(
          'O arquivo remoto não foi apagado. A metadata foi preservada. '
          'Arquivos Cloudinary antigos precisam ser removidos pelo processo '
          'administrativo; arquivos R2 usam o Worker autenticado.',
        );
      }
    }
    await ref.delete();
  }

  Stream<List<PatientDocumentModel>> getDocs(
    String patientId, {
    String? categoryFilter,
  }) {
    Query query = _db
        .collection('patients')
        .doc(patientId)
        .collection('docs')
        .orderBy('uploadedAt', descending: true);
    if (categoryFilter != null && categoryFilter != 'Todos') {
      query = query.where('category', isEqualTo: categoryFilter);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((document) => PatientDocumentModel.fromMap(
              document.id,
              document.data() as Map<String, dynamic>,
            ))
        .toList());
  }
}
