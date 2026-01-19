import 'package:controle_frota/components/header_viaturas.dart';
import 'package:controle_frota/components/manutencao_form.dart';
import 'package:controle_frota/dialogs/dialog_agendada.dart';
import 'package:controle_frota/dialogs/dialog_concluida.dart';
import 'package:controle_frota/dialogs/dialog_detalhes_manutencao.dart'
    show showDialogDetalhesManutencao;
import 'package:controle_frota/views/historico_manutencao_page.dart';
import 'package:flutter/material.dart';
import '../models/viatura_model.dart';
import '../models/manutencao_model.dart';
import '../db/database_helper.dart';
import 'package:intl/intl.dart';

class ListManutencoesPage extends StatefulWidget {
  final Viatura viatura;
  final int? manutencaoIdDestacada;

  const ListManutencoesPage({
    super.key,
    required this.viatura,
    this.manutencaoIdDestacada,
  });

  @override
  State<ListManutencoesPage> createState() => _ListManutencoesPageState();
}

class _ListManutencoesPageState extends State<ListManutencoesPage> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {}; // id -> key

  List<Manutencao> _manutencoes = [];
  String _statusFiltro = 'Todas';

  int? _destacadaId; // id que veio da tela anterior
  bool _destacadaPulsando = false; // liga/desliga o efeito visual

  @override
  void initState() {
    super.initState();
    _destacadaId = widget.manutencaoIdDestacada;
    _carregarManutencoes();
  }

  String _formatarData(String dataString) {
    try {
      final formato = DateFormat('dd/MM/yyyy');
      final data = formato.parse(dataString);
      return formato.format(data);
    } catch (_) {
      return dataString;
    }
  }

  Future<void> _carregarManutencoes() async {
    final db = await DatabaseHelper.getDatabase();
    final results = await db.query(
      'manutencoes',
      where: 'viaturaId = ?',
      whereArgs: [widget.viatura.id],
      orderBy: '''
        CASE WHEN status = 'Concluída' THEN 1 ELSE 0 END,
        dataAlvo ASC
      ''',
    );
    setState(() {
      _manutencoes = results.map((e) => Manutencao.fromMap(e)).toList();
    });

    // Depois que renderizar, rola até a destacada e aplica o “flash”
    if (_destacadaId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _irParaDestacada());
    }
  }

  void _irParaDestacada() {
    final id = _destacadaId;
    if (id == null) return;

    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        alignment: 0.15, // deixa um respiro acima do item
        curve: Curves.easeOutCubic,
      );
      setState(() => _destacadaPulsando = true);
      Future.delayed(
        const Duration(seconds: 2),
        () => mounted ? setState(() => _destacadaPulsando = false) : null,
      );
    }
  }

  Future<void> _confirmarExclusao(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir manutenção'),
        content: const Text('Tem certeza que deseja excluir esta manutenção?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DatabaseHelper.getDatabase();
      await db.delete('manutencoes', where: 'id = ?', whereArgs: [id]);
      _carregarManutencoes();
    }
  }

  List<Manutencao> get _manutencoesFiltradas {
    if (_statusFiltro == 'Todas') return _manutencoes;
    return _manutencoes
        .where((m) => m.status.toLowerCase() == _statusFiltro.toLowerCase())
        .toList();
  }

  Future<void> iniciarManutencao(Manutencao manutencao) async {
    final db = await DatabaseHelper.getDatabase();
    manutencao.status = 'Em andamento';
    await db.update(
      'manutencoes',
      manutencao.toMap(),
      where: 'id = ?',
      whereArgs: [manutencao.id],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manutenções da Viatura')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderViatura(viatura: widget.viatura),
            const SizedBox(height: 12),

            // Botão rápido para focar a manutenção destacada (se houver)
            if (_destacadaId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _irParaDestacada,
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('Ir para a manutenção selecionada'),
                ),
              ),

            const SizedBox(height: 12),

            Row(
              children: ['Todas', 'Agendada', 'Em andamento', 'Concluída']
                  .map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: _statusFiltro == status,
                        onSelected: (_) {
                          setState(() => _statusFiltro = status);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _manutencoesFiltradas.isEmpty
                  ? const Center(child: Text('Nenhuma manutenção encontrada.'))
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _manutencoesFiltradas.length,
                      itemBuilder: (_, index) {
                        final m = _manutencoesFiltradas[index];

                        // chave única por item para permitir o ensureVisible
                        final key = _itemKeys.putIfAbsent(
                          m.id!,
                          () => GlobalKey(),
                        );

                        final bool isDestacada = m.id == _destacadaId;

                        return AnimatedContainer(
                          key: key,
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isDestacada && _destacadaPulsando
                                ? Border.all(
                                    color: const Color(0xFFFFB020), // âmbar
                                    width: 2,
                                  )
                                : null,
                            boxShadow: [
                              if (isDestacada && _destacadaPulsando)
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFB020,
                                  ).withOpacity(.25),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: (m.status == 'Concluída')
                                ? Colors.grey[200]
                                : null,
                            child: ListTile(
                              onTap: () {
                                showDialogDetalhesManutencao(context, m);
                              },
                              leading: const Icon(Icons.build_circle),
                              title: Text(m.descricao),
                              subtitle: Text(
                                'Data: ${_formatarData(m.data)}    KM: ${m.km}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  m.status == 'Concluída'
                                      ? TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    HistoricoManutencaoPage(
                                                      manutencao: m,
                                                    ),
                                              ),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.all(8),
                                            foregroundColor:
                                                Colors.blue.shade700,
                                          ),
                                          child: Icon(
                                            Icons.print,
                                            color: Colors.blue.shade700,
                                            size: 28,
                                          ),
                                        )
                                      : PopupMenuButton<String>(
                                          tooltip:
                                              'Alterar status da manutenção',
                                          onSelected: (String novoStatus) async {
                                            bool confirmar = false;

                                            if (novoStatus == 'Agendada') {
                                              final manutencaoAtualizada =
                                                  await showDialogAgendada(
                                                    context,
                                                    m,
                                                  );

                                              if (manutencaoAtualizada !=
                                                  null) {
                                                await DatabaseHelper.agendarManutencao(
                                                  id: manutencaoAtualizada.id!,
                                                  dataAlvo:
                                                      manutencaoAtualizada
                                                          .dataAlvo ??
                                                      '',
                                                  local:
                                                      manutencaoAtualizada
                                                          .local ??
                                                      '',
                                                  observacao:
                                                      manutencaoAtualizada
                                                          .observacao ??
                                                      '',
                                                );
                                                confirmar = true;
                                              } else {
                                                return;
                                              }
                                            } else if (novoStatus ==
                                                'Em andamento') {
                                              confirmar =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text(
                                                        'Iniciar Manutenção',
                                                      ),
                                                      content: const Text(
                                                        'Deseja marcar como em andamento?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancelar',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Confirmar',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ) ??
                                                  false;
                                            } else if (novoStatus ==
                                                'Concluída') {
                                              confirmar =
                                                  await showDialogConcluida(
                                                    context,
                                                    m,
                                                  );
                                            }

                                            if (confirmar) {
                                              final db =
                                                  await DatabaseHelper.getDatabase();

                                              await db.update(
                                                'manutencoes',
                                                {'status': novoStatus},
                                                where: 'id = ?',
                                                whereArgs: [m.id],
                                              );

                                              String novaSituacaoViatura;
                                              if (novoStatus ==
                                                  'Em andamento') {
                                                novaSituacaoViatura = 'Oficina';
                                              } else if (novoStatus ==
                                                  'Concluída') {
                                                novaSituacaoViatura = 'Ativa';
                                              } else {
                                                novaSituacaoViatura =
                                                    widget.viatura.situacao;
                                              }

                                              await db.update(
                                                'viaturas',
                                                {
                                                  'situacao':
                                                      novaSituacaoViatura,
                                                },
                                                where: 'id = ?',
                                                whereArgs: [widget.viatura.id],
                                              );

                                              _carregarManutencoes();
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'Agendada',
                                              child: Text('Agendada'),
                                            ),
                                            PopupMenuItem(
                                              value: 'Em andamento',
                                              child: Text('Em andamento'),
                                            ),
                                            PopupMenuItem(
                                              value: 'Concluída',
                                              child: Text('Concluída'),
                                            ),
                                          ],
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: m.status == 'Em andamento'
                                                  ? Colors.blue[100]
                                                  : m.status == 'Agendada'
                                                  ? Colors.orange[100]
                                                  : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  (m.status.isEmpty ||
                                                          m.status == 'Próxima')
                                                      ? 'Definir'
                                                      : m.status,
                                                  style: TextStyle(
                                                    color:
                                                        m.status ==
                                                            'Em andamento'
                                                        ? Colors.blue[800]
                                                        : m.status == 'Agendada'
                                                        ? Colors.orange[800]
                                                        : Colors.grey[800],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.arrow_drop_down,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed:
                                        (m.status == 'Em andamento' ||
                                            m.status == 'Concluída')
                                        ? null
                                        : () {
                                            final formKey =
                                                GlobalKey<
                                                  ManutencaoFormState
                                                >();
                                            showDialog(
                                              context: context,
                                              builder: (_) => Dialog(
                                                insetPadding:
                                                    const EdgeInsets.all(32),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: SizedBox(
                                                  width: 850,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          32,
                                                        ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Text(
                                                          'Editar Manutenção',
                                                          style: TextStyle(
                                                            fontSize: 22,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 24,
                                                        ),
                                                        ManutencaoForm(
                                                          key: formKey,
                                                          viatura:
                                                              widget.viatura,
                                                          manutencao: m,
                                                          onSaved: () {
                                                            _carregarManutencoes();
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(
                                                          height: 24,
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          children: [
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                  ),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                      0xFF1A2B7B,
                                                                    ),
                                                              ),
                                                              child: const Text(
                                                                'Cancelar',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  formKey
                                                                      .currentState
                                                                      ?.salvar(),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                      0xFF1A2B7B,
                                                                    ),
                                                              ),
                                                              child: const Text(
                                                                'Salvar',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed:
                                        (m.status == 'Em andamento' ||
                                            m.status == 'Concluída')
                                        ? null
                                        : () => _confirmarExclusao(m.id!),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
