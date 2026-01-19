import 'package:controle_frota/utils/criticidade_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/manutencao_model.dart';

class AlertasPage extends StatefulWidget {
  const AlertasPage({super.key});

  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  List<Manutencao> _todas = [];

  String _filtroCriticidade = 'Todas';
  String _filtroData = 'Todos';

  // viaturaId -> { numeroViatura, placa, kmAtual }
  Map<int, Map<String, dynamic>> _viaturasMap = {};

  @override
  void initState() {
    super.initState();
    _carregarManutencoes();
  }

  Future<void> _carregarManutencoes() async {
    // 1) join com nº e placa
    final manutencoesJoin = await DatabaseHelper.getTodasManutencoes();

    // 2) viaturas (para pegar kmAtual)
    final viaturasData = await DatabaseHelper.getViaturas();

    // 3) map auxiliar de viaturas
    _viaturasMap = {
      for (var v in viaturasData)
        v['id'] as int: {
          'numeroViatura': v['numeroViatura'],
          'placa': v['placa'],
          'kmAtual': v['kmAtual'] ?? 0,
        },
    };

    // 4) converte e remove concluídas/concluida E AGENDADAS
    final todas = manutencoesJoin.map((e) => Manutencao.fromMap(e)).where((m) {
      final s = m.status.trim().toLowerCase();
      return s != 'concluída' &&
          s != 'concluida' &&
          s != 'agendada' &&
          s != 'em andamento';
    }).toList();

    setState(() => _todas = todas);
  }

  // --- Criticidade (agora com "Atraso") ---
  String _nivelCriticidade(Manutencao m) {
    final viatura = _viaturasMap[m.viaturaId];
    if (viatura == null) return 'Ignorar';

    final kmAtual = viatura['kmAtual'] as int? ?? 0;
    final temKmAlvo = m.kmAlvo != null && m.kmAlvo! > 0;
    final kmAlvo = m.kmAlvo ?? 0;

    // dataAlvo é opcional
    final rawData = m.dataAlvo.trim();
    DateTime? data;
    if (rawData.isNotEmpty) {
      // tenta dd/MM/yyyy, depois ISO
      try {
        data = DateFormat('dd/MM/yyyy').parseStrict(rawData);
      } catch (_) {
        try {
          data = DateTime.parse(rawData);
        } catch (_) {}
      }
    }

    // --- Regras de atraso ---
    final hoje = DateTime.now();
    final atrasadoPorKm = temKmAlvo && kmAtual >= kmAlvo;
    final atrasadoPorData =
        (data != null) &&
        data.isBefore(DateTime(hoje.year, hoje.month, hoje.day));

    if (atrasadoPorKm || atrasadoPorData) {
      return 'Atraso';
    }

    // Caso não esteja atrasado, usa a função de criticidade padrão
    final String? dataParaHelper = rawData.isEmpty ? null : rawData;
    return calcularCriticidade(
      dataAlvo: dataParaHelper,
      kmAlvo: m.kmAlvo,
      kmAtual: kmAtual,
    );
  }

  Map<String, List<Manutencao>> _agruparPorData() {
    final hoje = DateTime.now();
    final formato = DateFormat('dd/MM/yyyy');
    final semanaLimite = hoje.add(const Duration(days: 7));
    final mesLimite = hoje.add(const Duration(days: 30));

    final grupos = <String, List<Manutencao>>{
      'Hoje': [],
      'Esta Semana': [],
      'Este Mês': [],
      'Sem Data': [],
      'Outros': [],
    };

    for (var m in _todas) {
      final raw = m.dataAlvo.trim();
      if (raw.isEmpty) {
        grupos['Sem Data']!.add(m);
        continue;
      }

      DateTime? data;
      try {
        data = formato.parseStrict(raw); // dd/MM/yyyy
      } catch (_) {
        try {
          data = DateTime.parse(raw); // ISO
        } catch (_) {}
      }

      if (data == null) {
        grupos['Sem Data']!.add(m);
        continue;
      }

      if (DateUtils.isSameDay(data, hoje)) {
        grupos['Hoje']!.add(m);
      } else if (data.isAfter(hoje) && data.isBefore(semanaLimite)) {
        grupos['Esta Semana']!.add(m);
      } else if (data.isAfter(semanaLimite) && data.isBefore(mesLimite)) {
        grupos['Este Mês']!.add(m);
      } else {
        grupos['Outros']!.add(m);
      }
    }

    return grupos;
  }

  Color _corPorNivel(String nivel) {
    switch (nivel) {
      case 'Atraso':
        return const Color.fromARGB(
          255,
          247,
          159,
          45,
        ); // mais forte que crítico
      case 'Crítico':
        return Colors.red.shade100;
      case 'Atenção':
        return Colors.orange.shade100;
      default:
        return Colors.green.shade100; // "No Prazo"
    }
  }

