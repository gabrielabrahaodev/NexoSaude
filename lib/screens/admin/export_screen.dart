import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import '../../services/session_manager.dart';
import '../../ui/app_theme.dart';
import '../../utils/display.dart';
import '../../widgets/page_header.dart';

/// Exportação de backup — SOMENTE owner (sem filtro de clínica).
/// Formato JSON ou CSV; coleções pré-marcadas, podendo desmarcar.
/// Sensíveis (`portal`, `portal_slots`, `password_reset_requests`,
/// `user_prefs`, `platform_config`) nunca entram na lista.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  static const _collections = <String, String>{
    'Pacientes': 'patients',
    'Agendamentos': 'appointments',
    'Financeiro': 'financial',
    'Despesas': 'expenses',
    'Clínicas': 'clinics',
    'Usuários': 'users',
    'Planos de tratamento': 'treatment_plans',
    'Tratamentos': 'treatments',
    'Orçamentos': 'budgets',
    'Prontuário': 'clinical_records',
    'Dados clínicos': 'clinical_data',
    'Anamnese': 'anamnesis',
    'Laboratório': 'lab_orders',
    'Procedimentos': 'procedures',
    'Fornecedores': 'suppliers',
    'Estoque': 'inventory',
    'Pacotes psico': 'psychology_schedules',
    'Leads': 'leads',
    'Documentos': 'docs',
  };

  late final Map<String, bool> _selected = {
    for (final k in _collections.keys) k: true,
  };
  String _format = 'json';
  bool _exporting = false;
  String _status = '';

  bool get _isOwner => SessionManager().userRole == 'owner';

  /// Converte valores do Firestore p/ tipos serializáveis.
  dynamic _convert(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is Map) {
      return {for (final e in v.entries) '${e.key}': _convert(e.value)};
    }
    if (v is List) return v.map(_convert).toList();
    if (v is DocumentReference) return v.path;
    if (v is GeoPoint) return '${v.latitude},${v.longitude}';
    if (v is Blob) return base64Encode(v.bytes);
    return v;
  }

  String _csvCell(dynamic v) {
    if (v == null) return '';
    if (v is Map || v is List) return jsonEncode(v);
    return '$v';
  }

  String _buildCsv(List<Map<String, dynamic>> docs) {
    final headers = <String>['id'];
    for (final d in docs) {
      for (final k in d.keys) {
        if (!headers.contains(k)) headers.add(k);
      }
    }
    final sb = StringBuffer('\uFEFF');
    sb.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(';'));
    for (final d in docs) {
      sb.writeln(headers
          .map((h) => '"${_csvCell(d[h]).replaceAll('"', '""')}"')
          .join(';'));
    }
    return sb.toString();
  }

  void _download(String filename, String content, String mime) {
    final blob = html.Blob([content], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _export() async {
    final chosen = _collections.entries
        .where((e) => _selected[e.key] == true)
        .toList();
    if (chosen.isEmpty) {
      toast(context, "Selecione ao menos uma coleção.", error: true);
      return;
    }
    setState(() {
      _exporting = true;
      _status = 'Lendo...';
    });
    try {
      final stamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      if (_format == 'json') {
        final all = <String, dynamic>{};
        for (final e in chosen) {
          setState(() => _status = 'Lendo ${e.key}...');
          final snap = await FirebaseFirestore.instance
              .collection(e.value)
              .get();
          all[e.value] = [
            for (final d in snap.docs)
              {'id': d.id, ..._convert(d.data()) as Map<String, dynamic>},
          ];
        }
        _download('nexosaude-backup-$stamp.json',
            jsonEncode(all), 'application/json');
      } else {
        var n = 0;
        for (final e in chosen) {
          setState(() => _status = 'Lendo ${e.key}...');
          final snap = await FirebaseFirestore.instance
              .collection(e.value)
              .get();
          final docs = [
            for (final d in snap.docs)
              {'id': d.id, ..._convert(d.data()) as Map<String, dynamic>},
          ];
          _download('nexosaude-${e.value}-$stamp.csv', _buildCsv(docs),
              'text/csv');
          n++;
        }
        if (mounted) {
          toast(context, "$n arquivo(s) CSV baixado(s). Confira a pasta de downloads.");
        }
      }
      if (mounted) {
        setState(() => _status = 'Concluído.');
        toast(context, "Backup exportado.", ok: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Falha: $e');
        toast(context, "Falha ao exportar: $e", error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner) {
      return const Center(
          child: Text("Acesso restrito ao dono da clínica.",
              style: TextStyle(color: Colors.grey)));
    }
    final allChecked = _selected.values.every((v) => v);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const PageTitle(
            title: "Exportar backup",
            subtitle: "Baixa as coleções em JSON ou CSV"),
        const SizedBox(height: 12),
        const Text("Formato",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Row(
          children: [
            ChoiceChip(
              label: const Text("JSON (1 arquivo)"),
              selected: _format == 'json',
              onSelected: (_) => setState(() => _format = 'json'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text("CSV (1 por coleção)"),
              selected: _format == 'csv',
              onSelected: (_) => setState(() => _format = 'csv'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text("Coleções",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                for (final k in _selected.keys) {
                  _selected[k] = !allChecked;
                }
              }),
              child: Text(allChecked ? "Desmarcar todas" : "Marcar todas"),
            ),
          ],
        ),
        ..._collections.keys.map((label) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(label, style: const TextStyle(fontSize: 13)),
              value: _selected[label],
              onChanged: (v) =>
                  setState(() => _selected[label] = v ?? false),
            )),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download),
            label: Text(_exporting ? _status : "EXPORTAR"),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
          ),
        ),
        if (_status.isNotEmpty && !_exporting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_status,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}
