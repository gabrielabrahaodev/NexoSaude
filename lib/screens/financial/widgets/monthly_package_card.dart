import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'billing_skeleton.dart';
import '../../../utils/display.dart';

class MonthlyPackageCard extends StatelessWidget {
  final String patientName;
  final String periodLabel;
  final String installmentNumber;
  final int sessionCount;
  final DateTime dueDate;
  final double totalAmount;
  final bool contactedToday;
  final VoidCallback onTap;
  final double? fullAmount;
  final String? billingDetail;
  final bool isPartial;
  final bool billingLoading;

  const MonthlyPackageCard({
    super.key,
    required this.patientName,
    required this.periodLabel,
    required this.installmentNumber,
    required this.sessionCount,
    required this.dueDate,
    required this.totalAmount,
    required this.contactedToday,
    required this.onTap,
    this.fullAmount,
    this.billingDetail,
    this.isPartial = false,
    this.billingLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: contactedToday ? Colors.grey[50] : Colors.purple[50],
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor:
              contactedToday ? Colors.grey : Colors.purple[100],
          child: Icon(Icons.psychology,
              color: contactedToday ? Colors.white : Colors.purple[800]),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(patientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'PACOTE $periodLabel',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800]),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "$installmentNumber • $sessionCount sessão(ões) • Vence: ${DateFormat('dd/MM').format(dueDate)}"),
            if (billingLoading)
              const BillingDetailSkeleton()
            else if (billingDetail != null)
              Text(billingDetail!,
                  style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            if (contactedToday)
              const Text("Já contatado hoje",
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (billingLoading)
              const BillingSkeleton()
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${formatBRL(totalAmount)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.purple)),
                  if (fullAmount != null && fullAmount != totalAmount)
                    Text("de ${formatBRL(fullAmount!)}",
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
