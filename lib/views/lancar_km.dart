import 'dart:async';
import 'package:controle_frota/dialogs/mostrar_dialog_animado.dart';
import 'package:controle_frota/utils/exportar_km_csv.dart';
import 'package:controle_frota/utils/importar_km_csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../models/viatura_model.dart';
import '../db/database_helper.dart';

class LancarKmPage extends StatefulWidget {
  const LancarKmPage({super.key});

  @override
  State<LancarKmPage> createState() => _LancarKmPageState();
}

class _LancarKmPageState extends State<LancarKmPage> {
  // Configurações
  static const int _itensPorPagina = 10;
  static const int _saltoExagerado = 100000; // alerta para jumps absurdos
  static const Duration _debounceBusca = Duration(milliseconds: 300);

  // Estado
  List<Viatura> _viaturas = [];
  // Controllers e validação para TODA a lista (não só a página)
  final Map<int, TextEditingController> _kmControllers = {};
  final Map<int, bool> _validKm = {};
  final Map<int, int> _kmOriginal = {}; // para saber se houve alteração

  String _filtroBusca = '';
  String _filtroSituacao = 'Não Atualizadas';
  int _paginaAtual = 0;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _carregarViaturas();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _kmControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _hojeYmd() {
    final agora = DateTime.now();
    return '${agora.day.toString().padLeft(2, '0')}/'
        '${agora.month.toString().padLeft(2, '0')}/'
        '${agora.year.toString().padLeft(4, '0')}';
  }

  Future<void> _carregarViaturas() async {
    final db = await DatabaseHelper.getDatabase();
    List<Map<String, dynamic>> results;

    final hojeFormatado = _hojeYmd();

    if (_filtroSituacao == 'Todas') {
      results = await db.query('viaturas', orderBy: 'numeroViatura ASC');
    } else if (_filtroSituacao == 'Atualizadas') {
      results = await db.query(
        'viaturas',
        // coluna salva como dd/MM/yyyy -> compare os 10 primeiros chars
        where: "substr(ultimaAtualizacaoKm,1,10) = ?",
        whereArgs: [hojeFormatado],
        orderBy: 'numeroViatura ASC',
      );
    } else if (_filtroSituacao == 'Não Atualizadas') {
      results = await db.query(
        'viaturas',
        where:
            "ultimaAtualizacaoKm IS NULL OR substr(ultimaAtualizacaoKm,1,10) != ?",
        whereArgs: [hojeFormatado],
        orderBy: 'numeroViatura ASC',
      );
    } else {
      // mapeia chips para os status do banco
      var s = _filtroSituacao.toLowerCase();
      if (s == 'oficina') s = 'em manutenção';
      if (s == 'reservada') s = 'indisponível';

      results = await db.query(
        'viaturas',
        where: 'LOWER(situacao) = ?',
        whereArgs: [s],
        orderBy: 'numeroViatura ASC',
      );
    }

    final listaFiltrada = results
        .map((e) => Viatura.fromMap(e))
        .where(
          (v) =>
              v.numeroViatura.toLowerCase().contains(
                _filtroBusca.toLowerCase(),
              ) ||
              v.placa.toLowerCase().contains(_filtroBusca.toLowerCase()),
        )
        .toList();

    // Inicializa/preserva controllers para TODAS as viaturas da lista
    for (final v in listaFiltrada) {
      if (!_kmControllers.containsKey(v.id)) {
        _kmControllers[v.id!] = TextEditingController(
          text: v.kmAtual.toString(),
        );
        _kmOriginal[v.id!] = v.kmAtual;
      } else {
        // se trocar filtro e já tinha controller, mantém o que o usuário digitou
      }
      _validKm[v.id!] = _ehKmValidoPara(v, _kmControllers[v.id!]!.text);
    }

    // Se a página atual ficou "fora" (ex.: filtro diminuiu a lista), volta para 0
    final maxPagina = (listaFiltrada.length / _itensPorPagina).ceil();
    if (_paginaAtual >= maxPagina && maxPagina > 0) {
      _paginaAtual = 0;
    }

    setState(() {
      _viaturas = listaFiltrada;
    });
  }

  bool _ehKmValidoPara(Viatura v, String input) {
    final novoKm = int.tryParse(input.trim()) ?? v.kmAtual;
    return novoKm >= v.kmAtual;
  }

