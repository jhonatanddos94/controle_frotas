import 'dart:io';
import 'package:controle_frota/db/database_helper.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/viatura_model.dart';

class ExportarKmCsv {
  static Future<String?> exportar() async {
    try {
      final db = await DatabaseHelper.getDatabase();

      // Consulta todos os dados direto do banco
      final resultado = await db.query('viaturas');

      final List<List<dynamic>> rows = [];

      // Cabeçalho
      rows.add(['Viatura', 'Placa', 'KM Atual', 'Novo KM (preencher)']);

      for (final v in resultado) {
        rows.add([
          v['numeroViatura'] ?? '',
          v['placa'] ?? '',
          v['kmAtual'] ?? '',
          '',
        ]);
      }

      final String csvData = const ListToCsvConverter(
        fieldDelimiter: ';',
        textDelimiter: '"',
      ).convert(rows);

      final dir = await getDesktopDirectory();
      if (dir == null) return null;

      final file = File('${dir.path}/viaturas_km_export.csv');
      await file.writeAsString(csvData, flush: true);

      return file.path;
    } catch (e) {
      print('Erro ao exportar CSV: $e');
      return null;
    }
  }

  static Future<Directory?> getDesktopDirectory() async {
    final directory = Directory(
      '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}/Desktop',
    );
    return await directory.exists() ? directory : null;
  }
}
