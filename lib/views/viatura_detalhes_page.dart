import 'package:controle_frota/db/database_helper.dart';
import 'package:controle_frota/dialogs/editar_viatura_dialog.dart';
import 'package:controle_frota/models/viatura_model.dart';
import 'package:controle_frota/views/cadastro_manutencao_page.dart';
import 'package:flutter/material.dart';

class ViaturaDetalhesPage extends StatefulWidget {
  final Map<String, dynamic> viatura;

  const ViaturaDetalhesPage({super.key, required this.viatura});

  @override
  State<ViaturaDetalhesPage> createState() => _ViaturaDetalhesPageState();
}

class _ViaturaDetalhesPageState extends State<ViaturaDetalhesPage> {
  // Cópia mutável local (evita QueryRow read-only)
  late Map<String, dynamic> _viatura;

  // Flag para avisar a tela anterior que houve mudança (edição/exclusão)
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _viatura = Map<String, dynamic>.from(widget.viatura);
  }

  // --- helpers de cor para badge (mesmo padrão da Manutenções) ---
  Color _statusFg(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'concluída':
      case 'concluida':
        return const Color(0xFF166534);
      case 'em andamento':
        return const Color(0xFF0B57D0);
      case 'agendada':
        return const Color(0xFF445A6A);
      default:
        return const Color(0xFF374151);
    }
  }

  Color _statusBg(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'concluída':
      case 'concluida':
        return const Color(0xFFD1FAE5);
      case 'em andamento':
        return const Color(0xFFE8F0FE);
      case 'agendada':
        return const Color(0xFFEFF3F4);
      default:
        return const Color(0xFFEFF3F4);
    }
  }

  Icon _leadingIcon(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'concluída':
      case 'concluida':
        return const Icon(
          Icons.check_circle,
          size: 28,
          color: Color(0xFF166534),
        );
      case 'em andamento':
        return const Icon(
          Icons.build_circle_rounded,
          size: 28,
          color: Color(0xFF0B57D0),
        );
      case 'agendada':
        return const Icon(Icons.schedule, size: 28, color: Color(0xFF445A6A));
      default:
        return const Icon(Icons.handyman_rounded, size: 28, color: Colors.grey);
    }
  }

  // --------- EXCLUSÃO COM CONFIRMAÇÃO E TRAVA ----------
  Future<void> _confirmarExclusaoViatura() async {
    final id = _viatura['id'] as int;
    final numero = (_viatura['numeroViatura'] ?? '').toString();
    final placa = (_viatura['placa'] ?? '').toString();

    final manutCount = await DatabaseHelper.contarManutencoesDaViatura(id);
    if (!mounted) return;

    if (manutCount > 0) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Não foi possível excluir'),
          content: Text(
            'A viatura $numero • placa $placa possui $manutCount manutenção(ões) cadastrada(s). '
            'Exclua ou transfira as manutenções antes de excluir a viatura.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Excluir viatura?'),
        content: Text(
          'Viatura $numero • Placa $placa\n\nEsta ação não pode ser desfeita.',
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
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final ok = await DatabaseHelper.excluirViaturaSeSemManutencoes(id);
    if (!mounted) return;

    if (ok) {
      _changed = true;
      // Importante: não mostrar SnackBar aqui, pois a tela vai fechar agora
      Navigator.pop(context, true); // volta informando mudança
    } else {
      await showDialog(
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
  }
  // ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final v = _viatura;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed); // devolve se houve alteração
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Viatura ${v['numeroViatura']}')),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informações da Viatura',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _infoTile('Placa', (v['placa'] ?? '').toString()),
              _infoTile('Modelo', (v['modelo'] ?? '').toString()),
              _infoTile('KM Atual', '${v['kmAtual']} km'),
              _infoTile('Situação', (v['situacao'] ?? '').toString()),

              const SizedBox(height: 12),

              Row(
                children: [
                  // EDITAR
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                    onPressed: () async {
                      final vv = Viatura(
                        id: v['id'],
                        numeroViatura: v['numeroViatura'],
                        placa: v['placa'],
                        modelo: v['modelo'],
                        kmAtual: v['kmAtual'],
                        tipo: v['tipo'],
                        situacao: v['situacao'],
                      );

                      final dados = await showDialog<Map<String, dynamic>>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => EditarViaturaDialog(viatura: vv),
                      );

                      if (dados == null) return;

                      // ---------- VALIDAÇÕES ----------
                      final id = vv.id!;
                      final placa = (dados['placa'] as String).toUpperCase();
                      final numero = dados['numeroViatura'] as String;
                      final modelo = dados['modelo'] as String;
                      final kmNovo = dados['kmAtual'] as int;
                      final tipo = (dados['tipo'] as String?)?.trim();
                      final situacao = (dados['situacao'] as String);

                      final duplicada = await DatabaseHelper.existePlaca(
                        placa,
                        ignorarId: id,
                      );
                      if (duplicada) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Já existe uma viatura com esta placa.',
                            ),
                          ),
                        );
                        return;
                      }

                      final kmAtualAnterior =
                          (_viatura['kmAtual'] as int?) ?? 0;
                      final kmMaxManut = await DatabaseHelper.maxKmRegistrado(
                        id,
                      );
                      final kmMinAceito = (kmAtualAnterior > kmMaxManut)
                          ? kmAtualAnterior
                          : kmMaxManut;

                      if (kmNovo < kmMinAceito) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'KM inválido. O KM não pode ser menor que $kmMinAceito (histórico/atual).',
                            ),
                          ),
                        );
                        return;
                      }

                      // ---------- SALVAR ----------
                      await DatabaseHelper.atualizarViatura(
                        id: id,
                        numeroViatura: numero,
                        placa: placa,
                        modelo: modelo,
                        kmAtual: kmNovo,
                        tipo: (tipo == null || tipo.isEmpty) ? null : tipo,
                        situacao: situacao,
                        ultimaAtualizacaoKm: DateTime.now().toIso8601String(),
                      );

                      // ---------- REFLETIR NA UI ----------
                      if (!mounted) return;
                      setState(() {
                        _viatura['numeroViatura'] = numero;
                        _viatura['placa'] = placa;
                        _viatura['modelo'] = modelo;
                        _viatura['kmAtual'] = kmNovo;
                        _viatura['tipo'] = tipo ?? '';
                        _viatura['situacao'] = situacao;
                        _changed =
                            true; // informa alteração para página anterior
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Viatura atualizada com sucesso.'),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 12),

                  // EXCLUIR
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Excluir'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: _confirmarExclusaoViatura,
                  ),
                ],
              ),

              const Divider(height: 32),

              // Título + ação
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manutenções cadastradas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CadastroManutencaoPage(
                            viaturaSelecionada: Viatura(
                              id: v['id'],
                              numeroViatura: v['numeroViatura'],
                              placa: v['placa'],
                              modelo: v['modelo'],
                              kmAtual: v['kmAtual'],
                              tipo: v['tipo'],
                              situacao: v['situacao'],
                            ),
                          ),
                        ),
                      );
                      setState(() {}); // recarrega a lista local ao voltar
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('NOVA MANUTENÇÃO'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Lista
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _buscarManutencoes(v['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return const Center(
                        child: Text('Erro ao carregar manutenções'),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.info_outline,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Nenhuma manutenção cadastrada',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    final manutencoes = snapshot.data!;
                    return ListView.builder(
                      itemCount: manutencoes.length,
                      itemBuilder: (context, index) {
                        final m = manutencoes[index];
                        final String titulo =
                            (m['descricao'] ?? 'Sem descrição').toString();
                        final String dataAlvo = (m['dataAlvo'] ?? '')
                            .toString();
                        final String kmAlvo = (m['kmAlvo'] ?? '').toString();
                        final String status = (m['status'] ?? 'Pendente')
                            .toString();

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: _leadingIcon(status),
                                  ),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          titulo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'KM alvo: $kmAlvo • Data: $dataAlvo',
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
                                  Container(
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _buscarManutencoes(int viaturaId) {
    return DatabaseHelper.getManutencoesPorViatura(viaturaId);
  }
}
