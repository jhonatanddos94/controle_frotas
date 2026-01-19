import 'package:flutter/material.dart';
import 'package:controle_frota/db/database_helper.dart';

/// Mostra um diálogo para excluir a viatura.
/// - Se tiver manutenções vinculadas, o botão "Excluir" fica desabilitado.
/// - Se o usuário confirmar, o diálogo já tenta EXCLUIR (com trava no banco).
/// Retorna:
///   true  -> excluiu com sucesso
///   false -> usuário cancelou ou não foi possível excluir
Future<bool?> showConfirmExcluirViaturaDialog(
  BuildContext context, {
  required int viaturaId,
  required String numeroViatura,
  required String placa,
}) async {
  // Checa antes de abrir (para já controlar o estado do botão)
  final manutCount = await DatabaseHelper.contarManutencoesDaViatura(viaturaId);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      final podeExcluir = manutCount == 0;

      return AlertDialog(
        title: const Text('Excluir viatura?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Viatura $numeroViatura • Placa $placa'),
            const SizedBox(height: 12),
            if (!podeExcluir)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta viatura possui $manutCount manutenção(ões) cadastrada(s).\n'
                      'Exclua ou transfira as manutenções antes de excluir a viatura.',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Esta ação não pode ser desfeita.',
                style: TextStyle(color: Colors.black87),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Excluir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: !podeExcluir
                ? null
                : () async {
                    // Segurança extra: tenta excluir com verificação no DB.
                    final ok =
                        await DatabaseHelper.excluirViaturaSeSemManutencoes(
                          viaturaId,
                        );

                    if (!ok && context.mounted) {
                      // Situação de corrida: alguém vinculou manutenção agora.
                      await showDialog<void>(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text('Não foi possível excluir'),
                          content: Text(
                            'A viatura passou a ter manutenções vinculadas. '
                            'Exclua ou transfira as manutenções antes de excluir a viatura.',
                          ),
                        ),
                      );
                    }

                    if (context.mounted) {
                      Navigator.pop(context, ok);
                    }
                  },
          ),
        ],
      );
    },
  );
}
