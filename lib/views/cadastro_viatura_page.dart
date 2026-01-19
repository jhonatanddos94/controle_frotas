import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/viatura_model.dart';
import '../db/database_helper.dart';

/// Transforma letras em maiúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Formata a placa com hífen após 3 caracteres (suporta antigo e Mercosul)
/// Formata a placa garantindo 3 letras no início (AAA-1234 / AAA-1A23)
class PlacaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Upper + remove tudo que não for A-Z ou 0-9
    final raw = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    String prefix = ''; // 3 primeiras posições: apenas letras
    String suffix = ''; // restante (até 4), letras ou números

    for (int i = 0; i < raw.length; i++) {
      final c = raw[i];
      final isLetter = RegExp(r'[A-Z]').hasMatch(c);

      if (prefix.length < 3) {
        // Só aceita letras nas 3 primeiras
        if (isLetter) prefix += c;
      } else {
        // Depois das 3 letras, aceita letras ou números
        if (suffix.length < 4) suffix += c;
      }
    }

    String out;
    if (suffix.isEmpty) {
      out = prefix;
    } else {
      out = '$prefix-$suffix';
    }

    // Limita o total visível a 8 (AAA-1234)
    if (out.length > 8) out = out.substring(0, 8);

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

class CadastroViaturaPage extends StatefulWidget {
  const CadastroViaturaPage({super.key});

  @override
  State<CadastroViaturaPage> createState() => _CadastroViaturaPageState();
}

class _CadastroViaturaPageState extends State<CadastroViaturaPage> {
  final _formKey = GlobalKey<FormState>();
  final _numeroController = TextEditingController();
  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _kmController = TextEditingController();

  String? _tipoSelecionado;
  final List<String> _tipos = [
    'Carro',
    'Camionete',
    'Motocicleta',
    'Onibus',
    'Van',
  ];

  String? _situacaoSelecionada;
  final List<String> _situacoes = ['Ativa', 'Oficina', 'Reservada'];

  @override
  void dispose() {
    _numeroController.dispose();
    _placaController.dispose();
    _modeloController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  String formatarNumeroViatura(String numero) {
    final apenasDigitos = numero.replaceAll(RegExp(r'\D'), '');
    return apenasDigitos.padLeft(3, '0');
  }

  // Validação de placa (antigo e Mercosul)
  bool _placaValida(String value) {
    // Com hífen na UI
    final placa = value.trim().toUpperCase();
    final regexAntiga = RegExp(r'^[A-Z]{3}-\d{4}$'); // AAA-1234
    final regexMercosul = RegExp(r'^[A-Z]{3}-\d[A-Z]\d{2}$'); // AAA-1A23
    return regexAntiga.hasMatch(placa) || regexMercosul.hasMatch(placa);
  }

  Future<bool> _existePlaca(String placaSemHifen) async {
    final db = await DatabaseHelper.getDatabase();
    final rows = await db.query(
      'viaturas',
      where: 'UPPER(placa) = ?',
      whereArgs: [placaSemHifen.toUpperCase()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _existeNumero(String numero3digitos) async {
    final db = await DatabaseHelper.getDatabase();
    final rows = await db.query(
      'viaturas',
      where: 'numeroViatura = ?',
      whereArgs: [numero3digitos],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  void _salvarViatura() async {
    if (_formKey.currentState!.validate()) {
      final db = await DatabaseHelper.getDatabase();

      final numero = formatarNumeroViatura(_numeroController.text);
      final placaLimpa = _placaController.text.replaceAll('-', '');

      // Verifica duplicatas
      final existe = await db.query(
        'viaturas',
        where: 'numeroViatura = ? OR placa = ?',
        whereArgs: [numero, placaLimpa],
      );

      if (existe.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Já existe uma viatura com este número ou placa.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // cancela o cadastro
      }

      // Cria objeto e salva
      final viatura = Viatura(
        numeroViatura: numero,
        placa: placaLimpa,
        modelo: _modeloController.text,
        kmAtual: int.parse(_kmController.text),
        tipo: _tipoSelecionado ?? '',
        situacao: _situacaoSelecionada ?? '',
      );

      await db.insert('viaturas', viatura.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viatura cadastrada com sucesso!')),
      );

      setState(() {
        _numeroController.clear();
        _placaController.clear();
        _modeloController.clear();
        _kmController.clear();
        _tipoSelecionado = null;
        _situacaoSelecionada = null;
      });
    }
  }

  void _cancelar() {
    Navigator.pop(context);
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color.fromARGB(255, 49, 49, 49)),
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(
          color: Color.fromARGB(255, 41, 42, 43),
          width: 2.0,
        ),
      ),
      counterText: '', // esconde contador quando usar maxLength
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                const Text(
                  '📋 Cadastro de Viatura',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B7B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cadastre aqui uma nova viatura para controle de frota.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Número da viatura
                            TextFormField(
                              controller: _numeroController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                'Número da Viatura',
                                hint: 'Ex.: 007',
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Informe o número';
                                final num = int.tryParse(v);
                                if (num == null) return 'Apenas números';
                                if (num <= 0) return 'Número inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Tipo
                            DropdownButtonFormField<String>(
                              value: _tipoSelecionado,
                              decoration: _inputDecoration('Tipo de Viatura'),
                              items: _tipos
                                  .map(
                                    (tipo) => DropdownMenuItem(
                                      value: tipo,
                                      child: Text(tipo),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _tipoSelecionado = value),
                              validator: (value) =>
                                  value == null ? 'Selecione o tipo' : null,
                            ),
                            const SizedBox(height: 16),

                            // Modelo
                            TextFormField(
                              controller: _modeloController,
                              inputFormatters: [
                                UpperCaseTextFormatter(),
                                LengthLimitingTextInputFormatter(40),
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                'Modelo',
                                hint: 'Ex.: DUSTER 1.6',
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Informe o modelo';
                                if (v.length < 2) return 'Modelo muito curto';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Placa
                            TextFormField(
                              controller: _placaController,
                              inputFormatters: [
                                PlacaFormatter(),
                                LengthLimitingTextInputFormatter(
                                  8,
                                ), // AAA-1234 = 8
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                'Placa',
                                hint: 'Ex.: ABC-1A23 ou ABC-1234',
                              ),
                              validator: (value) {
                                final v = value?.trim().toUpperCase() ?? '';
                                if (v.isEmpty) return 'Informe a placa';
                                if (v.length != 8) return 'Placa incompleta';
                                if (!_placaValida(v)) return 'Placa inválida';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // KM Atual
                            TextFormField(
                              controller: _kmController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                  7,
                                ), // limite razoável
                              ],
                              decoration: _inputDecoration(
                                'KM Atual',
                                hint: 'Ex.: 35600',
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Informe o KM';
                                final km = int.tryParse(v);
                                if (km == null) return 'Apenas números';
                                if (km <= 0)
                                  return 'KM deve ser maior que zero';
                                if (km > 2000000)
                                  return 'KM muito alto, verifique';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Situação
                            DropdownButtonFormField<String>(
                              value: _situacaoSelecionada,
                              decoration: _inputDecoration(
                                'Situação da Viatura',
                              ),
                              items: _situacoes
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _situacaoSelecionada = value),
                              validator: (value) =>
                                  value == null ? 'Selecione a situação' : null,
                            ),
                            const SizedBox(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: _cancelar,
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
                                  onPressed: _salvarViatura,
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
