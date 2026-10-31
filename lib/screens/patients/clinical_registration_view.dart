import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/patient_registration.dart';
import '../agenda/clinical_agenda_view.dart';
import 'clinical_patient_view.dart';

class ClinicalRegistrationView extends StatelessWidget {
  const ClinicalRegistrationView({
    super.key,
    required this.controllers,
    required this.formKey,
    required this.editing,
    required this.saving,
    required this.lookingUpCep,
    required this.channels,
    required this.onEdit,
    required this.onSave,
    required this.onLookupCep,
    required this.onWhatsApp,
    required this.onChanged,
    required this.onChannel,
    required this.portal,
    required this.consentSummary,
    this.onOpenConsent,
    this.inputFormatters = const {},
  });
  final Map<String, TextEditingController> controllers;
  final GlobalKey<FormState> formKey;
  final Map<String, List<TextInputFormatter>> inputFormatters;
  final bool editing, saving, lookingUpCep;
  final Set<String> channels;
  final VoidCallback onEdit, onSave, onLookupCep, onWhatsApp, onChanged;
  final ValueChanged<String> onChannel;
  final Widget portal;
  final String consentSummary;
  final VoidCallback? onOpenConsent;
  static Color get _muted => ClinicalAgendaStyle.muted;
  static Color get _input => ClinicalAgendaStyle.tone(
    const Color(0xFF1C2026),
    ClinicalAgendaStyle.elevated,
  );
  Widget field(
    String key,
    String label,
    IconData? icon, {
    bool required = false,
    TextInputType? keyboard,
    Widget? action,
    Widget? suffix,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      SizedBox(
        height:
            {
              'socialName',
              'profession',
              'phone',
              'email',
              'birthDate',
              'cns',
              'emergencyRelationship',
              'emergencyPhone',
            }.contains(key)
            ? 20
            : 12,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '$label${required ? ' *' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ClinicalAgendaStyle.text,
                  fontSize: 9,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (action != null) action,
          ],
        ),
      ),
      const SizedBox(height: 3),
      TextFormField(
        key: ValueKey('registration-$key'),
        controller: controllers[key],
        readOnly: !editing || saving,
        keyboardType: keyboard,
        inputFormatters: inputFormatters[key],
        style: TextStyle(fontSize: 10, color: ClinicalAgendaStyle.text),
        onChanged: (_) => onChanged(),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null
            : null,
        decoration: InputDecoration(
          isDense: true,
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(maxHeight: 32),
          hintText: 'Não informado',
          hintStyle: TextStyle(fontSize: 11, color: _muted),
          prefixIcon: icon == null ? null : Icon(icon, size: 13, color: _muted),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 26,
            minHeight: 26,
          ),
          filled: true,
          fillColor: _input,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
  Widget rgIdentifier() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 12,
        child: Text(
          'RG / Órgão Emissor',
          style: TextStyle(
            color: ClinicalAgendaStyle.text,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 3),
      Container(
        decoration: BoxDecoration(
          color: _input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 8, right: 5),
              child: Icon(Icons.fingerprint, size: 13, color: _muted),
            ),
            Expanded(
              child: TextFormField(
                key: const ValueKey('registration-rg'),
                controller: controllers['rg'],
                readOnly: !editing || saving,
                onChanged: (_) => onChanged(),
                style: const TextStyle(fontSize: 10),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 7),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 5),
            SizedBox(
              width: 48,
              child: TextFormField(
                key: const ValueKey('registration-rgIssuer'),
                controller: controllers['rgIssuer'],
                readOnly: !editing || saving,
                onChanged: (_) => onChanged(),
                style: const TextStyle(fontSize: 9),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Emissor',
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 3,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget select(
    String key,
    String label,
    IconData icon,
    List<String> choices,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: ClinicalAgendaStyle.text,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      DropdownButtonFormField<String>(
        key: ValueKey('registration-$key-${controllers[key]!.text}'),
        initialValue: controllers[key]!.text.isEmpty
            ? null
            : controllers[key]!.text,
        isExpanded: true,
        iconSize: 14,
        items: [
          for (final c in {
            ...choices,
            if (controllers[key]!.text.isNotEmpty) controllers[key]!.text,
          })
            DropdownMenuItem(
              value: c,
              child: Text(
                c,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
            ),
        ],
        onChanged: !editing || saving
            ? null
            : (v) {
                controllers[key]!.text = v ?? '';
                onChanged();
              },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Não informado',
          prefixIcon: Icon(icon, size: 13, color: _muted),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 26,
            minHeight: 28,
          ),
          filled: true,
          fillColor: _input,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
  Widget pair(Widget left, Widget right) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 180
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              Expanded(child: right),
            ],
          ),
  );
  Widget card(
    String title,
    IconData icon,
    List<Widget> children, {
    String? tag,
    Color? iconColor,
  }) => PatientVisualStyle.panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor ?? PatientVisualStyle.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (tag != null)
              Text(tag, style: TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    ),
    padding: 14,
  );
  @override
  Widget build(BuildContext context) {
    final personal = card('Dados Pessoais', Icons.person_outline, [
      field(
        'name',
        'Nome Completo',
        Icons.account_circle_outlined,
        required: true,
      ),
      pair(
        field(
          'socialName',
          'Nome Social / Como prefere ser chamado',
          Icons.badge_outlined,
        ),
        field('profession', 'Profissão / Ocupação', Icons.work_outline),
      ),
      pair(
        field(
          'phone',
          'Telefone / WhatsApp',
          Icons.phone_outlined,
          keyboard: TextInputType.phone,
          action: Tooltip(
            message: 'Abrir conversa no WhatsApp',
            child: InkWell(
              onTap: controllers['phone']!.text.trim().isEmpty
                  ? null
                  : onWhatsApp,
              child: Text(
                'Chamar no\nWhatsApp',
                style: TextStyle(color: PatientVisualStyle.accent, fontSize: 8),
              ),
            ),
          ),
        ),
        field(
          'email',
          'E-mail Principal',
          Icons.mail_outline,
          keyboard: TextInputType.emailAddress,
        ),
      ),
      pair(
        select('biologicalSex', 'Sexo Biológico', Icons.person_outline, const [
          'Feminino',
          'Masculino',
          'Intersexo',
          'Prefiro não informar',
        ]),
        select('maritalStatus', 'Estado Civil', Icons.favorite_border, const [
          'Solteiro(a)',
          'Casado(a)',
          'União estável',
          'Divorciado(a)',
          'Viúvo(a)',
          'Prefiro não informar',
        ]),
      ),
    ], tag: 'IDENTIFICAÇÃO PRINCIPAL');
    final documentation = card(
      'Documentação & Conformidade',
      Icons.assignment_outlined,
      [
        pair(
          field(
            'cpf',
            'CPF',
            Icons.badge_outlined,
            keyboard: TextInputType.number,
            action: PatientRegistrationDraft.validCpf(controllers['cpf']!.text)
                ? Text(
                    'Válido',
                    style: TextStyle(
                      fontSize: 8,
                      color: PatientVisualStyle.accent,
                    ),
                  )
                : null,
          ),
          rgIdentifier(),
        ),
        pair(
          field(
            'birthDate',
            'Data de Nascimento',
            Icons.calendar_today_outlined,
          ),
          field(
            'cns',
            'Cartão Nacional do SUS (CNS)',
            Icons.credit_card_outlined,
            keyboard: TextInputType.number,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _input,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: PatientVisualStyle.accent,
                    size: 14,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Termo de Tratamento de Dados (LGPD)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                consentSummary,
                style: TextStyle(color: _muted, fontSize: 8),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onOpenConsent,
                      icon: const Icon(Icons.open_in_new, size: 12),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 22),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      label: const Text(
                        'Visualizar Termo em PDF',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Portal do paciente',
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: portal,
                        ),
                      ),
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(22, 22),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.link, size: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      iconColor: ClinicalAgendaStyle.blue,
    );
    final location = card(
      'Localização & Endereço',
      Icons.location_on_outlined,
      [
        field(
          'cep',
          'CEP',
          Icons.pin_drop_outlined,
          keyboard: TextInputType.number,
          suffix: TextButton(
            onPressed: editing && !saving && !lookingUpCep ? onLookupCep : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 22),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              lookingUpCep ? 'Buscando…' : 'Buscar',
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ),
        field('street', 'Logradouro / Avenida', Icons.signpost_outlined),
        pair(
          field('number', 'Número', null),
          field('complement', 'Complemento', null),
        ),
        pair(
          field('neighborhood', 'Bairro', null),
          field('cityState', 'Cidade / UF', null),
        ),
      ],
    );
    final emergency =
        card('Contato de Emergência', Icons.contact_emergency_outlined, [
          field(
            'emergencyName',
            'Nome do Contato',
            Icons.perm_contact_calendar_outlined,
          ),
          pair(
            field(
              'emergencyRelationship',
              'Grau de Parentesco',
              Icons.family_restroom,
            ),
            field(
              'emergencyPhone',
              'Telefone de Emergência',
              Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
          ),
        ], tag: 'Responsável');
    final preferences = card(
      'Preferências de Atendimento',
      Icons.tune,
      [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Canal Preferencial para Lembretes',
              style: TextStyle(color: _muted, fontSize: 9),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in const <(String, IconData)>[
                  ('WhatsApp', Icons.chat_outlined),
                  ('E-mail', Icons.mail_outline),
                  ('SMS', Icons.sms_outlined),
                ])
                  Semantics(
                    button: true,
                    selected: channels.contains(entry.$1),
                    enabled: editing && !saving,
                    child: InkWell(
                      onTap: editing && !saving
                          ? () => onChannel(entry.$1)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: channels.contains(entry.$1)
                              ? ClinicalAgendaStyle.teal
                              : _input,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.$2,
                              size: 11,
                              color: channels.contains(entry.$1)
                                  ? ClinicalAgendaStyle.onAccent
                                  : _muted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              entry.$1,
                              style: TextStyle(
                                fontSize: 9,
                                color: channels.contains(entry.$1)
                                    ? ClinicalAgendaStyle.onAccent
                                    : _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        select(
          'referralSource',
          'Como Conheceu a Clínica?',
          Icons.campaign_outlined,
          const [
            'Indicação de paciente / amigo',
            'Google',
            'Instagram',
            'Facebook',
            'Convênio',
            'Outros',
          ],
        ),
      ],
      iconColor: ClinicalAgendaStyle.blue,
      tag: 'Recepção',
    );
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dados Cadastrais',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Informações pessoais, documentos fiscais/regulatórios e localização para prontuário e emissão de recibos.',
            style: TextStyle(color: _muted, fontSize: 9),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: saving ? null : onEdit,
                icon: Icon(editing ? Icons.close : Icons.edit, size: 13),
                label: Text(
                  editing ? 'Cancelar edição' : 'Editar Dados',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: Icon(
                  saving ? Icons.hourglass_top : Icons.check,
                  size: 14,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: PatientVisualStyle.accent,
                ),
                label: const Text(
                  'Salvar Alterações',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 560
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 59,
                        child: Column(
                          children: [
                            personal,
                            const SizedBox(height: 16),
                            documentation,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 41,
                        child: Column(
                          children: [
                            location,
                            const SizedBox(height: 16),
                            emergency,
                            const SizedBox(height: 16),
                            preferences,
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      personal,
                      const SizedBox(height: 16),
                      documentation,
                      const SizedBox(height: 16),
                      location,
                      const SizedBox(height: 16),
                      emergency,
                      const SizedBox(height: 16),
                      preferences,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
