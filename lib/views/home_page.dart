import 'package:controle_frota/db/database_helper.dart';
import 'package:controle_frota/main.dart';
import 'package:controle_frota/models/viatura_model.dart';
import 'package:controle_frota/views/cadastro_manutencao_page.dart';
import 'package:controle_frota/views/cadastro_viatura_page.dart';
import 'package:controle_frota/views/configuracoes_page.dart';
import 'package:controle_frota/views/lancar_km.dart';
import 'package:controle_frota/views/list_manutencoes_page.dart';
import 'package:controle_frota/views/listagem_geral_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  List<Map<String, String>> _alertas = [];

  @override
  void initState() {
    super.initState();
    _carregarAlertas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // voltando para a Home
    _carregarAlertas();
  }

  String _formatPlaca(String? raw) {
    if (raw == null) return '';
    final s = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    // ABC0000 -> ABC-0000 | ABC1D23 -> ABC-1D23 (fica ok pra testes)
    return s.length >= 7 ? '${s.substring(0, 3)}-${s.substring(3)}' : raw;
  }

  // ----------------- carga e ordenação -----------------

  Future<void> _carregarAlertas() async {
    final alertas = await _buscarAlertas();
    if (!mounted) return;
    setState(() => _alertas = alertas);
  }

  Future<List<Map<String, String>>> _buscarAlertas() async {
    // helper local: ABC1234/ABC1D23 -> ABC-1234 / ABC-1D23
    String _formatPlaca(String? raw) {
      if (raw == null) return '';
      final s = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      return s.length >= 4
          ? '${s.substring(0, 3)}-${s.substring(3)}'
          : (raw ?? '');
    }

    final db = await DatabaseHelper.getDatabase();
    final manutencoes = await db.query(
      'manutencoes',
      where: "status NOT IN ('Em andamento','Concluída','Agendada')",
    );

    final List<Map<String, String>> alertas = [];
    final hoje = DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy');

    for (var m in manutencoes) {
      final int kmAlvo = (m['kmAlvo'] as int?) ?? 0;
      final String? dataAlvoStr = m['dataAlvo'] as String?;
      final int viaturaId = m['viaturaId'] as int;
      final int visto = m['visto'] as int? ?? 0;

      final viaturaData = await db.query(
        'viaturas',
        where: 'id = ?',
        whereArgs: [viaturaId],
        limit: 1,
      );
      if (viaturaData.isEmpty) continue;

      final int kmAtual = viaturaData.first['kmAtual'] as int? ?? 0;
      final String placaFmt = _formatPlaca(
        viaturaData.first['placa']?.toString(),
      );
      final String prefixo = viaturaData.first['numeroViatura'].toString();
      final String label = ' $prefixo - $placaFmt';

      DateTime? dataAlvo;
      if (dataAlvoStr != null && dataAlvoStr.trim().isNotEmpty) {
        try {
          dataAlvo = dateFmt.parse(dataAlvoStr);
        } catch (_) {}
      }

      // --- ATRASO ---
      final int kmAtraso = kmAtual - kmAlvo; // >= 0 => passou do KM
      final int diasAtraso = dataAlvo != null
          ? hoje.difference(dataAlvo).inDays
          : 0;

      if (kmAtraso >= 0 || (dataAlvo != null && diasAtraso > 0)) {
        alertas.add({
          'placa': label,
          'mensagem': [
            if (kmAtraso >= 0)
              'ATRASADA: excedeu ${kmAtraso.clamp(0, 99999)} km',
            if (diasAtraso > 0) 'vencida há ${diasAtraso.clamp(0, 999)} dia(s)',
          ].join(' • '),
          'icone': 'assets/atraso.png',
          'id': (m['id'] ?? '').toString(),
          'viaturaId': viaturaId.toString(),
        });
        continue;
      }

      // --- A vencer / no prazo ---
      final int kmRestante = (kmAlvo - kmAtual).clamp(0, 999999);
      final int diasRestantes = dataAlvo != null
          ? dataAlvo.difference(hoje).inDays.clamp(0, 999)
          : 9999;

      final bool isCritico = kmRestante <= 500 || diasRestantes <= 7;
      final bool isAtencao = kmRestante <= 1000 || diasRestantes <= 30;
      final bool isDentroPrazo =
          (kmRestante > 1000 && kmRestante <= 2000) ||
          (diasRestantes > 30 && diasRestantes <= 60);

      String icone;
      if (isCritico) {
        icone = 'assets/warning.png';
      } else if (isAtencao) {
        if (visto == 1) continue; // ignorar já vistos
        icone = 'assets/alert.png';
      } else if (isDentroPrazo) {
        if (visto == 1) continue; // ignorar já vistos
        icone = 'assets/prazo.png';
      } else {
        continue; // muito distante: não mostramos
      }

      alertas.add({
        'placa': label,
        'mensagem': dataAlvo != null
            ? 'Faltam $kmRestante km ou $diasRestantes dias para a manutenção.'
            : 'Faltam $kmRestante km para a manutenção.',
        'icone': icone,
        'id': (m['id'] ?? '').toString(),
        'viaturaId': viaturaId.toString(),
      });
    }

    // Ordenação: atraso > crítico > atenção > no prazo
    int rank(String ic) {
      if (ic.endsWith('atraso.png')) return 0;
      if (ic.endsWith('warning.png')) return 1;
      if (ic.endsWith('alert.png')) return 2;
      return 3;
    }

    alertas.sort((a, b) {
      final r = rank(a['icone']!) - rank(b['icone']!);
      if (r != 0) return r;
      return (a['mensagem'] ?? '').compareTo(b['mensagem'] ?? '');
    });

    return alertas;
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Manutenções'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Linha de botões
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HomeCard(
                  icon: Image.asset('assets/police.png', width: 32, height: 32),
                  label: 'Viaturas',
                ),
                _HomeCard(
                  icon: Image.asset(
                    'assets/hodometro.png',
                    width: 32,
                    height: 32,
                  ),
                  label: 'Lançar KMs',
                ),
                _HomeCard(
                  icon: Image.asset(
                    'assets/manutencao.png',
                    width: 32,
                    height: 32,
                  ),
                  label: 'Manutenções',
                ),
                _HomeCard(
                  icon: Image.asset('assets/list.png', width: 32, height: 32),
                  label: 'Listar',
                ),
                _HomeCard(
                  icon: Image.asset('assets/config.png', width: 32, height: 32),
                  label: 'Configurações',
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Título + contagem + atualizar (na mesma linha)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alertas de Manutenção (${_alertas.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // você pode usar só o ícone…
                // IconButton(
                //   tooltip: 'Atualizar alertas',
                //   icon: const Icon(Icons.refresh),
                //   onPressed: _carregarAlertas,
                // ),

                // …ou um botão com texto + ícone:
                TextButton.icon(
                  onPressed: _carregarAlertas,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Lista de alertas
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: _alertas.isEmpty
                    ? const Center(child: Text('Nenhum alerta no momento.'))
                    : ListView.builder(
                        itemCount: _alertas.length,
                        itemBuilder: (context, index) {
                          final alerta = _alertas[index];
                          final iconPath =
                              alerta['icone'] ?? 'assets/prazo.png';
                          final isAtraso = iconPath.endsWith('atraso.png');

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            elevation: 1,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              leading: Image.asset(
                                iconPath,
                                width: 30,
                                height: 30,
                              ),
                              title: Text(
                                'Viatura ${alerta['placa']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(alerta['mensagem'] ?? ''),
                              // Somente ATRASO fica sem "marcar como lido"
                              trailing: isAtraso
                                  ? const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.visibility,
                                        color: Colors.grey,
                                      ),
                                      tooltip: 'Marcar como lido',
                                      onPressed: () async {
                                        final db =
                                            await DatabaseHelper.getDatabase();
                                        await db.update(
                                          'manutencoes',
                                          {'visto': 1},
                                          where: 'id = ?',
                                          whereArgs: [int.parse(alerta['id']!)],
                                        );
                                        _carregarAlertas();
                                      },
                                    ),
                              onTap: () async {
                                final db = await DatabaseHelper.getDatabase();
                                final viatura = await db.query(
                                  'viaturas',
                                  where: 'id = ?',
                                  whereArgs: [int.parse(alerta['viaturaId']!)],
                                  limit: 1,
                                );

                                if (viatura.isEmpty) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListManutencoesPage(
                                      viatura: Viatura.fromMap(viatura.first),
                                      manutencaoIdDestacada: int.tryParse(
                                        alerta['id']!,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- Card de navegação -----------------

class _HomeCard extends StatelessWidget {
  final Widget icon;
  final String label;

  const _HomeCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          Widget? target;
          switch (label) {
            case 'Viaturas':
              target = const CadastroViaturaPage();
              break;
            case 'Manutenções':
              target = const CadastroManutencaoPage();
              break;
            case 'Lançar KMs':
              target = const LancarKmPage();
              break;
            case 'Configurações':
              target = const ConfiguracoesPage();
              break;
            case 'Listar':
              target = const ListagensPage();
              break;
          }

          if (target != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => target!),
            );
          }
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [icon, const SizedBox(height: 8), Text(label)],
            ),
          ),
        ),
      ),
    );
  }
}
