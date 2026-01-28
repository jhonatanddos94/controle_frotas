import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/viatura_model.dart';

class GerarFichaKmPdf {
  static Future<Uint8List> gerar({
    required List<Viatura> viaturas,
    String titulo = 'FICHA DE ATUALIZAÇÃO DE KM - VIATURAS',
    int minimoLinhas =
        22, // preenche com linhas vazias se tiver poucas viaturas
  }) async {
    final doc = pw.Document();

    // Ordena por número (evita sair embaralhado)
    final lista = [...viaturas];
    lista.sort((a, b) => a.numeroViatura.compareTo(b.numeroViatura));

    final dataHoje = DateTime.now();
    final dataStr =
        '${dataHoje.day.toString().padLeft(2, '0')}/'
        '${dataHoje.month.toString().padLeft(2, '0')}/'
        '${dataHoje.year.toString().padLeft(4, '0')}';

    // >>> A4 RETRATO (igual seu print)
    // Larguras ajustadas para caber no A4 retrato com margem.
    const wNum = 45.0;
    const wModelo = 120.0;
    const wKmAtual = 60.0;
    const wKmNovo = 70.0; // x4 = 280

    // Total: 45 + 120 + 60 + 280 = 505 (cabe no A4 retrato com folga)

    final tableBorder = pw.TableBorder.all(
      width: 0.7,
      color: PdfColors.grey600,
    );

    pw.Widget cellText(
      String text, {
      pw.TextStyle? style,
      pw.Alignment align = pw.Alignment.centerLeft,
      pw.EdgeInsets padding = const pw.EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),
    }) {
      return pw.Container(
        alignment: align,
        padding: padding,
        child: pw.Text(
          text,
          style: style ?? const pw.TextStyle(fontSize: 9),
          maxLines: 1,
        ),
      );
    }

    pw.Widget cellVazio({double height = 24}) {
      return pw.Container(
        height: height,
        alignment: pw.Alignment.center,
        // espaço vazio para escrever à mão
        child: pw.SizedBox(height: height),
      );
    }

    pw.TableRow headerRow() {
      final headerStyle = pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      );

      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F2F2)),
        children: [
          cellText('Nº', style: headerStyle),
          cellText('Modelo', style: headerStyle),
          cellText('KM Atual', style: headerStyle, align: pw.Alignment.center),
          cellText('KM Novo 1', style: headerStyle, align: pw.Alignment.center),
          cellText('KM Novo 2', style: headerStyle, align: pw.Alignment.center),
          cellText('KM Novo 3', style: headerStyle, align: pw.Alignment.center),
          cellText('KM Novo 4', style: headerStyle, align: pw.Alignment.center),
        ],
      );
    }

    pw.TableRow dataRow(Viatura v) {
      final modelo = (v.modelo ?? '').toString().trim();
      final modeloOk = modelo.isEmpty ? '-' : modelo;

      return pw.TableRow(
        children: [
          cellText(v.numeroViatura),
          cellText(modeloOk),
          cellText(v.kmAtual.toString(), align: pw.Alignment.center),
          cellVazio(height: 24),
          cellVazio(height: 24),
          cellVazio(height: 24),
          cellVazio(height: 24),
        ],
      );
    }

    pw.TableRow emptyRow() {
      return pw.TableRow(
        children: [
          cellText(''),
          cellText(''),
          cellText('', align: pw.Alignment.center),
          cellVazio(height: 24),
          cellVazio(height: 24),
          cellVazio(height: 24),
          cellVazio(height: 24),
        ],
      );
    }

    // completa com linhas vazias (pra ficar “ficha” mesmo)
    final linhas = <pw.TableRow>[headerRow(), ...lista.map(dataRow)];
    while ((linhas.length - 1) < minimoLinhas) {
      linhas.add(emptyRow());
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // retrato
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        build: (context) {
          return [
            // Cabeçalho
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    titulo,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  'Data: $dataStr',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Preencher os campos "KM Novo" manualmente e depois lançar no sistema.',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 14),

            // Tabela com larguras travadas
            pw.Table(
              border: tableBorder,
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: pw.FixedColumnWidth(wNum),
                1: pw.FixedColumnWidth(wModelo),
                2: pw.FixedColumnWidth(wKmAtual),
                3: pw.FixedColumnWidth(wKmNovo),
                4: pw.FixedColumnWidth(wKmNovo),
                5: pw.FixedColumnWidth(wKmNovo),
                6: pw.FixedColumnWidth(wKmNovo),
              },
              children: linhas,
            ),

            pw.SizedBox(height: 10),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total de viaturas: ${lista.length}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}
