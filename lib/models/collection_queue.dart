import '../utils/report_export.dart' show reportMoney;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../services/clinic_capabilities.dart';
import '../services/oracle_report_service.dart';
import '../services/package_billing.dart';
import '../services/pix_brcode.dart';
import '../utils/display.dart';
import 'appointment_model.dart';
import 'financial_model.dart';
import 'patient_list_entry.dart' show patientSearchKey;

class CollectionClinic {
  const CollectionClinic(
    this.id,
    this.name,
    this.type, {
    this.pixKey = '',
    this.city = '',
  });
  final String id, name, type, pixKey, city;
  bool get psychology => ClinicCapabilities.ofType(type).isPsychology;
  String get protocol =>
      psychology ? 'Psicologia · Pacotes & Sessões' : 'Odonto · Débito Direto';
  factory CollectionClinic.fromMap(String id, Map<String, dynamic> m) {
    final address = m['address'];
    return CollectionClinic(
      id,
      '${m['name'] ?? 'Unidade'}',
      '${m['type'] ?? 'dental'}',
      pixKey: '${m['pixKey'] ?? ''}'.trim(),
      city: '${m['city'] ?? (address is Map ? address['city'] : null) ?? ''}'
          .trim(),
    );
  }
}

bool collectionPackage(Map<String, dynamic> m) =>
    m['billingKind'] == 'package_monthly' ||
    (m['billingKind'] != 'session' && '${m['monthlyPeriod'] ?? ''}'.isNotEmpty);
bool collectionPaid(Map<String, dynamic> m) =>
    m['isPaid'] == true ||
    FinancialModel.isPaidOf(
      status: '${m['status'] ?? ''}',
      paidAmount: m['paidAmount'],
      amount: m['amount'],
    );
bool collectionPending(Map<String, dynamic> m) =>
    !reportCanceled(m) &&
    !collectionPaid(m) &&
    (m['type'] ?? 'income') == 'income' &&
    [
      'pending',
      'pendente',
      'cobrado',
      'parcial',
      'partial',
    ].contains('${m['status'] ?? 'pending'}'.toLowerCase().trim());
String collectionPeriod(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';
bool _inMonth(DateTime? d, DateTime m) =>
    d != null && d.year == m.year && d.month == m.month;
String collectionGroup(ReportDocument d) =>
    '${d.data['clinicId']}|${d.data['patientId']}|${d.data['monthlyPeriod']}|${d.data['planId'] ?? ''}';
double _money(double v) => (v * 100).roundToDouble() / 100;

String collectionPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10 || digits.length == 11) return '55$digits';
  if ((digits.length == 12 || digits.length == 13) && digits.startsWith('55')) {
    return digits;
  }
  return '';
}

class CollectionCharge {
  const CollectionCharge({
    required this.key,
    required this.clinic,
    required this.patientId,
    required this.patientName,
    required this.description,
    required this.documents,
    required this.amount,
    this.phone = '',
    this.record = '',
    this.dueDate,
    this.monthlyPeriod,
    this.bill,
    this.billingSessions = const [],
    this.billingPlan,
    this.issue,
    this.nextContact,
    this.contactedToday = false,
    this.paymentNoticed = false,
  });
  final String key, patientId, patientName, description, phone, record;
  final CollectionClinic clinic;
  final List<ReportDocument> documents;
  final double amount;
  final DateTime? dueDate, nextContact;
  final String? monthlyPeriod, issue;
  final PackageBill? bill;
  final List<ReportDocument> billingSessions;
  final ReportDocument? billingPlan;
  final bool contactedToday, paymentNoticed;
  bool get isPackage => monthlyPeriod != null;
  bool canContact(DateTime now) =>
      issue == null &&
      amount > 0 &&
      collectionPhone(phone).isNotEmpty &&
      !contactedToday &&
      (nextContact == null || !nextContact!.isAfter(now));
  bool matches(String raw) {
    final q = patientSearchKey(raw.trim());
    return q.isEmpty ||
        patientSearchKey(
          '$patientName $description $record ${documents.map((d) => d.id).join(' ')}',
        ).contains(q);
  }

