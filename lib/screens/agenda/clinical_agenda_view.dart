import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/appointment_model.dart';

/// Branch de avaliação: desligue com --dart-define=AGENDA_CLINICAL_DARK=false.
const clinicalAgendaEnabled = bool.fromEnvironment(
  'AGENDA_CLINICAL_DARK',
  defaultValue: true,
);

abstract final class ClinicalAgendaStyle {
  static const background = Color(0xFF10141A);
  static const surface = Color(0xFF181C22);
  static const elevated = Color(0xFF262A31);
  static const text = Color(0xFFDFE2EB);
  static const muted = Color(0xFF9AA4B5);
  static const teal = Color(0xFF02C49F);
  static const blue = Color(0xFFADC6FF);
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: blue,
      secondary: teal,
      surface: surface,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
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
  static const _names = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  static const _rowHeight = 64.0;
  static const _startMinute = 510;
  static const _endMinute = 1230;
  @override
  void initState() {
    super.initState();
    _day = DateTime.now().weekday - 1;
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
  bool _blocked(AppointmentModel a) =>
      a.status == 'Bloqueado' || a.patientId == 'BLOCKED_SLOT';
  int _minute(AppointmentModel a) => a.date.hour * 60 + a.date.minute;
  Color _color(AppointmentModel a) {
    if (_blocked(a) || a.isDone) return ClinicalAgendaStyle.muted;
    if (a.isCancelled || a.isMissed) return const Color(0xFFFFB4AB);
    if (a.status.toLowerCase() == 'remarcar') return const Color(0xFFFBBF24);
    return a.status == 'Confirmado'
        ? ClinicalAgendaStyle.teal
        : ClinicalAgendaStyle.blue;
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ClinicalAgendaStyle.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Breakpoint considera a janela toda; a sidebar já ocupa parte do desktop.
      final mobile = MediaQuery.sizeOf(context).width < 768;
      final daily = mobile || _daily;
      final end = widget.weekStart.add(const Duration(days: 6));
      final now = DateTime.now();
      final currentWeek =
          !now.isBefore(widget.weekStart) &&
          now.isBefore(end.add(const Duration(days: 1)));
      final weekNavigation = Row(
        children: [
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: () => widget.onChangeWeek(-7),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  currentWeek ? 'SEMANA ATUAL' : 'SEMANA',
                  style: const TextStyle(
                    color: ClinicalAgendaStyle.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_date(widget.weekStart)} — ${_date(end)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Próxima semana',
            onPressed: () => widget.onChangeWeek(7),
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(
            onPressed: () {
              setState(() => _day = DateTime.now().weekday - 1);
              widget.onToday();
            },
            child: const Text('Hoje'),
          ),
        ],
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 12 : 24, 12, mobile ? 12 : 24, 0),
        child: Column(
          children: [
            if (!mobile) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ClinicalAgendaStyle.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      color: ClinicalAgendaStyle.teal,
                      size: 7,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        constraints.maxWidth >= 850
                            ? 'MODO DE EXIBIÇÃO    Desktop (${daily ? 'Visualização Diária' : 'Visualização Semanal Completa'})'
                            : 'MODO DE EXIBIÇÃO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ClinicalAgendaStyle.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<bool>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: ClinicalAgendaStyle.teal,
                        selectedForegroundColor: const Color(0xFF00382C),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: true, label: Text('Dia')),
                        ButtonSegment(value: false, label: Text('Semana')),
                      ],
                      selected: {_daily},
                      onSelectionChanged: (v) =>
                          setState(() => _daily = v.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mobile) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ClinicalAgendaStyle.elevated.withValues(
                              alpha: .3,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month_outlined,
                            color: ClinicalAgendaStyle.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          daily ? 'Agenda Diária' : 'Agenda Semanal',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  constraints.maxWidth >= 700
                      ? Row(
                          children: [
                            Expanded(child: widget.professionalSelector),
                            const SizedBox(width: 24),
                            SizedBox(width: 320, child: weekNavigation),
                          ],
                        )
                      : Column(
                          children: [
                            widget.professionalSelector,
                            const SizedBox(height: 8),
                            weekNavigation,
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              '${_dayDate(i).day}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_events(
                              i,
                            ).any((a) => !_blocked(a) && !a.isCancelled))
                              const Icon(
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
                    const Icon(
                      Icons.event_available,
                      color: ClinicalAgendaStyle.teal,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.loading
                            ? 'Carregando agenda…'
                            : '${_events(_day).where((a) => !_blocked(a) && !a.isCancelled).length} agendamentos no dia',
                        style: const TextStyle(
                          color: ClinicalAgendaStyle.muted,
                        ),
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
                  : daily
                  ? _dailyList()
                  : _weeklyGrid(),
            ),
          ],
        ),
      );
    },
  );

  Widget _card(AppointmentModel a, {bool compact = false}) {
    final color = _color(a);
    final end = _minute(a) + a.durationMinutes;
    return Semantics(
      button: true,
      label: '${a.patientName}, ${_time(_minute(a))}, ${a.status}',
      child: Material(
        color: compact ? ClinicalAgendaStyle.surface : const Color(0xFF17283E),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onAppointment(a),
          child: Container(
            padding: EdgeInsets.all(compact ? 8 : 14),
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
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _blocked(a) ? (a.notes ?? a.procedure) : a.procedure,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: color),
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
                            style: const TextStyle(
                              color: ClinicalAgendaStyle.muted,
                            ),
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

  Widget _dailyList() {
    final events = _events(_day);
    final rows = <Widget>[];
    for (var minute = _startMinute; minute < _endMinute; minute += 30) {
      final starts = events
          .where((a) => _minute(a) >= minute && _minute(a) < minute + 30)
          .toList();
      final occupied = events.any(
        (a) =>
            !a.isCancelled &&
            _minute(a) < minute + 30 &&
            _minute(a) + a.durationMinutes > minute,
      );
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
                          side: const BorderSide(
                            color: ClinicalAgendaStyle.elevated,
                          ),
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
      final col = (width - 56) / 7;
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
            height: 64,
            decoration: const BoxDecoration(
              color: ClinicalAgendaStyle.elevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 56,
                  child: Icon(Icons.schedule, color: ClinicalAgendaStyle.muted),
                ),
                for (var i = 0; i < 7; i++)
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
                            width: 32,
                            height: 32,
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
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: _sameDay(_dayDate(i), DateTime.now())
                                    ? const Color(0xFF00382C)
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
                height: slots * _rowHeight,
                child: Stack(
                  children: [
                    for (var s = 0; s < slots; s++)
                      Positioned(
                        top: s * _rowHeight,
                        left: 0,
                        right: 0,
                        height: _rowHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ClinicalAgendaStyle.surface.withValues(
                              alpha: .6,
                            ),
                            border: const Border(
                              bottom: BorderSide(
                                color: ClinicalAgendaStyle.elevated,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 56,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _time(start + s * 30),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ClinicalAgendaStyle.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              for (var d = 0; d < 7; d++)
                                Expanded(
                                  child: InkWell(
                                    onTap: () => widget.onEmptySlot(
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
                    for (var d = 0; d < 7; d++)
                      ..._positionedEvents(d, start, col),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  List<Widget> _positionedEvents(int day, int start, double col) {
    final events = _events(day);
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
            top: (_minute(a) - start) / 30 * _rowHeight + 2,
            left: 56 + day * col + lane * col / group.length + 2,
            width: math.max(1, col / group.length - 4),
            height: math.max(48, a.durationMinutes / 30 * _rowHeight - 4),
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
