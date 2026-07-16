// Adicionamos 'root' ao enum
enum ToothFace { occlusal, mesial, distal, vestibular, lingual, root }

class ToothModel {
  final int id;
  Map<String, String> facesStatus; 
  String? notes;

  ToothModel({
    required this.id,
    Map<String, String>? facesStatus,
    this.notes,
  }) : facesStatus = facesStatus ?? {};

  bool get isUpper => id >= 11 && id <= 28;
  
  // --- VERIFICAÇÕES DE ESTADO ---

  // Verifica se existe um Implante Realizado na raiz
  bool get isImplantDone => facesStatus[ToothFace.root.name] == 'implant_done';

  // Verifica se existe uma Coroa Realizada na oclusal
  bool get isCrownDone => facesStatus[ToothFace.occlusal.name] == 'crown_done';

  // Verifica se o dente é "artificial" (não deve permitir cárie nas faces)
  bool get isArtificial => isImplantDone || isCrownDone;

  bool get isMissing => facesStatus.values.any((s) => s == 'missing');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'facesStatus': facesStatus,
      'notes': notes,
    };
  }

  factory ToothModel.fromMap(Map<String, dynamic> map) {
    return ToothModel(
      id: map['id'],
      facesStatus: Map<String, String>.from(map['facesStatus'] ?? {}),
      notes: map['notes'],
    );
  }
}