  String get badge => isPackage
      ? 'Pacote ${bill?.previstas ?? ''} sessões · ${clinic.name}'
      : clinic.psychology
      ? 'Sessão avulsa · ${clinic.name}'
      : 'Odonto · ${clinic.name}';
  String message(DateTime now) {
    final unit = clinic.name;
    final date = dueDate;
    final timing = date == null
        ? 'Vencimento não informado.'
        : '${date.isBefore(DateTime(now.year, now.month, now.day)) ? 'Venceu' : 'Vencimento'} em ${formatDateFull(date)}.';
    final code = clinic.pixKey.isEmpty
        ? ''
        : clinic.city.isEmpty || clinic.pixKey.length > 77
        ? '\nChave Pix: ${clinic.pixKey}'
        : '\nPix Copia e Cola:\n${pixBrCode(chave: clinic.pixKey, amount: amount, nome: clinic.name, cidade: clinic.city)}';
    return 'Olá $patientName, tudo bem?\nAqui é da Clínica NexoSaúde (Unidade $unit).\n\n'
        'Lembramos da cobrança referente a $description. $timing\n'
        '${bill == null ? '' : '${bill!.describe()}${bill!.isPartial ? ' (mês parcial)' : ''}.\n'}'
        '\nValor em aberto: ${reportMoney(amount)}$code\n\nQualquer dúvida, estamos à disposição!';
  }
}

class CollectionQueue {
  CollectionQueue({
    required this.clinics,
    required this.charges,
    this.settled = 0,
    this.settledCount = 0,
    this.contacts = 0,
    this.receipts = const [],
  });
  final List<CollectionClinic> clinics;
  final List<CollectionCharge> charges;
  final double settled;
  final int settledCount, contacts;
  final List<ReportDocument> receipts;
  double get pending =>
      charges.fold(0, (s, c) => s + (c.issue == null ? c.amount : 0));
  int get patients => charges
      .where((c) => c.patientId.isNotEmpty)
      .map((c) => '${c.clinic.id}|${c.patientId}')
      .toSet()
      .length;
  CollectionQueue only(String? id) =>
      id == null
            ? this
            : CollectionQueue(
                clinics: clinics,
                charges: charges.where((c) => c.clinic.id == id).toList(),
                receipts: receipts
                    .where((d) => d.data['clinicId'] == id)
                    .toList(),
                settled: _clinicSettled[id] ?? 0,
                settledCount: _clinicSettledCount[id] ?? 0,
                contacts: _clinicContacts[id] ?? 0,
              )
        .._clinicSettled.addAll(_clinicSettled)
        .._clinicSettledCount.addAll(_clinicSettledCount)
        .._clinicContacts.addAll(_clinicContacts);
  // Per-unit totals are carried by the pure aggregation, not inferred from filtered queue rows.
  final Map<String, double> _clinicSettled = {};
  final Map<String, int> _clinicSettledCount = {}, _clinicContacts = {};

