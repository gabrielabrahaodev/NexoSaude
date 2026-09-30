import 'package:flutter/material.dart';
import '../../../models/financial_model.dart';
import '../../../utils/display.dart';

class SessionChargeCard extends StatelessWidget {
  final FinancialModel item;
  final bool contactedToday;
  final VoidCallback onTap;

  /// Paciente avisou pagamento no portal (selo + dispensar na cobrança).
  final bool paymentNoticed;
  final VoidCallback? onDismissNotice;

  /// Deep-link p/ a ficha (sem menu). Nulo = sem botão.
  final VoidCallback? onOpenPatient;

  const SessionChargeCard({
    super.key,
    required this.item,
    required this.contactedToday,
    required this.onTap,
    this.paymentNoticed = false,
    this.onDismissNotice,
    this.onOpenPatient,
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
                "${item.title} - Vence: ${formatDateShort(item.dueDate!)}"),
            if (contactedToday)
              const Text("Já contatado hoje",
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            if (paymentNoticed)
              Row(
                children: [
                  const Text("Avisei que paguei",
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  if (onDismissNotice != null)
                    InkWell(
                      onTap: onDismissNotice,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.close,
                            size: 16, color: Colors.grey),
                      ),
                    ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${formatBRL(item.amount)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            if (onOpenPatient != null)
              IconButton(
                icon: const Icon(Icons.person_outline,
                    size: 20, color: Colors.blue),
                tooltip: "Abrir paciente",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onOpenPatient,
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
