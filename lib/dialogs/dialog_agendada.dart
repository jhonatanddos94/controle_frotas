import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:controle_frota/models/manutencao_model.dart';

Future<Manutencao?> showDialogAgendada(
  BuildContext context,
  Manutencao manutencao,
) async {
  // --- Regras de status ---
  final stRaw = (manutencao.status ?? '').toString();
  final st = stRaw.toLowerCase();
  final isConcluida = st == 'concluída' || st == 'concluida';
  final isEmAndamento = st == 'em andamento';

  // Bloqueia se já estiver concluída
  if (isConcluida) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Operação não permitida'),
        content: const Text(
          'Esta manutenção já está CONCLUÍDA e não pode ser reagendada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return null;
  }

  // --- Controllers ---
  final _localController = TextEditingController(text: manutencao.local ?? '');
  final _obsController = TextEditingController(
    text: manutencao.observacao ?? '',
  );

  DateTime? _dataSelecionada = _parseFlexible(manutencao.dataAlvo);
  final _dataController = TextEditingController(
    text: _dataSelecionada == null
        ? ''
        : DateFormat('dd/MM/yyyy').format(_dataSelecionada),
  );

  return showDialog<Manutencao>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Agendar Manutenção'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner de informação quando está "Em andamento"
              if (isEmAndamento)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Esta manutenção está EM ANDAMENTO. Ao salvar, o status será mantido.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

              // DATA (OPCIONAL)
              TextField(
                readOnly: true,
                controller: _dataController,
                decoration: InputDecoration(
                  labelText: 'Data prevista (opcional)',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_dataController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpar data',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _dataSelecionada = null;
                            _dataController.text = '';
                          },
                        ),
                      IconButton(
                        tooltip: 'Escolher data',
                        icon: const Icon(Icons.calendar_month_outlined),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dataSelecionada ?? now,
                            // permite passado (ex.: registrar algo que já venceu)
                            firstDate: DateTime(now.year - 5),
                            lastDate: DateTime(now.year + 5),
                            locale: const Locale('pt', 'BR'),
                          );
                          if (picked != null) {
                            _dataSelecionada = picked;
                            _dataController.text = DateFormat(
                              'dd/MM/yyyy',
                            ).format(picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // LOCAL (opcional)
              TextField(
                controller: _localController,
                decoration: const InputDecoration(
                  labelText: 'Local da manutenção (opcional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // OBSERVAÇÃO (opcional)
              TextField(
                controller: _obsController,
                maxLines: 3,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final temData = _dataController.text.trim().isNotEmpty;
            final temKmAlvo = (manutencao.kmAlvo ?? 0) > 0;

            final manutencaoAtualizada = Manutencao(
              id: manutencao.id,
              viaturaId: manutencao.viaturaId,
              descricao: manutencao.descricao,
              data: manutencao.data,
              km: manutencao.km,
              kmAlvo: manutencao.kmAlvo,
              dataAlvo: _dataController.text.trim(),
              // ❗️só vira Agendada se tiver critério de agenda
              status: (temData || temKmAlvo)
                  ? 'Agendada'
                  : (manutencao.status ?? 'Pendente'),
              local: _localController.text.trim(),
              observacao: _obsController.text.trim(),
            );
            Navigator.pop(context, manutencaoAtualizada);
          },

          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// Aceita ''/null, dd/MM/yyyy e formatos ISO comuns.
DateTime? _parseFlexible(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  // ISO direto
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  // dd/MM/yyyy
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(s);
  } catch (_) {}

  // Fallback para formatos comuns
  for (final f in [
    DateFormat('dd/MM/yyyy HH:mm'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('yyyy-MM-dd HH:mm:ss'),
  ]) {
    try {
      return f.parseStrict(s);
    } catch (_) {}
  }
  return null;
}