  static CollectionQueue build({
    required List<CollectionClinic> clinics,
    required DateTime month,
    required List<ReportDocument> financial,
    required List<ReportDocument> patients,
    required List<ReportDocument> appointments,
    required List<ReportDocument> plans,
    required DateTime now,
  }) {
    final ids = clinics.map((c) => c.id).toSet();
    final unique = {
      for (final d in financial)
        if (ids.contains(d.data['clinicId'])) d.id: d,
    };
    final people = {
      for (final d in patients) '${d.data['clinicId']}|${d.id}': d.data,
    };
    final planMaps = {
      for (final d in plans) '${d.data['clinicId']}|${d.id}': d.data,
    };
    final rows = <CollectionCharge>[];
    final settledBy = <String, double>{};
    final countBy = <String, int>{}, contactsBy = <String, int>{};
    final receipts = <ReportDocument>[];
    for (final clinic in clinics) {
      final docs = unique.values
          .where((d) => d.data['clinicId'] == clinic.id)
          .toList();
      final cash = OracleReportService.calculateMonth(
        month,
        docs,
        [],
      ).transactions.where((t) => t.isIncome && t.isPaid).toList();
      settledBy[clinic.id] = cash.fold<double>(0, (v, t) => v + t.amount);
      countBy[clinic.id] = cash.length;
      receipts.addAll([for (final t in cash) ReportDocument(t.id, t.details)]);
      final eventIds = <String>{};
      for (final d in docs) {
        final history = d.data['contactHistory'];
        if (history is List) {
          for (final event in history.whereType<Map>()) {
            if (_inMonth(reportDate(event['date']), month) &&
                '${event['method']}'.startsWith('whatsapp') &&
                (!'${event['method']}'.contains('partial') ||
                    event['confirmed'] == true)) {
              eventIds.add('${event['eventId'] ?? '${d.id}|${event['date']}'}');
            }
          }
        }
      }
      contactsBy[clinic.id] = eventIds.length;
      final packages = <String, List<ReportDocument>>{};
      for (final d in docs) {
        if (reportCanceled(d.data) ||
            (d.data['type'] ?? 'income') != 'income') {
          continue;
        }
        if (clinic.psychology && collectionPackage(d.data)) {
          if (d.data['monthlyPeriod'] == collectionPeriod(month)) {
            packages.putIfAbsent(collectionGroup(d), () => []).add(d);
          }
        } else if (!collectionPackage(d.data) &&
            collectionPending(d.data) &&
            _inMonth(reportDate(d.data['dueDate']), month)) {
          packages['single:${d.id}'] = [d];
        }
      }
      for (final entry in packages.entries) {
        final active = entry.value
            .where((d) => collectionPending(d.data))
            .toList();
        if (active.isEmpty) continue;
        final first = active.first.data;
        final pid = '${first['patientId'] ?? ''}';
        final person = people['${clinic.id}|$pid'];
        final isPackage = !entry.key.startsWith('single:');
        final due =
            active
                .map((d) => reportDate(d.data['dueDate']))
                .whereType<DateTime>()
                .toList()
              ..sort();
        final full = entry.value.fold<double>(
          0,
          (s, d) => s + parseBRL(d.data['amount']),
        );
        final paid = entry.value.fold<double>(
          0,
          (s, d) => s + math.max(0, parseBRL(d.data['paidAmount'])),
        );
        var amount = active.fold<double>(
          0,
          (s, d) =>
              s +
              math.max(
                0,
                parseBRL(d.data['amount']) - parseBRL(d.data['paidAmount']),
              ),
        );
        String? issue;
        PackageBill? bill;
        List<ReportDocument> billingSessions = const [];
        ReportDocument? billingPlan;
        if (pid.isEmpty || person == null) {
          issue = 'Paciente não encontrado nesta unidade.';
        }
        final planId = '${first['planId'] ?? ''}';
        final frozen = entry.value.any(
          (d) =>
              collectionPaid(d.data) ||
              parseBRL(d.data['paidAmount']) > 0 ||
              d.data['billingRatedAmount'] != null ||
              '${d.data['status']}'.toLowerCase() == 'cobrado',
        );
        if (isPackage && !frozen) {
          final candidates = appointments
              .where(
                (d) =>
                    d.data['clinicId'] == clinic.id &&
                    d.data['patientId'] == pid &&
                    _inMonth(reportDate(d.data['date']), month) &&
                    (d.data['monthlyPeriod'] == null ||
                        d.data['monthlyPeriod'] == collectionPeriod(month)),
              )
              .toList();
          final linked = candidates
              .where((d) => planId.isNotEmpty && d.data['planId'] == planId)
              .toList();
          final ambiguous =
              planId.isEmpty &&
              candidates.any((d) => '${d.data['planId'] ?? ''}'.isNotEmpty);
          final sessions = linked.isNotEmpty
              ? linked
              : candidates
                    .where((d) => '${d.data['planId'] ?? ''}'.isEmpty)
                    .toList();
          final plan = planMaps['${clinic.id}|$planId'];
          if (ambiguous ||
              sessions.isEmpty ||
              (planId.isNotEmpty &&
                  (plan == null ||
                      (plan['patientId'] != null &&
                          plan['patientId'] != pid)))) {
            issue =
                'Cálculo indisponível: confira vínculo do plano e sessões. A cobrança está bloqueada.';
          } else {
            billingSessions = sessions;
            billingPlan = plan == null ? null : ReportDocument(planId, plan);
            bill = PackageBilling.compute(
              packageAmount: full,
              discount: parseBRL(plan?['thirdPartyDiscount']),
              sessions: [
                for (final d in sessions)
                  AppointmentModel.fromMap(d.id, {
                    ...d.data,
                    'date': Timestamp.fromDate(reportDate(d.data['date'])!),
                  }),
              ],
            );
            amount = math.max(0, bill.amountDue - paid);
          }
        } else if (isPackage && frozen) {
          // Values already paid/charged/apurated are frozen; presence is never applied twice.
          amount = active.fold<double>(
            0,
            (s, d) =>
                s +
                math.max(
                  0,
                  parseBRL(d.data['amount']) - parseBRL(d.data['paidAmount']),
                ),
          );
        }
        if (!amount.isFinite || amount < 0) {
          amount = 0;
          issue = 'Valor inválido. Confira o lançamento.';
        }
        final futureContacts =
            active
                .map((d) => reportDate(d.data['nextContactAt']))
                .whereType<DateTime>()
                .toList()
              ..sort();
        rows.add(
          CollectionCharge(
            key: entry.key,
            clinic: clinic,
            patientId: pid,
            patientName:
                '${person?['name'] ?? first['patientName'] ?? 'Paciente'}',
            description: isPackage
                ? '${first['title'] ?? 'Pacote mensal'} · ${collectionPeriod(month)}'
                : '${first['title'] ?? first['description'] ?? 'Procedimento'}',
            documents: active,
            amount: _money(amount),
            phone:
                [person?['phone'], person?['celular'], person?['whatsapp']]
                    .map((v) => '${v ?? ''}')
                    .where((v) => collectionPhone(v).isNotEmpty)
                    .firstOrNull ??
                '',
            record:
                '${person?['recordNumber'] ?? person?['prontuario'] ?? person?['medicalRecordNumber'] ?? ''}',
            dueDate: due.isEmpty ? null : due.first,
            monthlyPeriod: isPackage ? collectionPeriod(month) : null,
            bill: bill,
            billingSessions: billingSessions,
            billingPlan: billingPlan,
            issue: issue,
            contactedToday: active.any((d) {
              final t = reportDate(d.data['lastContactDate']);
              return t != null &&
                  t.year == now.year &&
                  t.month == now.month &&
                  t.day == now.day;
            }),
            nextContact: futureContacts.isEmpty ? null : futureContacts.last,
            paymentNoticed: active.any((d) => d.data['avisoPagamento'] is Map),
          ),
        );
      }
    }
    rows.sort(
      (a, b) =>
          (a.dueDate ?? DateTime(9999)).compareTo(
                b.dueDate ?? DateTime(9999),
              ) !=
              0
          ? (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999))
          : a.key.compareTo(b.key),
    );
    final out = CollectionQueue(
      clinics: clinics,
      charges: rows,
      receipts: receipts,
      settled: settledBy.values.fold(0, (a, b) => a + b),
      settledCount: countBy.values.fold(0, (a, b) => a + b),
      contacts: contactsBy.values.fold(0, (a, b) => a + b),
    );
    out._clinicSettled.addAll(settledBy);
    out._clinicSettledCount.addAll(countBy);
    out._clinicContacts.addAll(contactsBy);
    return out;
  }
}