  void _onBuscaChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceBusca, () {
      setState(() {
        _filtroBusca = value;
        _paginaAtual = 0;
      });
      _carregarViaturas();
    });
  }

  void _onEditarKm(Viatura v, String value) {
    setState(() {
      _validKm[v.id!] = _ehKmValidoPara(v, value);
    });
  }

  Future<void> _salvarUm(Viatura v) async {
    final controller = _kmControllers[v.id]!;
    final texto = controller.text.trim();

    final novoKm = int.tryParse(texto);
    if (novoKm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Informe um KM válido.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (novoKm < v.kmAtual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ O novo KM não pode ser menor que o atual.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Alerta se salto muito grande
    if ((novoKm - v.kmAtual) > _saltoExagerado) {
      final confirmar =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Salto de KM muito grande'),
              content: Text(
                'Você está lançando +${novoKm - v.kmAtual} km.\nDeseja confirmar mesmo assim?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmar) return;
    }

    final db = await DatabaseHelper.getDatabase();
    final hojeFormatado = _hojeYmd();

    await db.update(
      'viaturas',
      {'kmAtual': novoKm, 'ultimaAtualizacaoKm': hojeFormatado},
      where: 'id = ?',
      whereArgs: [v.id],
    );

    _kmOriginal[v.id!] = novoKm;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ KM atualizado!'),
        backgroundColor: Colors.green,
      ),
    );

    await _carregarViaturas();
  }

  Future<void> _atualizarKmEmLote() async {
    // Validação geral
    for (final v in _viaturas) {
      final c = _kmControllers[v.id]!;
      if (!_ehKmValidoPara(v, c.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Corrija os campos em vermelho antes de salvar.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Checa saltos absurdos e confirma
    int maiorSalto = 0;
    for (final v in _viaturas) {
      final novoKm =
          int.tryParse(_kmControllers[v.id]!.text.trim()) ?? v.kmAtual;
      final salto = novoKm - v.kmAtual;
      if (salto > maiorSalto) maiorSalto = salto;
    }
    if (maiorSalto > _saltoExagerado) {
      final ok =
          await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Grandes alterações detectadas'),
              content: Text(
                'Existe(m) lançamento(s) acima de +$_saltoExagerado km.\nDeseja prosseguir mesmo assim?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Prosseguir'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }

    final db = await DatabaseHelper.getDatabase();
    final hojeFormatado = _hojeYmd();

    int atualizados = 0;

    for (final v in _viaturas) {
      final id = v.id!;
      final novoKm = int.tryParse(_kmControllers[id]!.text.trim()) ?? v.kmAtual;

      if (novoKm > v.kmAtual) {
        await db.update(
          'viaturas',
          {'kmAtual': novoKm, 'ultimaAtualizacaoKm': hojeFormatado},
          where: 'id = ?',
          whereArgs: [id],
        );
        _kmOriginal[id] = novoKm;
        atualizados++;
      }
    }

    if (atualizados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $atualizados viatura(s) atualizada(s) com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ℹ️ Nenhuma alteração detectada.'),
          backgroundColor: Colors.grey,
        ),
      );
    }

    await _carregarViaturas();
  }

  void _exportarCsvViaturas() async {
    final caminho = await ExportarKmCsv.exportar();
    if (!mounted) return;
    if (caminho != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📁 CSV exportado para: $caminho'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Falha ao exportar CSV'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _importarCsvViaturas() async {
    final path = await ImportarKmCsv.selecionarArquivoCsv();
    if (path == null || !mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Importação cancelada.')));
      return;
    }

    mostrarDialogoAnimado(
      context: context,
      titulo: 'Atualizando quilometragem...',
      lottieAsset: 'assets/lottie/loading.json',
    );

    final resultado = await ImportarKmCsv.importarComCaminho(path);

    if (Navigator.canPop(context)) Navigator.of(context).pop();

    await mostrarDialogoAnimado(
      context: context,
      titulo: resultado,
      lottieAsset: resultado.startsWith('✅')
          ? 'assets/lottie/success.json'
          : 'assets/lottie/warning.json',
      tempoAutoFechamento: const Duration(seconds: 3),
    );

    // 👇 força atualização de todos os campos com os novos valores do banco
    setState(() {
      _kmControllers.clear();
      _validKm.clear();
      _kmOriginal.clear();
      _paginaAtual = 0;
    });

    await _carregarViaturas();
  }

  @override
  Widget build(BuildContext context) {
    final totalPaginas = (_viaturas.length / _itensPorPagina).ceil();
    final paginaViaturas = _viaturas
        .skip(_paginaAtual * _itensPorPagina)
        .take(_itensPorPagina)
        .toList();

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Busca
            TextField(
              decoration: InputDecoration(
                labelText: 'Buscar por número ou placa',
                border: const OutlineInputBorder(),
                suffixIcon: _filtroBusca.isEmpty
                    ? const Icon(Icons.search)
                    : IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _filtroBusca = '';
                            _paginaAtual = 0;
                          });
                          _carregarViaturas();
                        },
                      ),
              ),
              onChanged: _onBuscaChanged,
            ),
            const SizedBox(height: 16),

            // Filtros
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      'Não Atualizadas',
                      'Atualizadas',
                      'Ativa',
                      'Oficina',
                      'Reservada',
                      'Todas',
                    ].map((status) {
                      final selecionado = _filtroSituacao == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: selecionado,
                          selectedColor: Colors.blue.shade100,
                          labelStyle: TextStyle(
                            color: selecionado
                                ? Colors.blue.shade900
                                : Colors.black,
                            fontWeight: selecionado
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _filtroSituacao = status;
                              _paginaAtual = 0;
                            });
                            _carregarViaturas();
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Ações CSV
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _exportarCsvViaturas,
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar Planilha'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _importarCsvViaturas,
                  icon: const Icon(Icons.upload),
                  label: const Text('Importar Planilha'),
                ),
                const Spacer(),
                // Info de quantos registros
                if (_viaturas.isNotEmpty)
                  Text(
                    'Exibindo ${paginaViaturas.length} de ${_viaturas.length}',
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Lista
            Expanded(
              child: paginaViaturas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/lottie/database.json',
                            width: 200,
                            repeat: true,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filtroSituacao == 'Não Atualizadas'
                                ? 'Todas as viaturas já foram atualizadas hoje!'
                                : 'Nenhuma viatura encontrada.',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: paginaViaturas.length,
                      itemBuilder: (_, index) {
                        final v = paginaViaturas[index];
                        final c = _kmControllers[v.id]!;
                        final valido = _validKm[v.id] ?? true;
                        final atualizadoHoje =
                            (v is Viatura) &&
                            (v.id != null) &&
                            false; // placeholder (não temos o campo carregado aqui)

                        // Badge "Hoje" via ultimaAtualizacaoKm comparando com hoje
                        // Como não está no modelo, vamos usar a abordagem com uma consulta simples no texto do controller:
                        final jaAtualizadoHoje =
                            _kmOriginal[v.id!] != null &&
                            _kmOriginal[v.id!] == int.tryParse(c.text);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Identificação
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Viatura ${v.numeroViatura}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (jaAtualizadoHoje)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Hoje',
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        v.placa,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'KM atual: ${_kmOriginal[v.id!] ?? v.kmAtual}',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Campo KM + botão salvar
                                SizedBox(
                                  width: 220,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: c,
                                          keyboardType: TextInputType.number,
                                          onChanged: (t) => _onEditarKm(v, t),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          style: TextStyle(
                                            color: valido
                                                ? Colors.black
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Novo KM',
                                            labelStyle: TextStyle(
                                              color: valido
                                                  ? Colors.black
                                                  : Colors.red,
                                            ),
                                            border: const OutlineInputBorder(),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: valido
                                                    ? Colors.grey.shade400
                                                    : Colors.red,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                color: valido
                                                    ? Colors.blue
                                                    : Colors.red,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Salvar apenas esta viatura',
                                        child: ElevatedButton(
                                          onPressed: valido
                                              ? () => _salvarUm(v)
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.save_as,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            if (totalPaginas > 1) ...[
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(totalPaginas, (index) {
                    final isSel = index == _paginaAtual;
                    return OutlinedButton(
                      onPressed: () => setState(() => _paginaAtual = index),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        backgroundColor: isSel ? Colors.blue : Colors.white,
                        side: BorderSide(
                          color: isSel ? Colors.blue : Colors.grey.shade400,
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
                          fontWeight: isSel
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Salvar Todos
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _atualizarKmEmLote,
                icon: const Icon(Icons.save_alt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2B7B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                ),
                label: const Text(
                  'Salvar Todos',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
