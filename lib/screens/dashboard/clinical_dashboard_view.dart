import 'package:flutter/material.dart';
import '../../utils/display.dart' show formatDateShort;
import '../../utils/report_export.dart' show reportMoney;

/// Presentation only: all figures come from clinic-scoped live streams.
class ClinicalDashboardView extends StatelessWidget {
  const ClinicalDashboardView({super.key, required this.monthLabel,
    required this.toReceive, required this.overdue, required this.overdueCount,
    required this.todayCount, required this.oldOverdueCount,
    required this.unconfirmedCount, required this.debtorsTodayCount,
    required this.upcoming, required this.birthdays, required this.now,
    this.onNavigate, this.onNewAppointment});
  final VoidCallback? onNewAppointment;
  final String monthLabel;
  final double toReceive, overdue;
  final int overdueCount, todayCount, oldOverdueCount, unconfirmedCount, debtorsTodayCount;
  final List<Map<String, dynamic>> upcoming, birthdays;
  final DateTime now;
  final ValueChanged<int>? onNavigate;
  static const green = Color(0xff10d6aa), cyan = Color(0xff22d3ee), red = Color(0xfffb7185), purple = Color(0xffc084fc);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xff0c1017) : const Color(0xfff4f7fb);
    final surface = dark ? const Color(0xff161e2b) : Colors.white;
    final border = dark ? const Color(0xff26364a) : const Color(0xffdce4ef);
    final muted = dark ? const Color(0xff94a3b8) : const Color(0xff596b80);
    Color ink(Color color) => dark ? color : Color.lerp(color, Colors.black, .4)!;
    Widget badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: .3))),
      child: Text(label, style: TextStyle(color: ink(color), fontSize: 11, fontWeight: FontWeight.w700)));
    Widget action(String text, int target, {Color color = cyan}) => TextButton(
      onPressed: onNavigate == null ? null : () => onNavigate!(target),
      child: Text(text, style: TextStyle(color: ink(color))));
    Widget panel(Widget child, {Color? outline, EdgeInsets padding = const EdgeInsets.all(20)}) => Container(
      width: double.infinity, padding: padding,
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: outline ?? border)), child: child);
    Widget iconBox(IconData icon, Color color) => Container(
      padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .25))),
      child: Icon(icon, color: ink(color), size: 24));
    Widget metric(String label, String value, String caption, String tag, IconData icon, Color color, String footer, String link, int target) => panel(Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [iconBox(icon, color), const Spacer(), badge(tag, color)]),
        const SizedBox(height: 20),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 28, color: label == 'Inadimplência' ? ink(red) : null))),
        const SizedBox(height: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4), Text(caption, style: TextStyle(color: label == 'Inadimplência' ? ink(red) : muted, fontSize: 13)),
        const Spacer(), Divider(color: border, height: 24),
        Row(children: [Expanded(child: Text(footer, style: TextStyle(color: muted, fontSize: 12))), action(link, target, color: color)]),
      ]));
    Widget exception(IconData icon, String title, String subtitle, int target, String link) => panel(
      LayoutBuilder(builder: (context, size) {
        final description = Row(children: [iconBox(icon, red), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), Text(subtitle, style: TextStyle(color: muted, fontSize: 13))]))]);
        final buttons = Wrap(spacing: 8, children: [action('Disparar lembretes', target), action(link, target)]);
        return size.maxWidth < 650 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [description, buttons]) : Row(children: [Expanded(child: description), buttons]);
      }), outline: red.withValues(alpha: .35));
    Widget dueList() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [Icon(Icons.schedule, size: 20, color: ink(cyan)), const Text('Próximos vencimentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text('${upcoming.length} títulos exibidos', style: TextStyle(color: muted, fontSize: 12)), action('Ver em Cobranças  ›', 7)]),
      const SizedBox(height: 10), panel(upcoming.isEmpty ? Padding(padding: const EdgeInsets.all(24), child: Text('Nenhuma conta pendente. Tudo em dia!', style: TextStyle(color: muted))) : Column(children: [
        for (var i = 0; i < upcoming.length; i++) ...[
          if (i > 0) Divider(height: 1, color: border),
          Builder(builder: (context) {
            final row = upcoming[i]; final due = row['due'] as DateTime?;
            final late = due != null && due.isBefore(DateTime(now.year, now.month, now.day));
            final color = late ? red : green;
            return InkWell(onTap: onNavigate == null ? null : () => onNavigate!(7), child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: LayoutBuilder(builder: (context, size) {
                final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${row['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), Text('${row['title']}${due == null ? ' • Sem vencimento' : ' • Vence ${formatDateShort(due)}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 13))]);
                final amount = Text(reportMoney((row['amount'] as num).toDouble()), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700));
                return size.maxWidth < 530 ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 10), Row(children: [badge(late ? 'ATRASADO' : due == null ? 'SEM DATA' : 'A VENCER', color), const Spacer(), amount])]) : Row(children: [Icon(Icons.circle, size: 12, color: ink(color)), const SizedBox(width: 14), Expanded(child: text), const SizedBox(width: 10), badge(late ? 'ATRASADO' : due == null ? 'SEM DATA' : 'A VENCER', color), const SizedBox(width: 22), amount, const SizedBox(width: 16), Icon(Icons.chat_bubble_outline, size: 19, color: muted)]);
              })));
          }),
        ]
      ]), padding: EdgeInsets.zero),
    ]);
    Widget side() => Column(children: [
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.monitor_heart_outlined, color: ink(green), size: 20), const SizedBox(width: 8), const Expanded(child: Text('STATUS DA UNIDADE', style: TextStyle(fontWeight: FontWeight.w700)))]),
        const SizedBox(height: 24), Text('Ocupação não disponível', style: TextStyle(color: muted)),
        const SizedBox(height: 10), Text('O sistema não registra a ocupação de consultórios nem o plantão dos profissionais em tempo real.', style: TextStyle(color: muted, fontSize: 13, height: 1.6)),
        Divider(color: border, height: 32), action('Consultar agenda', 1, color: green),
      ])), const SizedBox(height: 28),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.cake_outlined, color: ink(purple), size: 20), const SizedBox(width: 8), const Expanded(child: Text('ANIVERSARIANTES DO MÊS', style: TextStyle(fontWeight: FontWeight.w700)))]),
        action('Ver em Pacientes', 2, color: purple), const SizedBox(height: 12),
        if (birthdays.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30), decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(16)), child: Column(children: [iconBox(Icons.celebration_outlined, purple), const SizedBox(height: 16), const Text('Nenhum aniversariante para este período', textAlign: TextAlign.center), const SizedBox(height: 12), Text('As datas cadastradas dos pacientes aparecem aqui no mês do aniversário.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.6, fontSize: 13))])),
        for (final person in birthdays) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.cake_outlined, color: ink(purple)), title: Text('${person['name']}'), subtitle: Text('Dia ${person['day']}'), onTap: onNavigate == null ? null : () => onNavigate!(2)),
      ])),
    ]);
    return ColoredBox(color: base, child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: LayoutBuilder(builder: (context, size) {
      final columns = size.maxWidth >= 1000 ? 4 : size.maxWidth >= 520 ? 2 : 1;
      final cards = [
        metric('A receber', reportMoney(toReceive), 'fluxo projetado neste mês', 'PREVISTO', Icons.trending_up, cyan, 'Saldo pendente do mês', 'Detalhes', 5),
        metric('Inadimplência', reportMoney(overdue), '$overdueCount títulos em atraso', 'ATENÇÃO', Icons.warning_amber_rounded, red, 'Saldo vencido', 'Cobranças', 7),
        metric('Hoje', '$todayCount', 'agendamentos confirmados', 'HOJE', Icons.event_available_outlined, green, '$unconfirmedCount sem confirmação', 'Ver Agenda', 1),
        metric('Aniversariantes', '${birthdays.length}', 'no mês atual', 'FIDELIZAÇÃO', Icons.cake_outlined, purple, 'Cadastro dos pacientes', 'Pacientes', 2),
      ];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), badge(monthLabel, green), FilledButton.icon(onPressed: onNewAppointment, icon: const Icon(Icons.add), label: const Text('Novo agendamento'))]),
        const SizedBox(height: 28), Wrap(spacing: 20, runSpacing: 20, children: cards.map((card) => SizedBox(width: (size.maxWidth - (columns - 1) * 20) / columns, height: columns == 4 ? 270 : 290, child: card)).toList()),
        const SizedBox(height: 30),
        if (oldOverdueCount > 0 || unconfirmedCount > 0 || debtorsTodayCount > 0) ...[
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [Icon(Icons.error_outline, size: 20, color: ink(red)), Text('Exceções de hoje', style: TextStyle(color: ink(red), fontWeight: FontWeight.w700, fontSize: 16)), Text('• Ações clínicas prioritárias', style: TextStyle(color: muted))]), const SizedBox(height: 16),
          if (oldOverdueCount > 0) exception(Icons.more_time, '$oldOverdueCount conta(s) vencida(s) há 7+ dias', 'Revise a régua de cobrança e os lembretes pendentes', 7, 'Cobranças'),
          if (unconfirmedCount > 0) Padding(padding: const EdgeInsets.only(top: 10), child: exception(Icons.event_busy, '$unconfirmedCount agendamento(s) sem confirmação', 'Revise os agendamentos de hoje', 1, 'Agenda')),
          if (debtorsTodayCount > 0) Padding(padding: const EdgeInsets.only(top: 10), child: exception(Icons.warning_amber, '$debtorsTodayCount agendamento(s) com débito vencido', 'Pacientes confirmados para hoje', 7, 'Cobranças')),
          const SizedBox(height: 28),
        ],
        if (size.maxWidth >= 950) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: dueList()), const SizedBox(width: 28), SizedBox(width: 340, child: side())]) else ...[dueList(), const SizedBox(height: 28), side()],
      ]);
    })));
  }
}
