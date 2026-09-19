import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/financial_model.dart';
import '../../../utils/display.dart';

class SessionChargeCard extends StatelessWidget {
  final FinancialModel item;
  final bool contactedToday;
  final VoidCallback onTap;

  const SessionChargeCard({
    super.key,
    required this.item,
    required this.contactedToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              contactedToday ? Colors.grey : Colors.green[100],
          child: Icon(Icons.chat,
              color: contactedToday ? Colors.white : Colors.green[800]),
        ),
        title: Text(item.patientName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "${item.title} - Vence: ${DateFormat('dd/MM').format(item.dueDate!)}"),
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
            Text("${formatBRL(item.amount)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
