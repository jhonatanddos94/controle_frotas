import 'package:controle_frota/views/alertas_page.dart';
import 'package:controle_frota/views/manutencoes_page.dart';
import 'package:controle_frota/views/viatura_detalhes_page.dart';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class ListagensPage extends StatefulWidget {
  const ListagensPage({super.key});

  @override
  State<ListagensPage> createState() => _ListagensPageState();
}

class _ListagensPageState extends State<ListagensPage> {
  String _opcaoSelecionada = 'Viaturas';
  late Future<List<Map<String, dynamic>>> _viaturasFuture;

  // Paginação e filtro
  int _paginaAtual = 0;
  final int _itensPorPagina = 10;
  String _filtroSituacao = 'Todas';
  List<Map<String, dynamic>> _todasViaturas = [];

  @override
  void initState() {
    super.initState();
    _viaturasFuture = DatabaseHelper.getViaturas();
  }

  void _refreshViaturas({bool resetPage = true}) {
    setState(() {
      _viaturasFuture = DatabaseHelper.getViaturas();
      if (resetPage) _paginaAtual = 0;
    });
  }

  List<Map<String, dynamic>> get _viaturasFiltradas {
    if (_filtroSituacao == 'Todas') return _todasViaturas;
    return _todasViaturas
        .where(
          (v) =>
              v['situacao'].toString().toLowerCase() ==
              _filtroSituacao.toLowerCase(),
        )
        .toList();
  }

  String _formatPlaca(String? raw) {
    if (raw == null) return '';
    final s = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    // ABC0000 -> ABC-0000 | ABC1D23 -> ABC-1D23 (fica ok pra testes)
    return s.length >= 7 ? '${s.substring(0, 3)}-${s.substring(3)}' : raw;
  }

  List<Map<String, dynamic>> get _viaturasPaginadas {
    final lista = _viaturasFiltradas;
    if (lista.isEmpty) return [];
    final total = lista.length;
    // evita RangeError se página atual ficou "além" após filtro/remoção
    final inicioRaw = _paginaAtual * _itensPorPagina;
    final inicio = inicioRaw.clamp(0, total).toInt();
    var fim = (inicio + _itensPorPagina);
    if (fim > total) fim = total;
    return lista.sublist(inicio, fim);
  }

  int get _totalPaginas => _viaturasFiltradas.isEmpty
      ? 1
      : (_viaturasFiltradas.length / _itensPorPagina).ceil();

  Icon _iconeSituacao(String situacao) {
    switch (situacao.toLowerCase()) {
      case 'oficina':
        return const Icon(Icons.build, color: Colors.orange);
      case 'reservada':
        return const Icon(Icons.car_rental, color: Colors.blueGrey);
      case 'ativa':
        return const Icon(Icons.directions_car, color: Colors.green);
      default:
        return const Icon(Icons.directions_car_filled_outlined);
    }
  }

  // ——— cores do badge (igual estilo dos chips da página Manutenções) ———
  Color _situacaoBadgeBg(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'ativa':
        return const Color(0xFFD1FAE5); // verde claro
      case 'oficina':
        return const Color(0xFFFFF0D5); // âmbar claro
      case 'reservada':
        return const Color(0xFFE8F0FE); // azul claro
      default:
        return const Color(0xFFEFF3F4); // neutro claro
    }
  }

  Color _situacaoBadgeFg(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'ativa':
        return const Color(0xFF166534); // verde escuro
      case 'oficina':
        return const Color(0xFF8C5A13); // âmbar escuro
      case 'reservada':
        return const Color(0xFF0B57D0); // azul escuro
      default:
        return const Color(0xFF374151); // cinza escuro
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          // Cabeçalho (cards)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCard('Viaturas', Image.asset('assets/police.png')),
                const SizedBox(width: 12),
                _buildCard('Manutenções', Image.asset('assets/manutencao.png')),
                const SizedBox(width: 12),
                _buildCard('Alertas', Image.asset('assets/alert.png')),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Conteúdo (com fundo ocupando largura total)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6FCFA),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _buildConteudo(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String label, Widget iconWidget) {
    final selecionado = _opcaoSelecionada == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _opcaoSelecionada = label;
          });
          if (label == 'Viaturas') {
            _refreshViaturas(
              resetPage: false,
            ); // opcional: dá uma atualizada leve
          }
        },
        child: Card(
          elevation: selecionado ? 4 : 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: selecionado
                ? const BorderSide(color: Colors.teal, width: 1)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 28, width: 28, child: iconWidget),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: selecionado ? Colors.teal : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    switch (_opcaoSelecionada) {
      case 'Viaturas':
        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(_viaturasFuture), // garante rebuild ao trocar o Future
          future: _viaturasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Erro ao carregar viaturas'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Nenhuma viatura cadastrada'));
            }

            _todasViaturas = snapshot.data!;

            // Se a página atual ficou fora do alcance depois de um filtro/refresh, volta pra 0
            final maxPageIndex = (_totalPaginas - 1).clamp(0, 9999);
            if (_paginaAtual > maxPageIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _paginaAtual = maxPageIndex);
              });
            }

            return Column(
              children: [
                // Filtro por situação
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todas', 'ativa', 'oficina', 'reservada'].map((
                      filtro,
                    ) {
                      final ativo = _filtroSituacao == filtro;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            filtro[0].toUpperCase() + filtro.substring(1),
                          ),
                          selected: ativo,
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: ativo ? Colors.white : Colors.black,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _filtroSituacao = filtro;
                              _paginaAtual = 0;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // Lista com pull-to-refresh e cards no mesmo estilo dos de Manutenções
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _refreshViaturas(resetPage: false),
                    child: _viaturasPaginadas.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'Nenhuma viatura para exibir neste filtro.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _viaturasPaginadas.length,
                            itemBuilder: (context, index) {
                              final v = _viaturasPaginadas[index];

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    // ABRE DETALHES E ESPERA RESULTADO
                                    final changed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ViaturaDetalhesPage(viatura: v),
                                      ),
                                    );

                                    if (changed == true) {
                                      _refreshViaturas(); // recarrega a lista
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical:
                                          18, // mesmo respiro vertical dos cards de manutenção
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Ícone
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: _iconeSituacao(v['situacao']),
                                        ),

                                        // Título + subtítulo
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${v['numeroViatura']} - ${_formatPlaca(v['placa']?.toString())}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${v['modelo']} • KM Atual ${v['kmAtual']}',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  color: Colors.black54,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Badge da situação
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _situacaoBadgeBg(
                                              v['situacao'],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            (v['situacao'] ?? '')
                                                    .toString()
                                                    .isEmpty
                                                ? 'Indefinido'
                                                : (v['situacao'] as String),
                                            style: TextStyle(
                                              color: _situacaoBadgeFg(
                                                v['situacao'],
                                              ),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // Paginação
                // Paginação (sem overflow: quebra em várias linhas se precisar)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(_totalPaginas, (i) {
                        final sel = i == _paginaAtual;
                        return InkWell(
                          onTap: () => setState(() => _paginaAtual = i),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? Colors.blue : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: sel ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            );
          },
        );

      case 'Manutenções':
        return const ManutencoesPage();

      case 'Alertas':
        return const AlertasPage();

      default:
        return const Center(child: Text('Selecione uma opção acima'));
    }
  }
}
