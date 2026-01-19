import 'package:controle_frota/utils/historico_pdf_generator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/manutencao_model.dart';

class HistoricoManutencaoPage extends StatelessWidget {
  final Manutencao manutencao;

  const HistoricoManutencaoPage({super.key, required this.manutencao});

  /// Faz parse tolerante de vários formatos de data.
  DateTime? _parseFlexible(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1) Tenta ISO 8601
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // 2) Tenta formatos comuns dd/MM/yyyy HH:mm e dd/MM/yyyy
    final candidates = <DateFormat>[
      DateFormat('dd/MM/yyyy HH:mm'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('yyyy-MM-dd'),
    ];

    for (final f in candidates) {
      try {
        return f.parseStrict(s);
      } catch (_) {
        // tenta o próximo
      }
    }
    return null;
  }

  /// Formata a data de maneira amigável. Retorna "–" quando ausente/inválida.
  String formatarData(String? data) {
    final dt = _parseFlexible(data);
    if (dt == null) return '–'; // sem data definida
    // Se a string original tem hora (tem ":"), mostra com hora; senão só a data
    final hasTime = (data ?? '').contains(':');
    final fmt = hasTime
        ? DateFormat('dd/MM/yyyy HH:mm')
        : DateFormat('dd/MM/yyyy');
    return fmt.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4F3),
      appBar: AppBar(
        title: const Text('Histórico da Manutenção'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          width: 794, // Largura A4 aproximada
          padding: const EdgeInsets.all(32),
          color: Colors.white,
          child: Stack(
            children: [
              // Marca d’água
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: 0.07,
                    child: Image.asset('assets/logo.png', width: 500),
                  ),
                ),
              ),

              // Conteúdo principal
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho
                  const Text(
                    'GUARDA MUNICIPAL DE DOURADOS',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'Sistema de Controle de Manutenções',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Título e botões
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Histórico da Manutenção',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final path =
                                  await HistoricoPdfGenerator.salvarComDialog(
                                    manutencao,
                                  );
                              if (path != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('PDF salvo em:\n$path'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Gerar PDF'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () =>
                                HistoricoPdfGenerator.imprimir(manutencao),
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Imprimir'),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  _buildSection('📘 INFORMAÇÕES GERAIS', [
                    _buildInfo('Descrição', manutencao.descricao),
                    _buildInfo('Data', formatarData(manutencao.data)),
                    _buildInfo('KM', manutencao.km?.toString()),
                    _buildInfo('Status', manutencao.status),
                  ]),

                  const Divider(height: 24),

                  _buildSection('📅 AGENDAMENTO', [
                    _buildInfo('KM Alvo', manutencao.kmAlvo?.toString()),
                    _buildInfo(
                      'Data Alvo',
                      // quando não houver, mostra "–" (data opcional)
                      formatarData(manutencao.dataAlvo),
                    ),
                    _buildInfo('Local', manutencao.local),
                    _buildInfo('Observações', manutencao.observacao),
                  ]),

                  const Divider(height: 24),

                  _buildSection('👤 RESPONSÁVEL PELA CONCLUSÃO', [
                    _buildInfo('Nome', manutencao.responsavelNome),
                    _buildInfo('Matrícula', manutencao.responsavelMatricula),
                    _buildInfo(
                      'Data/Hora Conclusão',
                      formatarData(manutencao.dataHoraConclusao),
                    ),
                  ]),

                  const SizedBox(height: 32),

                  const Text(
                    'Emitido automaticamente – Sistema de Controle GM Dourados',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> infos) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey[800],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...infos,
        ],
      ),
    );
  }

  Widget _buildInfo(String label, String? value) {
    final shown = (value == null || value.trim().isEmpty) ? '–' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: shown,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
