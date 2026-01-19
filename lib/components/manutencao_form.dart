import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/viatura_model.dart';
import '../models/manutencao_model.dart';
import '../db/database_helper.dart';
import 'package:flutter/services.dart';

class ManutencaoForm extends StatefulWidget {
  final Viatura viatura;
  final Manutencao? manutencao;
  final VoidCallback? onSaved;

  const ManutencaoForm({
    super.key,
    required this.viatura,
    this.manutencao,
    this.onSaved,
  });

  @override
  State<ManutencaoForm> createState() => ManutencaoFormState();
}

class ManutencaoFormState extends State<ManutencaoForm> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _kmController = TextEditingController();
  final _kmAlvoController = TextEditingController();
  DateTime? _dataAlvoSelecionada;
  late TextEditingController _dataAlvoController;

  @override
  void initState() {
    super.initState();

    if (widget.manutencao != null) {
      _descricaoController.text = widget.manutencao!.descricao;
      _kmController.text = widget.viatura.kmAtual.toString();
      _kmAlvoController.text = widget.manutencao!.kmAlvo.toString();

      _dataAlvoSelecionada = DateFormat(
        'dd/MM/yyyy',
      ).parse(widget.manutencao!.dataAlvo);
    } else {
      _kmController.text = widget.viatura.kmAtual.toString();
    }

    _dataAlvoController = TextEditingController(
      text: _dataAlvoSelecionada == null
          ? ''
          : DateFormat('dd/MM/yyyy').format(_dataAlvoSelecionada!),
    );
  }

  Future<void> _selecionarDataAlvo(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataAlvoSelecionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(600, 600)),
          child: Theme(data: Theme.of(context), child: child!),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dataAlvoSelecionada = picked;
        _dataAlvoController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate() && _dataAlvoSelecionada != null) {
      final db = await DatabaseHelper.getDatabase();

      final manutencao = Manutencao(
        id: widget.manutencao?.id,
        viaturaId: widget.viatura.id!,
        descricao: _descricaoController.text.trim(),
        km: int.parse(_kmController.text),
        kmAlvo: int.parse(_kmAlvoController.text),
        data: DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now()), // Data de registro atual
        dataAlvo: DateFormat('dd/MM/yyyy').format(_dataAlvoSelecionada!),

        status: widget.manutencao?.status ?? 'Agendada',
      );

      if (widget.manutencao == null) {
        await db.insert('manutencoes', manutencao.toMap());
      } else {
        await db.update(
          'manutencoes',
          manutencao.toMap(),
          where: 'id = ?',
          whereArgs: [manutencao.id],
        );
      }

      if (widget.onSaved != null) widget.onSaved!();
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color.fromARGB(255, 49, 49, 49)),
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF1A2B7B), width: 2.0),
      ),
    );
  }

  void salvar() => _salvar();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _descricaoController,
            decoration: _inputDecoration('Descrição da Manutenção'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Informe a descrição' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _kmController,
            enabled: false,
            decoration: _inputDecoration('KM Atual da Viatura'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _kmAlvoController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('KM para Manutenção'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Informe o KM alvo' : null,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _selecionarDataAlvo(context),
            child: AbsorbPointer(
              child: TextFormField(
                controller: _dataAlvoController,
                readOnly: true,
                onTap: () => _selecionarDataAlvo(context),
                decoration: _inputDecoration('Data Alvo da Manutenção'),
                validator: (_) =>
                    _dataAlvoSelecionada == null ? 'Selecione a data' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
