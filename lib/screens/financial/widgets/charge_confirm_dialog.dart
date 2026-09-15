import 'package:flutter/material.dart';

class ChargeConfirmDialog extends StatelessWidget {
  final String? displayName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ChargeConfirmDialog({
    super.key,
    required this.displayName,
    required this.onConfirm,
    required this.onCancel,
  });

  static Future<void> show(
    BuildContext context, {
    required String? displayName,
    required String? processingId,
    required String monthlyPackagePrefix,
    required Future<void> Function(String id) onMarkCharged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChargeConfirmDialog(
        displayName: displayName,
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () async {
          Navigator.pop(ctx);
          if (processingId != null &&
              !processingId.startsWith(monthlyPackagePrefix)) {
            await onMarkCharged(processingId);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Confirmação: $displayName"),
      content:
          const Text("Você enviou a mensagem de cobrança no WhatsApp?"),
      actions: [
        TextButton(
            onPressed: onCancel,
            child: const Text("Não / Cancelar",
                style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text("SIM, Marcar Cobrado"),
        ),
      ],
    );
  }
}
