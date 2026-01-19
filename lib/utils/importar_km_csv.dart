import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../db/database_helper.dart';

class ImportarKmCsv {
  static String formatarNumeroViatura(String numero) {
    final match = RegExp(r'^(\D+)-?(\d+)$').firstMatch(numero.toUpperCase());
    if (match != null) {
      final prefixo = match.group(1)!;
      final parteNumerica = match.group(2)!.padLeft(3, '0');
      return '$prefixo-$parteNumerica';
    }
    return numero.padLeft(3, '0');
  }

  // 👉 helper para dd/MM/yyyy
  static String _hojeDdMmYyyy() {
    final agora = DateTime.now();
    return '${agora.day.toString().padLeft(2, '0')}/'
        '${agora.month.toString().padLeft(2, '0')}/'
        '${agora.year.toString().padLeft(4, '0')}';
  }

  static Future<String?> selecionarArquivoCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    return result?.files.single.path;
  }

  static Future<String> importarComCaminho(String path) async {
    try {
      final file = File(path);
      final csvContent = await file.readAsString();

      final rows = const CsvToListConverter(
        fieldDelimiter: ';',
        eol: '\n',
      ).convert(csvContent);

      if (rows.length <= 1) return '⚠️ Nenhum dado encontrado no arquivo.';

      final db = await DatabaseHelper.getDatabase();
      final hoje = _hojeDdMmYyyy(); // <-- agora dd/MM/yyyy
      int atualizados = 0;
      int ignorados = 0;

      for (int i = 1; i < rows.length; i++) {
        final linha = rows[i];
        final numeroViatura = formatarNumeroViatura(linha[0].toString().trim());
        final novoKmStr = linha[3].toString().trim();

        if (numeroViatura.isEmpty || novoKmStr.isEmpty) {
          ignorados++;
          continue;
        }

        final novoKm = int.tryParse(novoKmStr);
        if (novoKm == null) {
          ignorados++;
          continue;
        }

        final result = await db.query(
          'viaturas',
          where: 'numeroViatura = ?',
          whereArgs: [numeroViatura],
          limit: 1,
        );
        if (result.isEmpty) {
          ignorados++;
          continue;
        }

        final viatura = result.first;
        final kmAtual = ((viatura['kmAtual'] ?? 0) as num).toInt();

        if (novoKm < kmAtual) {
          ignorados++;
          continue;
        }

        await db.update(
          'viaturas',
          {
            'kmAtual': novoKm,
            'ultimaAtualizacaoKm': hoje, // <-- consistente com a tela
          },
          where: 'id = ?',
          whereArgs: [viatura['id']],
        );
        atualizados++;
      }

      return '✅ $atualizados viaturas atualizadas.\n⚠️ $ignorados ignoradas.';
    } catch (e) {
      print('Erro ao importar CSV: $e');
      return '❌ Erro ao importar CSV.';
    }
  }
}
