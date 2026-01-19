import 'package:flutter/material.dart';
import '../models/manutencao_model.dart';
import '../db/database_helper.dart';

Future<void> mostrarDialogoAndamento({
  required BuildContext context,
  required Manutencao manutencao,
  VoidCallback? onAtualizado, // callback para atualizar a tela depois
}) async {
  final confirmar = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Iniciar Manutenção'),
      content: const Text('Deseja marcar esta manutenção como "Em andamento"?'),
      actions: [
        TextButton(
          child: const Text('Cancelar', style: TextStyle(color: Colors.teal)),
          onPressed: () => Navigator.pop(context, false),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Confirmar'),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  if (confirmar == true) {
    try {
      await _iniciarManutencao(manutencao);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manutenção marcada como em andamento.')),
      );

      onAtualizado?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao iniciar manutenção: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _iniciarManutencao(Manutencao manutencao) async {
  final db = await DatabaseHelper.getDatabase();

  // Atualiza SOMENTE os campos necessários da manutenção
  await db.update(
    'manutencoes',
    {
      'status': 'Em andamento',
      'visto': 1, // não aparecer como atenção/prazo
      // NÃO alteramos dataAlvo nem kmAlvo aqui.
    },
    where: 'id = ?',
    whereArgs: [manutencao.id],
  );

  // (Recomendado) refletir na viatura a mudança de status operacional
  await db.update(
    'viaturas',
    {'situacao': 'Oficina'},
    where: 'id = ?',
    whereArgs: [manutencao.viaturaId],
  );
}
