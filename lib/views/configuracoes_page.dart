import 'dart:io';
import 'dart:convert';
import 'package:controle_frota/db/database_helper.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_selector_windows/file_selector_windows.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  // Nome do arquivo do banco na sua app
  static const String _dbFileName = 'viaturas.db';

  // -------------------- BACKUP --------------------

  Future<void> _backupCompleto(BuildContext context) async {
    try {
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final originalDbFile = File(p.join(dbPath, _dbFileName));

      if (!await originalDbFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banco de dados não encontrado.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = DateTime.now().toIso8601String().split('T').first;
      final suggestedName = 'backup_viaturas_$data.db';

      final fileSelector = FileSelectorWindows();
      final pathDestino = await fileSelector.getSavePath(
        acceptedTypeGroups: [
          XTypeGroup(label: 'Banco de Dados', extensions: ['db']),
        ],
        suggestedName: suggestedName,
      );

      if (pathDestino == null) return;

      var destino = pathDestino;
      if (!destino.toLowerCase().endsWith('.db')) {
        destino = '$destino.db';
      }

      await originalDbFile.copy(destino);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Backup salvo com sucesso em:\n$destino'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao fazer backup:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // -------------------- RESTAURAR BACKUP --------------------

  Future<void> _restaurarBackup(BuildContext context) async {
    try {
      // 1) Selecionar o arquivo .db a restaurar
      XFile? picked;
      try {
        picked = await FileSelectorWindows().openFile(
          acceptedTypeGroups: [
            XTypeGroup(label: 'Banco de Dados', extensions: ['db']),
          ],
        );
      } catch (_) {
        picked = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(label: 'Banco de Dados', extensions: ['db']),
          ],
        );
      }
      if (picked == null) return;

      final sourceFile = File(picked.path);
      if (!await sourceFile.exists()) {
        throw 'Arquivo selecionado não encontrado.';
      }

      // 2) Fechar o banco atual para liberar o arquivo no Windows
      await DatabaseHelper.closeDatabase();

      // 3) Caminhos
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final destPath = p.join(dbPath, 'viaturas.db');
      final destFile = File(destPath);

      // 3.1 Backup do arquivo atual (se existir)
      if (await destFile.exists()) {
        final ts = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .replaceAll('.', '-');
        final backupPath = p.join(dbPath, 'viaturas_backup_$ts.db');

        // use copy para evitar falhas de rename em alguns locks residuais
        await destFile.copy(backupPath);

        // deletar o atual para permitir escrita do novo
        await destFile.delete();
      }

      // 4) Copiar o selecionado para o nome oficial
      await sourceFile.copy(destPath);

      // 5) (Opcional) Reabrir o banco para continuar usando sem reiniciar
      await DatabaseHelper.warmUp();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Backup restaurado com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao restaurar backup:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // -------------------- helpers --------------------

  String _timestamped(String base, String ext) {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '$base\_$stamp$ext';
  }

  Future<bool> _isLikelySQLite(File f) async {
    try {
      final raf = await f.open();
      final header = await raf.read(16);
      await raf.close();
      final headStr = utf8.decode(header, allowMalformed: true);
      return headStr.startsWith('SQLite format 3');
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 800;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Opções de Backup',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: isTight
                      ? WrapAlignment.center
                      : WrapAlignment.spaceAround,
                  children: [
                    _buildCard(
                      context,
                      icon: Icons.backup,
                      title: 'Backup Completo',
                      onTap: () => _backupCompleto(context),
                      maxWidth: isTight ? constraints.maxWidth : 360,
                    ),
                    _buildCard(
                      context,
                      icon: Icons.settings_backup_restore,
                      title: 'Restaurar Backup',
                      onTap: () => _restaurarBackup(context),
                      maxWidth: isTight ? constraints.maxWidth : 360,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    double? maxWidth,
  }) {
    final w = maxWidth ?? MediaQuery.of(context).size.width * 0.4;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: w,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