  Icon _iconePorNivel(String nivel) {
    switch (nivel) {
      case 'Atraso':
        return const Icon(Icons.report_rounded, color: Colors.red);
      case 'Crítico':
        return const Icon(Icons.warning_amber_rounded, color: Colors.red);
      case 'Atenção':
        return const Icon(Icons.error_outline, color: Colors.orange);
      default:
        return const Icon(Icons.check_circle_outline, color: Colors.green);
    }
  }

  Widget _buildListaFiltrada() {
    final grupos = _agruparPorData();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: grupos.entries
          .where((entry) => _filtroData == 'Todos' || entry.key == _filtroData)
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) {
            // Ordena "Sem Data" por KM restante (menor primeiro; atrasos vêm primeiro)
            final itens = [...entry.value];
            if (entry.key == 'Sem Data') {
              itens.sort((a, b) {
                final va = _viaturasMap[a.viaturaId];
                final vb = _viaturasMap[b.viaturaId];
                final kmAtualA = va?['kmAtual'] as int? ?? 0;
                final kmAtualB = vb?['kmAtual'] as int? ?? 0;
                final ra = (a.kmAlvo ?? 0) - kmAtualA;
                final rb = (b.kmAlvo ?? 0) - kmAtualB;
                return ra.compareTo(rb);
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📅 ${entry.key}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...itens.map((m) {
                  final nivel = _nivelCriticidade(m);
                  if (nivel == 'Ignorar') return const SizedBox.shrink();

                  if (_filtroCriticidade != 'Todas' &&
                      nivel != _filtroCriticidade) {
                    return const SizedBox.shrink();
                  }

                  final viatura = _viaturasMap[m.viaturaId];
                  final viaturaNome = viatura != null
                      ? 'Viatura ${viatura['numeroViatura']} - ${viatura['placa']}'
                      : 'Viatura não encontrada';

                  final temData = m.dataAlvo.trim().isNotEmpty;

                  return Card(
                    color: _corPorNivel(nivel),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Detalhes do Alerta'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🔧 ${m.descricao}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Viatura: $viaturaNome'),
                                if (temData) Text('Data alvo: ${m.dataAlvo}'),
                                Text('KM alvo: ${m.kmAlvo ?? '-'}'),
                                const SizedBox(height: 12),
                                if (m.local != null && m.local!.isNotEmpty)
                                  Text('Local: ${m.local}'),
                                if (m.observacao != null &&
                                    m.observacao!.isNotEmpty)
                                  Text('Obs: ${m.observacao}'),
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
                      },
                      leading: _iconePorNivel(nivel),
                      title: Text(m.descricao),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viaturaNome,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            temData
                                ? 'Data alvo: ${m.dataAlvo}   •   KM alvo: ${m.kmAlvo ?? '-'}'
                                : 'KM alvo: ${m.kmAlvo ?? '-'}',
                          ),
                        ],
                      ),
                      trailing: Text(
                        nivel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: nivel == 'Atraso'
                              ? Colors.red
                              : nivel == 'Crítico'
                              ? Colors.red
                              : nivel == 'Atenção'
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            );
          })
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Alertas')),
      body: _todas.isEmpty
          ? const Center(child: Text('Nenhum alerta encontrado.'))
          : Column(
              children: [
                const SizedBox(height: 16),
                // Filtro de criticidade (agora com "Atraso")
                Wrap(
                  spacing: 8,
                  children:
                      ['Todas', 'Atraso', 'Crítico', 'Atenção', 'No Prazo']
                          .map(
                            (nivel) => ChoiceChip(
                              label: Text(nivel),
                              selected: _filtroCriticidade == nivel,
                              selectedColor: () {
                                switch (nivel) {
                                  case 'Atraso':
                                    return Colors.red;
                                  case 'Crítico':
                                    return Colors.red;
                                  case 'Atenção':
                                    return Colors.orange;
                                  case 'No Prazo':
                                    return Colors.green;
                                  default:
                                    return Colors.blue;
                                }
                              }(),
                              onSelected: (_) =>
                                  setState(() => _filtroCriticidade = nivel),
                              labelStyle: TextStyle(
                                color: _filtroCriticidade == nivel
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
                // Filtro de datas (com "Sem Data")
                Wrap(
                  spacing: 8,
                  children:
                      ['Todos', 'Hoje', 'Esta Semana', 'Este Mês', 'Sem Data']
                          .map(
                            (filtro) => ChoiceChip(
                              label: Text(filtro),
                              selected: _filtroData == filtro,
                              selectedColor: Colors.teal,
                              onSelected: (_) =>
                                  setState(() => _filtroData = filtro),
                              labelStyle: TextStyle(
                                color: _filtroData == filtro
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildListaFiltrada()),
              ],
            ),
    );
  }
}
