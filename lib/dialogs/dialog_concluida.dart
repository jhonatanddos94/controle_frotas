import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/manutencao_model.dart';

Future<bool> showDialogConcluida(
  BuildContext context,
  Manutencao manutencao,
) async {
  final formKey = GlobalKey<FormState>();

  final nomeController = TextEditingController(
    text: manutencao.responsavelNome ?? '',
  );
  final matriculaController = TextEditingController(
    text: manutencao.responsavelMatricula ?? '',
  );
  final localController = TextEditingController(text: manutencao.local ?? '');
  final observacaoController = TextEditingController(
    text: manutencao.observacao ?? '',
  );

  DateTime dataHoraConclusao = () {
    final raw = manutencao.dataHoraConclusao?.trim();
    if (raw == null || raw.isEmpty) return DateTime.now();
    return DateTime.tryParse(raw) ?? DateTime.now();
  }();

  String _fmt(DateTime dt) => DateFormat('dd/MM/yyyy HH:mm').format(dt);
  final dataHoraCtrl = TextEditingController(text: _fmt(dataHoraConclusao));

  Future<void> _selecionarDataHora() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: dataHoraConclusao,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dataHoraConclusao),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (pickedTime == null) return;

    dataHoraConclusao = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    dataHoraCtrl.text = _fmt(dataHoraConclusao);
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Finalizar Manutenção'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Data/hora da conclusão
                GestureDetector(
                  onTap: _selecionarDataHora,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: dataHoraCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Data/Hora da conclusão',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nome de guerra (obrigatório)
                TextFormField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome de guerra',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÿ\s]")),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Informe o nome';
                    if (RegExp(r'[0-9]').hasMatch(v)) {
                      return 'Não pode conter números';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Matrícula (OBRIGATÓRIA)
                TextFormField(
                  controller: matriculaController,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula do agente',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Informe a matrícula';
                    // opcional: tamanho mínimo/máximo
                    if (v.length < 3) return 'Mínimo de 3 dígitos';
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: localController,
                  decoration: const InputDecoration(
                    labelText: 'Local da manutenção (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: observacaoController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade100,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;

            try {
              final db = await DatabaseHelper.getDatabase();

              await db.update(
                'manutencoes',
                {
                  'status': 'Concluída',
                  'responsavelNome': nomeController.text.trim(),
                  'responsavelMatricula': matriculaController.text
                      .trim(), // obrigatório
                  'local': localController.text.trim().isEmpty
                      ? null
                      : localController.text.trim(),
                  'observacao': observacaoController.text.trim().isEmpty
                      ? null
                      : observacaoController.text.trim(),
                  'dataHoraConclusao': dataHoraConclusao.toIso8601String(),
                  'visto': 1,
                },
                where: 'id = ?',
                whereArgs: [manutencao.id],
              );

              await db.update(
                'viaturas',
                {'situacao': 'Ativa'},
                where: 'id = ?',
                whereArgs: [manutencao.viaturaId],
              );

              Navigator.pop(ctx, true);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Falha ao concluir: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Concluir'),
        ),
      ],
    ),
  );

  return result ?? false;
}
