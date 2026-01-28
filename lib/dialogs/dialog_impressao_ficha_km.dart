import 'package:controle_frota/utils/gerar_ficha_km_pdf.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/viatura_model.dart';

enum _FiltroSituacao { ativas, oficina, baixadas, todas }

class DialogImpressaoFichaKm extends StatefulWidget {
  final List<Viatura> viaturas;

  const DialogImpressaoFichaKm({super.key, required this.viaturas});

  @override
  State<DialogImpressaoFichaKm> createState() => _DialogImpressaoFichaKmState();
}

class _DialogImpressaoFichaKmState extends State<DialogImpressaoFichaKm> {
  final _buscaCtrl = TextEditingController();

  _FiltroSituacao _filtro = _FiltroSituacao.ativas;

  // Seleção por "id" quando tiver; se id for null, cai num key único por texto.
  final Map<String, bool> _selecionados = {};

  @override
  void initState() {
    super.initState();
    // Por padrão: seleciona todas as ATIVAS.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selecionarTodasFiltradas();
    });
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _key(Viatura v) {
    final id = v.id;
    if (id != null) return 'id:$id';
    // fallback (se não tiver id ainda)
    return 'k:${v.numeroViatura}|${v.placa}|${v.modelo}|${v.tipo}|${v.situacao}';
  }

  bool _matchSituacao(Viatura v) {
    final s = (v.situacao).trim().toLowerCase();
    switch (_filtro) {
      case _FiltroSituacao.ativas:
        return s == 'ativa' || s == 'ativo';
      case _FiltroSituacao.oficina:
        return s.contains('oficina') ||
            s.contains('manutenção') ||
            s.contains('manutencao') ||
            s.contains('manut');
      case _FiltroSituacao.baixadas:
        return s.contains('baixad') ||
            s.contains('inativa') ||
            s.contains('inativo');
      case _FiltroSituacao.todas:
        return true;
    }
  }

  bool _matchBusca(Viatura v) {
    final q = _buscaCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;

    final n = v.numeroViatura.toLowerCase();
    final p = v.placa.toLowerCase();
    final m = v.modelo.toLowerCase();
    final t = v.tipo.toLowerCase();
    final s = v.situacao.toLowerCase();

    return n.contains(q) ||
        p.contains(q) ||
        m.contains(q) ||
        t.contains(q) ||
        s.contains(q);
  }

  List<Viatura> get _filtradas {
    final list = widget.viaturas
        .where((v) => _matchSituacao(v) && _matchBusca(v))
        .toList();

    list.sort((a, b) {
      // ordena por número, tentando int quando der
      final ai = int.tryParse(a.numeroViatura.replaceAll(RegExp(r'\D'), ''));
      final bi = int.tryParse(b.numeroViatura.replaceAll(RegExp(r'\D'), ''));
      if (ai != null && bi != null) return ai.compareTo(bi);
      return a.numeroViatura.compareTo(b.numeroViatura);
    });

    return list;
  }

  int get _totalSelecionadas {
    int c = 0;
    for (final v in widget.viaturas) {
      if ((_selecionados[_key(v)] ?? false) == true) c++;
    }
    return c;
  }

  void _selecionarTodasFiltradas() {
    final list = _filtradas;
    setState(() {
      for (final v in list) {
        _selecionados[_key(v)] = true;
      }
    });
  }

  void _limparSelecao() {
    setState(_selecionados.clear);
  }

  List<Viatura> _getSelecionadas() {
    final sel = widget.viaturas
        .where((v) => (_selecionados[_key(v)] ?? false) == true)
        .toList();

    sel.sort((a, b) => a.numeroViatura.compareTo(b.numeroViatura));
    return sel;
  }

  Future<void> _previewOuImprimir() async {
    final selecionadas = _getSelecionadas();

    if (selecionadas.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos 1 viatura para gerar a ficha.'),
        ),
      );
      return;
    }

    final pdfBytes = await GerarFichaKmPdf.gerar(viaturas: selecionadas);
    if (!mounted) return;

    await Printing.layoutPdf(
      name: 'FICHA_KM_${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
      onLayout: (_) async => pdfBytes,
    );

    if (!mounted) return;

    // Feedback visual para o usuário
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '📄 Ficha de KM gerada. Verifique a impressão ou a pasta de downloads.',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Fecha o dialog automaticamente após gerar
    Navigator.of(context).pop();
  }

  /// “Folha A4” simulada (com tamanho mínimo decente).
  /// - Se couber: mostra grande.
  /// - Se não couber: mantém proporção e deixa rolar (sem encolher demais).
  Widget _a4Sheet({required Widget child}) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final maxH = c.maxHeight;

        // A4 retrato: 1 : 1.414
        const ratio = 1.414;

        // Defina um "alvo" maior pra ficar confortável.
        // A folha tenta ficar com ~760px de largura (bom em desktop),
        // mas respeita o espaço disponível.
        double targetW = 760.0;

        // Se o espaço disponível for menor, ajusta
        double sheetW = targetW.clamp(520.0, maxW);
        double sheetH = sheetW * ratio;

        // Se altura não couber, reduz pela altura
        if (sheetH > maxH) {
          sheetH = maxH;
          sheetW = sheetH / ratio;
        }

        // Quando a tela for MUITO estreita, não deixa cair abaixo de 520,
        // e nesse caso usa scroll externo.
        final tooNarrow = maxW < 540 || maxH < 620;

        final sheet = Center(
          child: Container(
            width: sheetW,
            height: sheetH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset(0, 10),
                  color: Color(0x22000000),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
          ),
        );

        if (!tooNarrow) return sheet;

        // Se estiver apertado, centraliza e permite rolar sem “amassar” a folha.
        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 520),
                child: sheet,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rodapeResponsivo() {
    const dicaText =
        'Dica: deixe “Ativas” e use “Selecionar filtradas” para imprimir só o que está em operação.';

    final dica = Text(
      dicaText,
      style: const TextStyle(fontSize: 12, color: Colors.black54),
      softWrap: true,
      overflow: TextOverflow.visible,
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _previewOuImprimir,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Pré-visualizar / Imprimir'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 640;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dica,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: dica),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;

    final media = MediaQuery.of(context).size;

    // Dialog maior (quase tela toda, mas com borda)
    final dialogW = (media.width * 0.92).clamp(780.0, 1200.0);
    final dialogH = (media.height * 0.90).clamp(620.0, 900.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: _a4Sheet(
          child: Column(
            children: [
              // Cabeçalho
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Row(
                  children: [
                    const Icon(Icons.print_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Imprimir Ficha de Atualização de KM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Corpo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filtros e busca
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _FiltroChip(
                            label: 'Ativas',
                            selected: _filtro == _FiltroSituacao.ativas,
                            onTap: () {
                              setState(() => _filtro = _FiltroSituacao.ativas);
                              _selecionarTodasFiltradas();
                            },
                          ),
                          _FiltroChip(
                            label: 'Oficina',
                            selected: _filtro == _FiltroSituacao.oficina,
                            onTap: () => setState(
                              () => _filtro = _FiltroSituacao.oficina,
                            ),
                          ),
                          _FiltroChip(
                            label: 'Baixadas',
                            selected: _filtro == _FiltroSituacao.baixadas,
                            onTap: () => setState(
                              () => _filtro = _FiltroSituacao.baixadas,
                            ),
                          ),
                          _FiltroChip(
                            label: 'Todas',
                            selected: _filtro == _FiltroSituacao.todas,
                            onTap: () =>
                                setState(() => _filtro = _FiltroSituacao.todas),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 360, // um pouco maior
                            child: TextField(
                              controller: _buscaCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                hintText:
                                    'Buscar por nº, placa, modelo, tipo ou situação',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Resumo + ações rápidas
                      Row(
                        children: [
                          Text(
                            'Filtradas: ${filtradas.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Selecionadas: $_totalSelecionadas',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _selecionarTodasFiltradas,
                            icon: const Icon(Icons.done_all),
                            label: const Text('Selecionar filtradas'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _limparSelecao,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Limpar'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Lista
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: filtradas.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nenhuma viatura encontrada com esses filtros.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  itemCount: filtradas.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final v = filtradas[i];
                                    final k = _key(v);
                                    final checked = _selecionados[k] ?? false;

                                    return CheckboxListTile(
                                      value: checked,
                                      onChanged: (val) {
                                        setState(
                                          () => _selecionados[k] = val ?? false,
                                        );
                                      },
                                      title: Row(
                                        children: [
                                          SizedBox(
                                            width: 72,
                                            child: Text(
                                              v.numeroViatura,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              v.modelo,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${v.placa} • ${v.tipo} • ${v.situacao} • KM: ${v.kmAtual}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      dense: true,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Rodapé (sem overflow e adaptável)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: _rodapeResponsivo(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.black87 : Colors.black26),
          color: selected ? Colors.black.withOpacity(0.06) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }
}
