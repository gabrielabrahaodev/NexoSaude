/// Estágio terapêutico do paciente (clínicas de psicologia).
///
/// Gravado em `patients.status` com os valores estáveis em inglês
/// (`lead`/`active`/`discharged` — sem migração de dados); a UI exibe
/// os rótulos em palavras do usuário via [label].
/// Desconhecido/ausente (ex.: `Ativo` legado) cai em [lead] (Prospecto).
/// Só existe para psicologia — dental usa `status: 'Ativo'` e ignora.
enum TherapeuticStatus { lead, active, discharged }

extension TherapeuticStatusX on TherapeuticStatus {
  /// Rótulo exibido (kanban, cadastro, badges).
  String get label => switch (this) {
        TherapeuticStatus.lead => 'Prospecto',
        TherapeuticStatus.active => 'Acompanhamento',
        TherapeuticStatus.discharged => 'Alta-Manutenção',
      };

  /// Valor persistido no Firestore.
  String get storage => name;
}

/// Parse com fallback prospecto. Puro e testado.
TherapeuticStatus parseTherapeuticStatus(String? raw) {
  for (final s in TherapeuticStatus.values) {
    if (s.name == raw) return s;
  }
  return TherapeuticStatus.lead;
}
