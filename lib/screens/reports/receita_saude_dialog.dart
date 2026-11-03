import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/patient_registration.dart';
import '../../models/receita_saude_report.dart';
import '../../services/receita_saude_service.dart';
import '../../utils/display.dart';
import '../../utils/report_export.dart';
import '../care/clinical_care_view.dart';

class ReceitaSaudeDialog extends StatefulWidget {
  const ReceitaSaudeDialog({
    super.key,
    required this.month,
    required this.clinicName,
    required this.load,
    required this.onExport,
    this.defaultOccupation = '226',
  });
  final DateTime month;
  final String clinicName, defaultOccupation;
  final Future<ReceitaSaudeData> Function() load;
  final Future<void> Function(ReceitaSaudeExport) onExport;
  @override
  State<ReceitaSaudeDialog> createState() => _ReceitaSaudeDialogState();
}

class _ReceitaSaudeDialogState extends State<ReceitaSaudeDialog> {
  late Future<ReceitaSaudeData> _future;
  final _name = TextEditingController(),
      _cpf = TextEditingController(),
      _registration = TextEditingController();
  String? _professional;
  late String _occupation;
  bool _busy = false;
  String? _error, _notice;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
    _occupation = widget.defaultOccupation;
  }

  @override
  void dispose() {
    _name.dispose();
    _cpf.dispose();
    _registration.dispose();
    super.dispose();
  }

  void _select(String? key, ReceitaSaudeData data) {
    if (key == null) return;
    final first = data.rows.firstWhere((r) => r.professionalKey == key);
    final profile = data.professionals[first.professionalId] ?? {};
    setState(() {
      _professional = key;
      _name.text = first.professionalName;
      _cpf.text = '${profile['cpf'] ?? ''}';
      _registration.text = '${profile['professionalRegister'] ?? ''}';
      _error = null;
    });
  }

  Future<void> _export(List<ReceitaSaudeLine> rows, bool pdf) async {
    if (_busy) return;
    final chosen = rows.where((r) => r.selected).toList();
    if (chosen.isEmpty) {
      setState(() => _error = 'Selecione ao menos um pagamento.');
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do profissional prestador.');
      return;
    }
    if (!pdf) {
      try {
        receitaSaudeCsv(
          month: widget.month,
          rows: chosen,
          professionalCpf: _cpf.text,
          occupation: _occupation,
          registration: _registration.text,
        );
      } catch (e) {
        setState(
          () => _error =
              'Confira o CPF do profissional e as pendências dos pagamentos. O CSV exige até 1.000 linhas válidas.',
        );
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onExport(
        ReceitaSaudeExport(
          rows: chosen,
          professionalName: _name.text.trim(),
          professionalCpf: _cpf.text,
          registration: _registration.text.trim(),
          occupation: _occupation,
          pdf: pdf,
        ),
      );
      if (mounted) {
        setState(
          () => _notice = pdf
              ? 'Relatório de apoio gerado.'
              : 'CSV gerado. Importe na Escrituração do Carnê-Leão Web e confira recibos já emitidos antes de importar novamente.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível gerar o arquivo. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ClinicalCareStyle.forContext(context),
    child: PopScope(
      canPop: !_busy,
      child: Dialog(
        child: SizedBox(
          width: 960,
          height: MediaQuery.sizeOf(context).height * .88,
          child: FutureBuilder<ReceitaSaudeData>(
            future: _future,
            builder: (context, snap) {
              final data = snap.data;
              final groups = <String, String>{
                if (data != null)
                  for (final r in data.rows)
                    r.professionalKey: r.professionalName.isEmpty
                        ? 'Sem profissional vinculado — identificar manualmente'
                        : r.professionalName,
              };
              final rows =
                  data?.rows
                      .where((r) => r.professionalKey == _professional)
                      .toList() ??
                  <ReceitaSaudeLine>[];
              final pending = rows
                  .where((r) => r.selected && r.issues(widget.month).isNotEmpty)
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Receita Saúde',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: _busy,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${widget.clinicName} • ${reportMonthLabel(widget.month)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Conferência dos pagamentos por profissional pessoa física. O PDF é um relatório de apoio; o CSV prepara a emissão em lote no Carnê-Leão Web. A emissão oficial exige acesso gov.br do profissional ou representante.',
                              style: TextStyle(fontSize: 12),
                            ),
                            TextButton.icon(
                              onPressed: () => launchUrl(
                                Uri.parse(
                                  'https://www.gov.br/receitafederal/pt-br/assuntos/meu-imposto-de-renda/pagamento/carne-leao/manual',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text(
                                'Orientações da Receita Federal',
                              ),
                            ),
                            if (snap.connectionState == ConnectionState.waiting)
                              const LinearProgressIndicator()
                            else if (snap.hasError) ...[
                              const Text(
                                'Não foi possível carregar os pagamentos e cadastros desta unidade. Nenhum arquivo foi gerado.',
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _future = widget.load();
                                }),
                                child: const Text('Tentar novamente'),
                              ),
                            ] else if (data!.rows.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Nenhum pagamento recebido encontrado no mês selecionado.',
                                ),
                              )
                            else ...[
                              DropdownButtonFormField<String>(
                                key: const ValueKey('receita-professional'),
                                initialValue: _professional,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Profissional prestador *',
                                ),
                                items: [
                                  for (final g in groups.entries)
                                    DropdownMenuItem(
                                      value: g.key,
                                      child: Text(
                                        g.value,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => _select(v, data),
                              ),
                              if (_professional != null) ...[
                                const SizedBox(height: 14),
                                TextField(
                                  key: const ValueKey(
                                    'receita-professional-name',
                                  ),
                                  controller: _name,
                                  readOnly: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome do profissional *',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: 250,
                                      child: TextField(
                                        key: const ValueKey(
                                          'receita-professional-cpf',
                                        ),
                                        controller: _cpf,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'CPF do profissional *',
                                          errorText:
                                              _cpf.text.isEmpty ||
                                                  PatientRegistrationDraft.validCpf(
                                                    _cpf.text,
                                                  )
                                              ? null
                                              : 'CPF inválido',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 300,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _occupation,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Ocupação no Carnê-Leão *',
                                        ),
                                        items: [
                                          for (final entry
                                              in receitaOccupations.entries)
                                            DropdownMenuItem(
                                              value: entry.key,
                                              child: Text(
                                                '${entry.key} – ${entry.value}',
                                              ),
                                            ),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => _occupation = v!),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 250,
                                      child: TextField(
                                        controller: _registration,
                                        maxLength: 15,
                                        decoration: const InputDecoration(
                                          labelText: 'Registro no conselho',
                                          helperText:
                                              'Pode ficar vazio se houver um único registro ativo.',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Informe quem efetivamente pagou cada serviço. O CPF do paciente não é assumido como CPF do pagador. Correções nesta conferência valem somente para o arquivo exportado.',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${rows.where((r) => r.selected).length} pagamento(s) selecionado(s) • $pending com pendências • ${reportMoney(rows.where((r) => r.selected).fold<double>(0, (sum, r) => sum + r.amount))}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (final row in rows)
                                  _ReceitaLineEditor(
                                    key: ValueKey('receita-line-${row.id}'),
                                    row: row,
                                    month: widget.month,
                                    onChanged: () => setState(() {}),
                                  ),
                              ],
                            ],
                            if (_notice != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _notice!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Fechar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy || rows.isEmpty
                              ? null
                              : () => _export(rows, true),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text('Relatório PDF'),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('receita-export-csv'),
                          onPressed: _busy || rows.isEmpty
                              ? null
                              : () => _export(rows, false),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(
                            _busy ? 'Gerando…' : 'CSV para Carnê-Leão',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ReceitaLineEditor extends StatefulWidget {
  const _ReceitaLineEditor({
    super.key,
    required this.row,
    required this.month,
    required this.onChanged,
  });
  final ReceitaSaudeLine row;
  final DateTime month;
  final VoidCallback onChanged;
  @override
  State<_ReceitaLineEditor> createState() => _ReceitaLineEditorState();
}

class _ReceitaLineEditorState extends State<_ReceitaLineEditor> {
  late final TextEditingController _beneficiary, _payer;
  bool _same = false;
  @override
  void initState() {
    super.initState();
    _beneficiary = TextEditingController(text: widget.row.beneficiaryCpf);
    _payer = TextEditingController(text: widget.row.payerCpf);
  }

  @override
  void dispose() {
    _beneficiary.dispose();
    _payer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final issues = row.issues(widget.month);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: row.selected,
              onChanged: (v) {
                row.selected = v!;
                widget.onChanged();
              },
              title: Text(
                '${row.patientName} • ${reportMoney(row.amount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                row.description,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 250,
                  child: TextField(
                    key: ValueKey('beneficiary-${row.id}'),
                    controller: _beneficiary,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'CPF do beneficiário *',
                    ),
                    onChanged: (v) {
                      row.beneficiaryCpf = v;
                      if (_same) {
                        row.payerCpf = v;
                        _payer.text = v;
                      }
                      widget.onChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    key: ValueKey('payer-${row.id}'),
                    controller: _payer,
                    readOnly: _same,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'CPF do pagador *',
                    ),
                    onChanged: (v) {
                      row.payerCpf = v;
                      widget.onChanged();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final first = DateTime(
                      widget.month.year,
                      widget.month.month,
                    );
                    final last = DateTime(
                      widget.month.year,
                      widget.month.month + 1,
                      0,
                    );
                    final d = await showDatePicker(
                      context: context,
                      initialDate:
                          row.paymentDate != null &&
                              !DateUtils.dateOnly(
                                row.paymentDate!,
                              ).isBefore(first) &&
                              !DateUtils.dateOnly(
                                row.paymentDate!,
                              ).isAfter(last)
                          ? DateUtils.dateOnly(row.paymentDate!)
                          : first,
                      firstDate: first,
                      lastDate: last,
                    );
                    if (d != null && mounted) {
                      row.paymentDate = d;
                      widget.onChanged();
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(
                    row.paymentDate == null
                        ? 'Informar data do pagamento'
                        : formatDateFull(row.paymentDate!),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _same,
              onChanged: (v) {
                setState(() => _same = v!);
                if (_same) {
                  row.payerCpf = row.beneficiaryCpf;
                  _payer.text = row.payerCpf;
                }
                widget.onChanged();
              },
              title: const Text(
                'Pagador é o próprio beneficiário',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (row.selected && issues.isNotEmpty)
              Text(
                issues.join(' • '),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
