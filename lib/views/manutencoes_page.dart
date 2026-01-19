import 'package:controle_frota/models/viatura_model.dart';
import 'package:controle_frota/views/list_manutencoes_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class ManutencoesPage extends StatefulWidget {
  const ManutencoesPage({super.key});

  @override
  State<ManutencoesPage> createState() => _ManutencoesPageState();
}

class _ManutencoesPageState extends State<ManutencoesPage> {
  // Dados
  List<Map<String, dynamic>> _todasManutencoes = [];
  Map<int, Viatura> _viaturaCache = {}; // viaturaId -> Viatura

  // UI/estado
  String _filtroStatus = 'Todas';
  String _busca = '';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    setState(() => _carregando = true);
    await Future.wait([_carregarManutencoes(), _carregarViaturas()]);
    setState(() => _carregando = false);
  }

  Future<void> _carregarManutencoes() async {
    final db = await DatabaseHelper.getDatabase();
    final resultado = await db.query('manutencoes', orderBy: 'data DESC');
    _todasManutencoes = resultado;
  }

  Future<void> _carregarViaturas() async {
    final db = await DatabaseHelper.getDatabase();
    final rows = await db.query('viaturas');
    _viaturaCache = {
      for (final v in rows) (v['id'] as int): Viatura.fromMap(v),
    };
  }

  // ---------- Helpers ----------
  bool _isProximaOuAgendada(String s) {
    final v = s.trim().toLowerCase();
    return v == 'próxima' || v == 'proxima' || v == 'agendada';
  }

  // Criticidade (mesma regra da Home): 'critico' | 'atencao' | 'prazo' | null
  String? _criticidade(Map<String, dynamic> m, Viatura v) {
    final int kmAlvo = (m['kmAlvo'] ?? m['km'] ?? 0) is int
        ? (m['kmAlvo'] ?? m['km'] ?? 0) as int
        : int.tryParse((m['kmAlvo'] ?? m['km'] ?? '0').toString()) ?? 0;

    final int kmRestante = kmAlvo - v.kmAtual;

    final String? dataAlvoStr = m['dataAlvo'] as String?;
    int diasRestantes = 9999;
    if (dataAlvoStr != null && dataAlvoStr.trim().isNotEmpty) {
      try {
        final d = DateFormat('dd/MM/yyyy').parse(dataAlvoStr);
        diasRestantes = d.difference(DateTime.now()).inDays;
      } catch (_) {}
    }

    final bool isCritico = kmRestante <= 500 || diasRestantes <= 7;
    final bool isAtencao = kmRestante <= 1000 || diasRestantes <= 30;
    final bool isDentroPrazo =
        (kmRestante > 1000 && kmRestante <= 2000) ||
        (diasRestantes > 30 && diasRestantes <= 60);

    if (isCritico) return 'critico';
    if (isAtencao) return 'atencao';
    if (isDentroPrazo) return 'prazo';
    return null;
  }

  // Cores de status “sistema”
  Color _statusFg(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'concluída':
      case 'concluida':
        return const Color(0xFF166534); // verde escuro
      case 'em andamento':
        return const Color(0xFF0B57D0); // azul escuro
      case 'agendada':
        return const Color(0xFF445A6A); // neutro
      default:
        return const Color(0xFF374151);
    }
  }

  Color _statusBg(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'concluída':
      case 'concluida':
        return const Color(0xFFD1FAE5); // verde claro
      case 'em andamento':
        return const Color(0xFFE8F0FE); // azul claro
      case 'agendada':
        return const Color(0xFFEFF3F4); // neutro claro
      default:
        return const Color(0xFFEFF3F4);
    }
  }

  // Cores das faixas de criticidade (para Próxima/Agendada)
  Color _critFg(String level) {
    switch (level) {
      case 'critico':
        return const Color(0xFFB3261E); // vermelho escuro
      case 'atencao':
        return const Color(0xFF8C5A13); // âmbar escuro
      case 'prazo':
        return const Color(0xFF1B5E20); // verde escuro
      default:
        return const Color(0xFF374151);
    }
  }

  Color _critBg(String level) {
    switch (level) {
      case 'critico':
        return const Color(0xFFFFE3E3); // vermelho muito claro
      case 'atencao':
        return const Color(0xFFFFF0D5); // âmbar claro (mais distinto)
      case 'prazo':
        return const Color(0xFFE7F5EE); // verde muito claro
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  // Filtro + busca
  List<Map<String, dynamic>> get _manutencoesFiltradas {
    Iterable<Map<String, dynamic>> lista = _todasManutencoes;

    if (_filtroStatus != 'Todas') {
      lista = lista.where(
        (m) =>
            (m['status'] ?? '').toString().toLowerCase() ==
            _filtroStatus.toLowerCase(),
      );
    }

    if (_busca.trim().isNotEmpty) {
      final q = _busca.toLowerCase();
      lista = lista.where((m) {
        final viatura = _viaturaCache[m['viaturaId'] as int? ?? -1];
        final placa = viatura?.placa.toLowerCase() ?? '';
        final num = viatura?.numeroViatura.toLowerCase() ?? '';
        final desc = (m['descricao'] ?? '').toString().toLowerCase();
        return placa.contains(q) || num.contains(q) || desc.contains(q);
      });
    }

    return lista.toList();
  }

  int _countStatus(String status) {
    if (status == 'Todas') return _todasManutencoes.length;
    return _todasManutencoes
        .where(
          (m) =>
              (m['status'] ?? '').toString().toLowerCase() ==
              status.toLowerCase(),
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar por descrição, placa ou nº da viatura',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _busca = v),
          ),
        ),

        // Filtros
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Todas', 'Agendada', 'Em andamento', 'Concluída'].map((
              status,
            ) {
              final ativo = _filtroStatus == status;
              final count = _countStatus(status);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$status ($count)'),
                  selected: ativo,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(
                    color: ativo ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _filtroStatus = status),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 6),

        // Lista
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregarTudo,
                  child: _manutencoesFiltradas.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Nenhuma manutenção encontrada.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          itemCount: _manutencoesFiltradas.length,
                          itemBuilder: (context, index) {
                            final m = _manutencoesFiltradas[index];
                            final viatura =
                                _viaturaCache[m['viaturaId'] as int? ?? -1];

                            if (viatura == null) {
                              return const SizedBox.shrink();
                            }

                            final status = (m['status'] ?? '').toString();
                            final data = (m['data'] ?? '').toString();
                            final km = m['km'];

                            // Criticidade para Próxima/Agendada
                            final bool usaCrit = _isProximaOuAgendada(status);
                            final String? crit = usaCrit
                                ? _criticidade(m, viatura)
                                : null;

                            // Badge
                            late final Widget badge;
                            if (usaCrit && crit != null) {
                              final label = (crit == 'critico')
                                  ? 'Crítico'
                                  : (crit == 'atencao')
                                  ? 'Atenção'
                                  : 'No prazo';

                              badge = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _critBg(crit),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: _critFg(crit),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              );
                            } else {
                              badge = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusBg(status),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status.isEmpty ? 'Indefinido' : status,
                                  style: TextStyle(
                                    color: _statusFg(status),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              );
                            }

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ListManutencoesPage(
                                        viatura: viatura,
                                        manutencaoIdDestacada: m['id'] as int?,
                                      ),
                                    ),
                                  ).then((_) => _carregarTudo());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: Icon(
                                          Icons.build_circle_rounded,
                                          size: 32,
                                          color: (usaCrit && crit != null)
                                              ? _critFg(crit!)
                                              : _statusFg(status),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (m['descricao'] ??
                                                      'Sem descrição')
                                                  .toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Viatura ${viatura.numeroViatura} • ${viatura.placa} • KM: $km',
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Data: $data',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      badge,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
