import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

Future<void> mostrarDialogoAnimado({
  required BuildContext context,
  required String titulo,
  required String lottieAsset,
  bool barrierDismissible = false,
  Duration? tempoAutoFechamento,
}) async {
  showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(lottieAsset, width: 120, repeat: true),
              const SizedBox(height: 16),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (tempoAutoFechamento != null) {
    await Future.delayed(tempoAutoFechamento);
    Navigator.of(context).pop(); // Fecha o dialogo
  }
}
