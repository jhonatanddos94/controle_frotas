import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_selector_windows/file_selector_windows.dart'; // Windows
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:controle_frota/models/manutencao_model.dart';

class HistoricoPdfGenerator {
  // Paleta
  static const PdfColor _azul = PdfColor.fromInt(0xFF1A2B7B);
  static const String _dash = '-'; // placeholder seguro (ASCII)

  /// Abre o “Salvar como…”, grava o PDF e retorna o caminho salvo (Windows).
  static Future<String?> salvarComDialog(Manutencao m) async {
    final bytes = await _buildPdfBytes(m);

    final hoje = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final suggestedName = 'historico_manutencao_$hoje.pdf';

    final fileSelector = FileSelectorWindows();
    final path = await fileSelector.getSavePath(
      acceptedTypeGroups: [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
      suggestedName: suggestedName,
    );

    if (path == null) return null; // usuário cancelou

    var finalPath = path;
    if (!finalPath.toLowerCase().endsWith('.pdf')) {
      finalPath = '$finalPath.pdf';
    }

    await File(finalPath).writeAsBytes(bytes, flush: true);
    return finalPath;
  }

  /// Abre o diálogo de impressão do SO (sem salvar).
  static Future<void> imprimir(Manutencao m) async {
    final bytes = await _buildPdfBytes(m);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ========================= INTERNALS =========================

  static Future<Uint8List> _buildPdfBytes(Manutencao m) async {
    // 1) Carrega fontes robustas (Roboto). Se não achar, usa fallback interno.
    pw.Font? fontRegular;
    pw.Font? fontBold;
    try {
      final reg = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bld = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      fontRegular = pw.Font.ttf(reg);
      fontBold = pw.Font.ttf(bld);
    } catch (_) {
      // fallback: fontes internas do pacote (podem não ter todos os glifos)
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);
    final pdf = pw.Document(theme: theme);

    // 2) Watermark (brasão PNG transparente)
    pw.MemoryImage? watermarkImage;
    try {
      final bytes = await rootBundle.load(
        'assets/logo.png',
      ); // troque se preciso
      watermarkImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      watermarkImage = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        build: (context) {
          return pw.Stack(
            children: [
              if (watermarkImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.07,
                      child: pw.Image(watermarkImage, width: 360),
                    ),
                  ),
                ),

              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Cabeçalho institucional
                  pw.Text(
                    'GUARDA MUNICIPAL DE DOURADOS',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Sistema de Controle de Manutenções',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 12),

                  // Título
                  pw.Text(
                    'Histórico da Manutenção',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: _azul,
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // INFORMAÇÕES GERAIS
                  _sectionHeader('INFORMAÇÕES GERAIS', leading: _squareIcon()),
                  _kvBlock([
                    _kv('Descrição', _v(m.descricao)),
                    _kv('Data', _v(m.data)),
                    _kv('KM', _vInt(m.km)),
                    _kv('Status', _v(m.status)),
                  ]),

                  // AGENDAMENTO
                  _sectionHeader('AGENDAMENTO', leading: _squareIcon()),
                  _kvBlock([
                    _kv('KM Alvo', _vInt(m.kmAlvo)),
                    _kv('Data Alvo', _v(m.dataAlvo)),
                    _kv('Local', _v(m.local)),
                    _kv('Observações', _v(m.observacao)),
                  ]),

                  // RESPONSÁVEL
                  _sectionHeader(
                    'RESPONSÁVEL PELA CONCLUSÃO',
                    leading: _squareIcon(),
                  ),
                  _kvBlock([
                    _kv('Nome', _v(m.responsavelNome).toUpperCase()),
                    _kv('Matrícula', _v(m.responsavelMatricula)),
                    _kv(
                      'Data/Hora Conclusão',
                      _formatarData(m.dataHoraConclusao),
                    ),
                  ]),

                  pw.Spacer(),

                  // Rodapé (usa hífen ASCII pra evitar tofu)
                  pw.Center(
                    child: pw.Text(
                      'Emitido automaticamente - Sistema de Controle GM Dourados',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ---------------------- Helpers de Layout ----------------------

  static pw.Widget _sectionHeader(String title, {pw.Widget? leading}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (leading != null) leading,
          if (leading != null) pw.SizedBox(width: 8),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _azul,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _squareIcon() => pw.Container(
    width: 10,
    height: 10,
    decoration: pw.BoxDecoration(
      color: _azul,
      borderRadius: pw.BorderRadius.circular(2),
    ),
  );

  static List<MapEntry<String, String>> _kv(String k, String v) => [
    MapEntry(k, v),
  ];

  static pw.Widget _kvBlock(List<List<MapEntry<String, String>>> lines) {
    final flat = <MapEntry<String, String>>[];
    for (final line in lines) {
      flat.addAll(line);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(left: 2, right: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: flat.map((e) => _kvRow(e.key, e.value)).toList(),
      ),
    );
  }

  static pw.Widget _kvRow(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              '$k:',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v.isEmpty ? _dash : v,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- Helpers de Dados ----------------------

  static String _v(String? s) => (s == null || s.trim().isEmpty) ? _dash : s!;
  static String _vInt(int? v) => v == null ? _dash : '$v';

  static String _formatarData(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return _dash;
    try {
      final dt = DateTime.parse(dataIso);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      // se já vier formatado, retorna como está (mas nunca vazio)
      return dataIso.trim().isEmpty ? _dash : dataIso;
    }
  }
}
