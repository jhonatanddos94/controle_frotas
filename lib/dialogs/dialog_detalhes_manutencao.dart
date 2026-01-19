import 'package:flutter/material.dart';
import '../models/manutencao_model.dart';
import 'package:intl/intl.dart';

void showDialogDetalhesManutencao(BuildContext context, Manutencao manutencao) {
  final formatador = DateFormat('dd/MM/yyyy');

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Detalhes da Manutenção'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Descrição: ${manutencao.descricao}'),
          const SizedBox(height: 8),

          // Correção aqui: usando o formatador para parsear
          Text(
            'Data prevista: ${formatador.format(formatador.parse(manutencao.data))}',
          ),

          const SizedBox(height: 8),
          Text('KM Previsto: ${manutencao.km}'),

          if (manutencao.local?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Local: ${manutencao.local}'),
          ],
          if (manutencao.observacao?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text('Observação: ${manutencao.observacao}'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}
