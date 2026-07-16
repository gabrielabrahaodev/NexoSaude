import 'package:cloud_firestore/cloud_firestore.dart';

class PatientDocumentModel {
  final String id;
  final String title;
  final String category; // "Exames", "Radiografias", etc.
  final String url;
  final String path; // Caminho no Storage (para deletar depois)
  final String fileType; // 'image' ou 'document'
  final String extension; // .jpg, .pdf
  final int sizeBytes;
  final DateTime uploadedAt;
  final String uploadedBy;

  PatientDocumentModel({
    required this.id,
    required this.title,
    required this.category,
    required this.url,
    required this.path,
    required this.fileType,
    required this.extension,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'url': url,
      'path': path,
      'fileType': fileType,
      'extension': extension,
      'sizeBytes': sizeBytes,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
    };
  }

  factory PatientDocumentModel.fromMap(String id, Map<String, dynamic> map) {
    return PatientDocumentModel(
      id: id,
      title: map['title'] ?? 'Sem título',
      category: map['category'] ?? 'Geral',
      url: map['url'] ?? '',
      path: map['path'] ?? '',
      fileType: map['fileType'] ?? 'document',
      extension: map['extension'] ?? '',
      sizeBytes: map['sizeBytes'] ?? 0,
      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
      uploadedBy: map['uploadedBy'] ?? '',
    );
  }
}