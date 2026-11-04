import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/appointment_model.dart';
import '../../ui/app_theme.dart';

/// Branch de avaliação: desligue com --dart-define=AGENDA_CLINICAL_DARK=false.
const clinicalAgendaEnabled = bool.fromEnvironment(
  'AGENDA_CLINICAL_DARK',
  defaultValue: true,
);

abstract final class ClinicalAgendaStyle {
  static bool get isDark => AppColors.isDark;
  static Color tone(Color dark, Color light) => isDark ? dark : light;
  static Color get background =>
      tone(const Color(0xFF10141A), const Color(0xFFF3F6FA));
  static Color get surface => tone(const Color(0xFF181C22), Colors.white);
  static Color get elevated =>
      tone(const Color(0xFF262A31), const Color(0xFFE8EDF4));
  static Color get text =>
      tone(const Color(0xFFDFE2EB), const Color(0xFF202936));
  static Color get muted =>
      tone(const Color(0xFF9AA4B5), const Color(0xFF536276));
  static Color get teal =>
      tone(const Color(0xFF02C49F), const Color(0xFF007E69));
  static Color get blue =>
      tone(const Color(0xFFADC6FF), const Color(0xFF294F9A));
  static Color get accent =>
      tone(const Color(0xFF3DDBB7), const Color(0xFF007E69));
  static Color get warning =>
      tone(const Color(0xFFFFC400), const Color(0xFF875800));
  static Color get danger =>
      tone(const Color(0xFFFFB4AB), const Color(0xFFB3261E));
  static Color get onAccent => isDark ? const Color(0xFF00382C) : Colors.white;
  static Color get onBlue => isDark ? const Color(0xFF002E6A) : Colors.white;
  static Color get selected =>
      tone(const Color(0xFF17443E), const Color(0xFFD9F2E9));

  /// Register an inherited theme dependency so live switching keeps existing State.
  static ThemeData forContext(BuildContext context) {
    Theme.of(context);
    return theme;
  }

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: isDark
        ? ColorScheme.dark(primary: blue, secondary: teal, surface: surface)
        : ColorScheme.fromSeed(
            seedColor: blue,
            brightness: isDark ? Brightness.dark : Brightness.light,
            primary: blue,
            secondary: teal,
            surface: surface,
          ),
    textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
      fontFamily: 'PlusJakartaSans',
      bodyColor: text,
      displayColor: text,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
  );
}

/// Apresentação sem Firebase. Recebe a mesma lista filtrada e ações da agenda.
class ClinicalAgendaView extends StatefulWidget {
  const ClinicalAgendaView({
    super.key,
    required this.weekStart,
    required this.appointments,
    required this.professionalSelector,
    required this.onChangeWeek,
    required this.onToday,
    required this.onEmptySlot,
    required this.onAppointment,
    this.loading = false,
    this.onSelectedDay,
    this.error,
  });
  final DateTime weekStart;
  final List<AppointmentModel> appointments;
  final Widget professionalSelector;
  final ValueChanged<int> onChangeWeek;
  final VoidCallback onToday;
  final void Function(DateTime, String) onEmptySlot;
  final ValueChanged<AppointmentModel> onAppointment;
  final bool loading;
  final ValueChanged<DateTime>? onSelectedDay;
  final String? error;
  @override
  State<ClinicalAgendaView> createState() => _ClinicalAgendaViewState();
}

