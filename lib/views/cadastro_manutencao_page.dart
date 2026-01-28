import 'package:controle_frota/views/list_manutencoes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/viatura_model.dart';
import '../models/manutencao_model.dart';

/// Letras em maiúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class CadastroManutencaoPage extends StatefulWidget {
  final Viatura? viaturaSelecionada;
  const CadastroManutencaoPage({super.key, this.viaturaSelecionada});

  @override
  State<CadastroManutencaoPage> createState() => _CadastroManutencaoPageState();
}

class _CadastroManutencaoPageState extends State<CadastroManutencaoPage> {
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  final _dataController = TextEditingController();
  final _buscaController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _kmAlvoController = TextEditingController();
  DateTime? _dataSelecionada; // OPCIONAL

  List<Viatura> _viaturas = [];
  Viatura? _viaturaSelecionada;

  bool get _podeSalvar {
    // Data NÃO é obrigatória
    return _viaturaSelecionada != null &&
        _descricaoController.text.trim().isNotEmpty &&
        _kmAlvoController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _carregarViaturas().then((_) {
      if (widget.viaturaSelecionada != null) {
        _viaturaSelecionada = widget.viaturaSelecionada;
        _buscaController.text =
            '${widget.viaturaSelecionada!.numeroViatura} - ${widget.viaturaSelecionada!.placa}';
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _descricaoController.dispose();
    _kmAlvoController.dispose();
    _dataController.dispose(); // <-- novo
    super.dispose();
  }

  Future<void> _carregarViaturas() async {
    final db = await DatabaseHelper.getDatabase();
    final results = await db.query('viaturas', orderBy: 'numeroViatura ASC');
    setState(() {
      _viaturas = results.map((v) => Viatura.fromMap(v)).toList();
    });
  }

  Future<bool> _existeDuplicata({
    required int viaturaId,
    required String descricaoNormalizadaLower,
    required String dataAlvoStr, // pode ser ''
  }) async {
    final db = await DatabaseHelper.getDatabase();
    final res = await db.query(
      'manutencoes',
      where:
          'viaturaId = ? AND LOWER(descricao) = ? AND dataAlvo = ? AND status != ?',
      whereArgs: [
        viaturaId,
        descricaoNormalizadaLower,
        dataAlvoStr,
        'Concluída',
      ],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  void _salvarManutencao() async {
    // 1) Validação dos campos do formulário
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corrija os campos destacados antes de salvar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2) Viatura obrigatória
    if (_viaturaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma viatura antes de salvar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3) KM alvo numérico
    final kmAlvo = int.tryParse(_kmAlvoController.text);
    if (kmAlvo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um KM válido (apenas números).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4) KM alvo >= KM atual
    if (kmAlvo < _viaturaSelecionada!.kmAtual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O KM da manutenção ($kmAlvo) não pode ser menor que o KM atual da viatura (${_viaturaSelecionada!.kmAtual}).',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final db = await DatabaseHelper.getDatabase();

    // 5) Data (opcional)
    final String dataAlvoStr = (_dataSelecionada == null)
        ? ''
        : DateFormat('dd/MM/yyyy').format(_dataSelecionada!);

    // 6) Normalização de descrição
    final descricaoNormalizada = _descricaoController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final descricaoLower = descricaoNormalizada.toLowerCase();

    // 7) Duplicidade (considera data vazia quando sem data)
    final jaExiste = await _existeDuplicata(
      viaturaId: _viaturaSelecionada!.id!,
      descricaoNormalizadaLower: descricaoLower,
      dataAlvoStr: dataAlvoStr,
    );
    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Já existe uma manutenção com mesma descrição e data (ou sem data) para esta viatura.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 8) INSERIR SEMPRE COMO 'Pendente'
    final manutencao = Manutencao(
      viaturaId: _viaturaSelecionada!.id!,
      descricao: descricaoNormalizada,
      km: kmAlvo,
      kmAlvo: kmAlvo,
      data: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      dataAlvo: dataAlvoStr, // pode ser ''
      status: 'Pendente', // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<< FIX AQUI
    );

    try {
      await db.insert('manutencoes', manutencao.toMap());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manutenção cadastrada com sucesso!')),
      );

      setState(() {
        _descricaoController.clear();
        _kmAlvoController.clear();
        _buscaController.clear();
        _viaturaSelecionada = null;
        _dataSelecionada = null;
        _autoValidateMode = AutovalidateMode.disabled;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmarSalvarManutencao() async {
    // Liga autovalidação a partir daqui
    setState(() {
      _autoValidateMode = AutovalidateMode.always;
    });

    final formValido = _formKey.currentState!.validate();

    // Data segue OPCIONAL
    if (!formValido || _viaturaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha os campos obrigatórios e selecione a viatura.',
          ),
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cadastro'),
        content: const Text('Deseja realmente cadastrar esta manutenção?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2B7B),
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      _salvarManutencao();
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _dataSelecionada = picked);
      _dataController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  InputDecoration _inputDecoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      labelStyle: const TextStyle(color: Color.fromARGB(255, 49, 49, 49)),
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF1A2B7B), width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kmAtualText = _viaturaSelecionada == null
        ? null
        : 'KM atual: ${_viaturaSelecionada!.kmAtual}';

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '🛠 Cadastro de Manutenção',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B7B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  // texto neutro (não induz a "agendar" aqui)
                  'Busque a viatura e cadastre a próxima manutenção preventiva.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _autoValidateMode,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Autocomplete<String>(
                                    optionsBuilder: (textValue) {
                                      if (textValue.text.isEmpty) {
                                        return const Iterable<String>.empty();
                                      }
                                      final q = textValue.text.toLowerCase();
                                      return _viaturas
                                          .map(
                                            (v) =>
                                                '${v.numeroViatura} - ${v.placa} - ${v.modelo}',
                                          )
                                          .where(
                                            (op) =>
                                                op.toLowerCase().contains(q),
                                          );
                                    },
                                    fieldViewBuilder:
                                        (
                                          context,
                                          textEditingController,
                                          focusNode,
                                          onFieldSubmitted,
                                        ) {
                                          textEditingController.text =
                                              _buscaController.text;
                                          return TextFormField(
                                            controller: _buscaController,
                                            focusNode: focusNode,
                                            inputFormatters: [
                                              UpperCaseTextFormatter(),
                                            ],
                                            decoration: _inputDecoration(
                                              'Buscar por Placa ou Nº',
                                            ),
                                            onChanged: (_) {
                                              setState(() {
                                                _viaturaSelecionada = null;
                                              });
                                            },
                                          );
                                        },
                                    onSelected: (selection) {
                                      final selecionada = _viaturas.firstWhere(
                                        (v) =>
                                            selection.contains(
                                              v.numeroViatura,
                                            ) ||
                                            selection.contains(v.placa),
                                      );
                                      setState(() {
                                        _viaturaSelecionada = selecionada;
                                        _buscaController.text = selection;
                                      });
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (_viaturaSelecionada != null)
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade400,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Viatura: ${_viaturaSelecionada!.numeroViatura} | ${_viaturaSelecionada!.placa}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),

                                          Tooltip(
                                            message: 'Visualizar manutenções',
                                            child: InkWell(
                                              onTap: () {
                                                if (_viaturaSelecionada !=
                                                    null) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ListManutencoesPage(
                                                            viatura:
                                                                _viaturaSelecionada!,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                ),
                                                child: Icon(
                                                  Icons.visibility_outlined,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 8,
                                          ), // espaço entre olho e X
                                          // ✕ Depois: limpar
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _viaturaSelecionada = null;
                                                _buscaController.clear();
                                              });
                                            },
                                            tooltip: 'Limpar seleção',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _descricaoController,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                'Descrição da Manutenção',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Descreva a manutenção';
                                if (v.length < 5) {
                                  return 'Use pelo menos 5 caracteres';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _kmAlvoController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDecoration(
                                'KM próxima manutenção',
                                helperText: kmAtualText,
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Informe o KM da manutenção';
                                }
                                final km = int.tryParse(value);
                                if (km == null) return 'KM inválido';
                                if (_viaturaSelecionada != null &&
                                    km < _viaturaSelecionada!.kmAtual) {
                                  return 'KM alvo não pode ser menor que o KM atual';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // DATA OPCIONAL
                            TextFormField(
                              readOnly: true,
                              controller: _dataController,
                              onTap: () async {
                                await _selecionarData(context);
                                if (_dataSelecionada != null) {
                                  _dataController.text = DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(_dataSelecionada!);
                                }
                              },
                              decoration:
                                  _inputDecoration(
                                    'Data próxima manutenção (opcional)',
                                  ).copyWith(
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_dataSelecionada != null)
                                          IconButton(
                                            tooltip: 'Limpar data',
                                            onPressed: () {
                                              setState(
                                                () => _dataSelecionada = null,
                                              );
                                              _dataController
                                                  .clear(); // <-- agora limpa o campo
                                            },
                                            icon: const Icon(Icons.close),
                                          ),
                                        IconButton(
                                          onPressed: () =>
                                              _selecionarData(context),
                                          icon: const Icon(
                                            Icons.calendar_month_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              // sem validator: é opcional
                            ),

                            const SizedBox(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A2B7B),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _podeSalvar
                                      ? _confirmarSalvarManutencao
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A2B7B),
                                  ),
                                  child: const Text(
                                    'Salvar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
