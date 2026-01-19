import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:controle_frota/models/viatura_model.dart';

class EditarViaturaDialog extends StatefulWidget {
  final Viatura viatura;

  const EditarViaturaDialog({super.key, required this.viatura});

  @override
  State<EditarViaturaDialog> createState() => _EditarViaturaDialogState();
}

class _EditarViaturaDialogState extends State<EditarViaturaDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _numeroCtrl;
  late final TextEditingController _placaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _tipoCtrl;
  late String _situacao;

  @override
  void initState() {
    super.initState();
    final v = widget.viatura;

    _numeroCtrl = TextEditingController(text: (v.numeroViatura).toString());
    _placaCtrl = TextEditingController(text: (v.placa ?? '').toUpperCase());
    _modeloCtrl = TextEditingController(text: v.modelo ?? '');
    _kmCtrl = TextEditingController(text: (v.kmAtual).toString());
    _tipoCtrl = TextEditingController(text: v.tipo ?? '');

    _situacao = _normalizeSituacao(v.situacao);
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _placaCtrl.dispose();
    _modeloCtrl.dispose();
    _kmCtrl.dispose();
    _tipoCtrl.dispose();
    super.dispose();
  }

  String _normalizeSituacao(String? s) {
    final val = (s ?? '').trim().toLowerCase();
    switch (val) {
      case 'ativa':
        return 'Ativa';
      case 'oficina':
        return 'Oficina';
      case 'reservada':
        return 'Reservada';
      default:
        return 'Ativa';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Espaços na borda do diálogo
    const insetH = 80.0;
    const insetV = 40.0;

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Tamanho alvo (responsivo)
    final targetW = (screenW - insetH * 2).clamp(520.0, 900.0);
    final targetH = (screenH - insetV * 2).clamp(420.0, 700.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: insetH,
        vertical: insetV,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: targetW, maxHeight: targetH),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  'Editar viatura',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Número da viatura
                        TextFormField(
                          controller: _numeroCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Número da viatura',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Informe o número'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Placa (sempre maiúscula)
                        TextFormField(
                          controller: _placaCtrl,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            TextInputFormatter.withFunction((
                              oldValue,
                              newValue,
                            ) {
                              return newValue.copyWith(
                                text: newValue.text.toUpperCase(),
                                selection: newValue.selection,
                              );
                            }),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Placa',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Informe a placa'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Modelo
                        TextFormField(
                          controller: _modeloCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Modelo',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Informe o modelo'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // KM atual (só dígitos)
                        TextFormField(
                          controller: _kmCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'KM atual',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Informe o KM';
                            }
                            final n = int.tryParse(v);
                            if (n == null || n < 0) return 'KM inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Tipo + Situação
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tipoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Tipo (opcional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _situacao,
                                decoration: const InputDecoration(
                                  labelText: 'Situação',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Ativa',
                                    child: Text('Ativa'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Oficina',
                                    child: Text('Oficina'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Reservada',
                                    child: Text('Reservada'),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => _situacao = val ?? 'Ativa'),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Selecione a situação'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;

                      final kmParsed = int.tryParse(_kmCtrl.text.trim());
                      if (kmParsed == null) return; // segurança extra

                      final result = {
                        'numeroViatura': _numeroCtrl.text.trim(),
                        'placa': _placaCtrl.text.trim().toUpperCase(),
                        'modelo': _modeloCtrl.text.trim(),
                        'kmAtual': kmParsed,
                        // manda null quando vazio (mantém coerência com o restante do app)
                        'tipo': _tipoCtrl.text.trim().isEmpty
                            ? null
                            : _tipoCtrl.text.trim(),
                        'situacao': _situacao,
                      };

                      FocusScope.of(context).unfocus();
                      Navigator.pop(context, result);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