class _ClinicalAgendaViewState extends State<ClinicalAgendaView> {
  late int _day;
  bool _daily = false;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  int get _visibleDays => widget.appointments.any((a) => a.date.weekday == DateTime.sunday) ? 7 : 6;
  static const _names = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  static const _startMinute = 510;
  static const _endMinute = 1230;
  @override
  void initState() {
    super.initState();
    _day = DateTime.now().weekday - 1;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  DateTime _dayDate(int i) => widget.weekStart.add(Duration(days: i));
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  List<AppointmentModel> _events(int day) =>
      widget.appointments.where((a) => _sameDay(a.date, _dayDate(day))).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  bool _matches(AppointmentModel a) => '${a.patientName} ${a.procedure}'.toLowerCase().contains(_search.toLowerCase().trim());
  bool _blocked(AppointmentModel a) =>
      a.status == 'Bloqueado' || a.patientId == 'BLOCKED_SLOT';
  int _minute(AppointmentModel a) => a.date.hour * 60 + a.date.minute;
  Color _color(AppointmentModel a) {
    if (_blocked(a) || a.isDone) return ClinicalAgendaStyle.muted;
    if (a.isCancelled || a.isMissed) return ClinicalAgendaStyle.danger;
    if (a.status.toLowerCase() == 'remarcar') {
      return ClinicalAgendaStyle.warning;
    }
    return a.status == 'Confirmado'
        ? ClinicalAgendaStyle.teal
        : ClinicalAgendaStyle.blue;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Breakpoint considera a janela toda; a sidebar já ocupa parte do desktop.
      final mobile = MediaQuery.sizeOf(context).width < 768;
      final daily = mobile || _daily;
      final end = widget.weekStart.add(const Duration(days: 6));
      final weekNavigation = Row(children: [
        IconButton(visualDensity: VisualDensity.compact, tooltip: 'Semana anterior', onPressed: () => widget.onChangeWeek(-7), icon: const Icon(Icons.chevron_left)),
        Icon(Icons.calendar_today_outlined, color: ClinicalAgendaStyle.teal, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text('${_date(widget.weekStart)} — ${_date(end)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        IconButton(visualDensity: VisualDensity.compact, tooltip: 'Próxima semana', onPressed: () => widget.onChangeWeek(7), icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () { setState(() => _day = DateTime.now().weekday - 1); widget.onToday(); }, child: const Text('Hoje')),
      ]);
      final modes = Row(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<bool>(
          style: SegmentedButton.styleFrom(selectedBackgroundColor: ClinicalAgendaStyle.teal, selectedForegroundColor: ClinicalAgendaStyle.onAccent, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), visualDensity: VisualDensity.compact),
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: true, label: Text('Dia')), ButtonSegment(value: false, label: Text('Semana'))],
          selected: {daily}, onSelectionChanged: (v) => setState(() => _daily = v.first),
        ),
        TextButton(onPressed: () async {
          final selected = await showDatePicker(context: context, initialDate: _dayDate(_day), firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'Escolher data da agenda');
          if (selected == null || !mounted) return;
          final monday = selected.subtract(Duration(days: selected.weekday - 1));
          final offset = DateTime.utc(monday.year, monday.month, monday.day).difference(DateTime.utc(widget.weekStart.year, widget.weekStart.month, widget.weekStart.day)).inDays;
          setState(() { _day = selected.weekday - 1; _daily = true; });
          widget.onChangeWeek(offset);
          widget.onSelectedDay?.call(selected);
        }, child: const Text('Mês')),
      ]);
      final search = TextField(controller: _searchController, onChanged: (v) => setState(() => _search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Buscar paciente ou procedimento…', isDense: true));
      return Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 10 : 16, 4, mobile ? 10 : 16, 0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: ClinicalAgendaStyle.surface, borderRadius: BorderRadius.circular(18)),
              child: constraints.maxWidth >= 1000
                ? Row(children: [modes, const SizedBox(width: 16), Expanded(child: widget.professionalSelector), const SizedBox(width: 20), SizedBox(width: 290, child: weekNavigation), const SizedBox(width: 12), SizedBox(width: 200, child: search)])
                : Column(children: [
                    Row(children: [Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: modes))]),
                    const SizedBox(height: 8),
                    widget.professionalSelector,
                    weekNavigation,
                    search,
                  ]),
            ),
            const SizedBox(height: 6),
            if (daily) ...[
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => Semantics(
                    selected: _day == i,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => _day = i);
                        widget.onSelectedDay?.call(_dayDate(i));
                      },
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: _day == i
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF4338CA),
                                  ],
                                )
                              : null,
                          color: _day == i ? null : ClinicalAgendaStyle.surface,
                          border: Border.all(
                            color: _day == i
                                ? ClinicalAgendaStyle.blue
                                : ClinicalAgendaStyle.elevated,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _names[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: _day == i
                                    ? Colors.white
                                    : ClinicalAgendaStyle.text,
                              ),
                            ),
                            Text(
                              '${_dayDate(i).day}',
                              style: TextStyle(
                                color: _day == i
                                    ? Colors.white
                                    : ClinicalAgendaStyle.text,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_events(
                              i,
                            ).any((a) => !_blocked(a) && !a.isCancelled))
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: ClinicalAgendaStyle.teal,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      color: ClinicalAgendaStyle.teal,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.loading
                            ? 'Carregando agenda…'
                            : mobile && _search.trim().isNotEmpty
                                ? '${widget.appointments.where((a) => !_blocked(a) && _matches(a)).length} resultados nesta semana'
                                : '${_events(_day).where((a) => !_blocked(a) && !a.isCancelled).length} agendamentos no dia',
                        style: TextStyle(color: ClinicalAgendaStyle.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: widget.error != null
                  ? Center(child: Text(widget.error!))
                  : widget.loading
                  ? const Center(child: CircularProgressIndicator())
                  : mobile && _search.trim().isNotEmpty
                  ? _mobileSearchResults()
                  : daily
                  ? _dailyList()
                  : _weeklyGrid(),
            ),
          ],
        ),
      );
    },
  );

  Widget _card(AppointmentModel a, {bool compact = false, VoidCallback? onTap}) {
    final color = _color(a);
    final end = _minute(a) + a.durationMinutes;
    return Semantics(
      button: true,
      label: '${a.patientName}, ${_time(_minute(a))}, ${a.status}',
      child: Material(
        color: compact
            ? ClinicalAgendaStyle.elevated.withValues(alpha: .45)
            : ClinicalAgendaStyle.elevated,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => widget.onAppointment(a),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 14, vertical: compact ? 2 : 14),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _blocked(a) ? 'Bloqueado' : a.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        _blocked(a) ? (a.notes ?? a.procedure) : a.procedure,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, height: 1.1, color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _blocked(a)
                            ? 'HORÁRIO BLOQUEADO'
                            : a.procedure.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _blocked(a) ? (a.notes ?? a.procedure) : a.patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            '${_time(_minute(a))} – ${_time(end)}',
                            style: TextStyle(color: ClinicalAgendaStyle.muted),
                          ),
                          Text(
                            a.status,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Busca na semana que a agenda já carregou, sem novas consultas ao Firebase.
  Widget _mobileSearchResults() {
    final matches = widget.appointments
        .where((a) => !_blocked(a) && _matches(a))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, color: ClinicalAgendaStyle.muted, size: 40),
              const SizedBox(height: 12),
              const Text('Nenhum agendamento encontrado nesta semana.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Confira o termo ou selecione outra semana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ClinicalAgendaStyle.muted)),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: ValueKey('agenda-mobile-search-${_search.trim().toLowerCase()}'),
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            matches.length == 1
                ? '1 agendamento encontrado nesta semana'
                : '${matches.length} agendamentos encontrados nesta semana',
            style: TextStyle(color: ClinicalAgendaStyle.muted),
          ),
        ),
        for (final a in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${_names[a.date.weekday - 1]} ${_date(a.date)}',
                      style: TextStyle(color: ClinicalAgendaStyle.teal,
                          fontWeight: FontWeight.w600)),
                ),
                _card(a, onTap: () {
                  FocusScope.of(context).unfocus();
                  _searchController.clear();
                  setState(() {
                    _search = '';
                    _day = a.date.weekday - 1;
                  });
                  widget.onSelectedDay?.call(_dayDate(_day));
                  widget.onAppointment(a);
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dailyList() {
    final events = _events(_day);
    final rows = <Widget>[];
    for (var minute = _startMinute; minute < _endMinute; minute += 30) {
      final starts = events
          .where((a) => _matches(a) && _minute(a) >= minute && _minute(a) < minute + 30)
          .toList();
      final occupied = events.any(
        (a) =>
            !a.isCancelled &&
            _minute(a) < minute + 30 &&
            _minute(a) + a.durationMinutes > minute,
      );
      // Search filters appointment cards, never the actual free intervals.
      if (starts.isEmpty && occupied) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _time(minute),
                    style: TextStyle(
                      fontSize: 12,
                      color: starts.isEmpty
                          ? ClinicalAgendaStyle.muted
                          : ClinicalAgendaStyle.teal,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: starts.isEmpty
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: ClinicalAgendaStyle.muted,
                          side: BorderSide(color: ClinicalAgendaStyle.elevated),
                        ),
                        onPressed: () =>
                            widget.onEmptySlot(_dayDate(_day), _time(minute)),
                        child: const Text('+ Disponível'),
                      )
                    : Column(
                        children: [
                          for (final a in starts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _card(a),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }
    // Dados fora da janela usual continuam acessíveis, sem serem ocultados.
    final outside = events.where(
      (a) => _minute(a) < _startMinute || _minute(a) >= _endMinute,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        for (final a in outside)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(a)),
        ...rows,
      ],
    );
  }

  Widget _weeklyGrid() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final col = (width - 64) / _visibleDays;
      // Fit 08:30 through 15:00 (14 half-hour rows), spending space on
      // appointment rows rather than headers. Short screens retain scrolling.
      final rowHeight = ((constraints.maxHeight - 44) / 14).clamp(36.0, 44.0).toDouble();
      // A janela se expande para preservar eventos fora do expediente padrão.
      final start = widget.appointments.fold<int>(
        _startMinute,
        (v, a) => math.min(v, (_minute(a) ~/ 30) * 30),
      );
      final end = widget.appointments.fold<int>(
        _endMinute,
        (v, a) =>
            math.max(v, ((_minute(a) + a.durationMinutes + 29) ~/ 30) * 30),
      );
      final slots = (end - start) ~/ 30;
      return Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: ClinicalAgendaStyle.elevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Icon(Icons.schedule, color: ClinicalAgendaStyle.muted),
                ),
                for (var i = 0; i < _visibleDays; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _day = i;
                        _daily = true;
                        widget.onSelectedDay?.call(_dayDate(i));
                      }),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _names[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: _sameDay(_dayDate(i), DateTime.now())
                                  ? ClinicalAgendaStyle.teal
                                  : ClinicalAgendaStyle.muted,
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _sameDay(_dayDate(i), DateTime.now())
                                  ? ClinicalAgendaStyle.teal
                                  : null,
                            ),
                            child: Text(
                              '${_dayDate(i).day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _sameDay(_dayDate(i), DateTime.now())
                                    ? ClinicalAgendaStyle.onAccent
                                    : ClinicalAgendaStyle.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: SizedBox(
                height: slots * rowHeight,
                child: Stack(
                  children: [
                    for (var s = 0; s < slots; s++)
                      Positioned(
                        top: s * rowHeight,
                        left: 0,
                        right: 0,
                        height: rowHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ClinicalAgendaStyle.surface.withValues(
                              alpha: .6,
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: ClinicalAgendaStyle.elevated,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 64,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _time(start + s * 30),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ClinicalAgendaStyle.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              for (var d = 0; d < _visibleDays; d++)
                                Expanded(
                                  child: InkWell(
                                    onTap: _search.trim().isNotEmpty ? null : () => widget.onEmptySlot(
                                      _dayDate(d),
                                      _time(start + s * 30),
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    for (var d = 0; d < _visibleDays; d++)
                      ..._positionedEvents(d, start, col, rowHeight),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  List<Widget> _positionedEvents(int day, int start, double col, double rowHeight) {
    final events = _events(day).where(_matches).toList();
    // Cada componente de sobreposição usa faixas estáveis; encaixes não se cobrem.
    final result = <Widget>[];
    var index = 0;
    while (index < events.length) {
      final group = <AppointmentModel>[events[index++]];
      var groupEnd = _minute(group.first) + group.first.durationMinutes;
      while (index < events.length && _minute(events[index]) < groupEnd) {
        final a = events[index++];
        group.add(a);
        groupEnd = math.max(groupEnd, _minute(a) + a.durationMinutes);
      }
      for (var lane = 0; lane < group.length; lane++) {
        final a = group[lane];
        result.add(
          Positioned(
            top: (_minute(a) - start) / 30 * rowHeight + 2,
            left: 64 + day * col + lane * col / group.length + 2,
            width: math.max(1, col / group.length - 4),
            height: math.max(28, a.durationMinutes / 30 * rowHeight - 4),
            child: Tooltip(
              message:
                  '${a.patientName}\n${a.procedure}\n${a.status}\n${_time(_minute(a))}',
              child: _card(a, compact: true),
            ),
          ),
        );
      }
    }
    return result;
  }
}
