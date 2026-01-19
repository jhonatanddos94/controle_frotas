import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _db;
  static String? _dbPath;

  // Configura factory e diretório seguro de bancos (APPDATA/ControleFrota/databases)
  static Future<void> _configureDbRoot() async {
    if (_dbPath != null) return;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final env = Platform.environment;
    final base =
        env['APPDATA'] ?? env['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    final root = join(base, 'ControleFrota', 'databases');
    await Directory(root).create(recursive: true);

    // faz o factory usar esse root por padrão
    databaseFactoryFfi.setDatabasesPath(root);
    _dbPath = join(root, 'viaturas.db');
  }

  /// Caminho completo do arquivo do banco
  static Future<String> getDbFilePath() async {
    await _configureDbRoot();
    return _dbPath!;
  }

  // ----------------- migrações/garantias -----------------

  static Future<void> _ensureUltimaColuna(Database db) async {
    final result = await db.rawQuery('PRAGMA table_info(viaturas)');
    final has = result.any((c) => c['name'] == 'ultimaAtualizacaoKm');
    if (!has) {
      await db.execute(
        'ALTER TABLE viaturas ADD COLUMN ultimaAtualizacaoKm TEXT;',
      );
    }
  }

  static Future<void> _ensureUniqueIndexPlaca(Database db) async {
    final dups = await db.rawQuery('''
      SELECT UPPER(TRIM(placa)) p, COUNT(*) c
      FROM viaturas
      WHERE placa IS NOT NULL AND TRIM(placa) <> ''
      GROUP BY UPPER(TRIM(placa))
      HAVING c > 1
      LIMIT 1
    ''');
    if (dups.isEmpty) {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_viaturas_placa ON viaturas(placa COLLATE NOCASE);',
      );
    }
  }

  /// Corrige registros marcados como "Agendada" sem de fato estarem agendados (sem data/local).
  static Future<void> _corrigirStatusIndevido(Database db) async {
    // Volta para Pendente se não houver evidência mínima de agendamento
    await db.rawUpdate('''
      UPDATE manutencoes
      SET status = 'Pendente'
      WHERE status = 'Agendada'
        AND (
          IFNULL(TRIM(local),'') = ''
          OR IFNULL(TRIM(dataAlvo),'') = ''
        )
    ''');

    // Garante default Pendente se status nulo/vazio
    await db.rawUpdate('''
      UPDATE manutencoes
      SET status = 'Pendente'
      WHERE status IS NULL OR TRIM(status) = ''
    ''');
  }

  static Future<Database> getDatabase() async {
    if (_db != null && _db!.isOpen) return _db!;
    await _configureDbRoot();
    final path = await getDbFilePath();

    _db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3, // <--- bump
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS viaturas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              numeroViatura TEXT,
              placa TEXT,
              modelo TEXT,
              kmAtual INTEGER,
              tipo TEXT,
              situacao TEXT,
              ultimaAtualizacaoKm TEXT
            );
          ''');
          await _ensureUniqueIndexPlaca(db);

          // status agora tem DEFAULT 'Pendente'
          await db.execute('''
            CREATE TABLE manutencoes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              viaturaId INTEGER,
              descricao TEXT,
              data TEXT,
              km INTEGER,
              kmAlvo INTEGER,
              dataAlvo TEXT,
              status TEXT DEFAULT 'Pendente',
              local TEXT,
              observacao TEXT,
              responsavelNome TEXT,
              responsavelMatricula TEXT,
              dataHoraConclusao TEXT,
              visto INTEGER DEFAULT 0
            );
          ''');
        },
        onUpgrade: (db, oldV, newV) async {
          // v2 -> v3: garantir colunas e corrigir status indevido
          if (oldV < 2) {
            await _ensureUltimaColuna(db);
            await _ensureUniqueIndexPlaca(db);
          }
          if (oldV < 3) {
            // Não dá pra alterar DEFAULT facilmente em coluna existente,
            // mas garantimos consistência com correção retroativa.
            await _corrigirStatusIndevido(db);
          }
        },
        onOpen: (db) async {
          await _ensureUltimaColuna(db);
          await _ensureUniqueIndexPlaca(db);
          await _corrigirStatusIndevido(db); // blindagem sempre que abrir
        },
      ),
    );
    return _db!;
  }

  static Future<void> closeDatabase() async {
    final db = _db;
    if (db != null && db.isOpen) await db.close();
    _db = null;
  }

  static Future<void> warmUp() async {
    await getDatabase();
  }

  /// Saber se o DB está aberto
  static bool get isOpen => _db?.isOpen ?? false;

  // --------------------- QUERIES / AÇÕES ---------------------

  // Buscar manutenções por viatura
  static Future<List<Map<String, dynamic>>> getManutencoesPorViatura(
    int viaturaId,
  ) async {
    final db = await getDatabase();
    return db.query(
      'manutencoes',
      where: 'viaturaId = ?',
      whereArgs: [viaturaId],
      orderBy: 'data DESC',
    );
  }

  // Excluir manutenção
  static Future<void> excluirManutencao(int id) async {
    final db = await getDatabase();
    await db.delete('manutencoes', where: 'id = ?', whereArgs: [id]);
  }

  // Atualizar manutenção (campos básicos)
  static Future<void> atualizarManutencao({
    required int id,
    required String descricao,
    required int km,
    required String data,
    required String status,
  }) async {
    final db = await getDatabase();
    await db.update(
      'manutencoes',
      {'descricao': descricao, 'km': km, 'data': data, 'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Define metas/alvos (NÃO muda status).
  static Future<void> definirMetaManutencao({
    required int id,
    String? dataAlvo, // dd/MM/yyyy (ou ISO) — mantenha o padrão do app
    String? local,
    String? observacao,
  }) async {
    final db = await getDatabase();
    await db.update(
      'manutencoes',
      {
        if (dataAlvo != null) 'dataAlvo': dataAlvo.trim(),
        if (local != null) 'local': local.trim(),
        if (observacao != null) 'observacao': observacao.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Agendar de verdade (muda status para 'Agendada' — exige data e local).
  static Future<void> agendarManutencao({
    required int id,
    required String dataAlvo,
    required String local,
    String? observacao,
    String? agendadoPor, // pode reutilizar responsavelNome
    String?
    agendadoEmIso, // pode reutilizar dataHoraConclusao ou criar campo próprio
  }) async {
    final db = await getDatabase();

    if (dataAlvo.trim().isEmpty || local.trim().isEmpty) {
      throw ArgumentError('Para agendar, informe dataAlvo e local.');
    }

    await db.update(
      'manutencoes',
      {
        'dataAlvo': dataAlvo.trim(),
        'local': local.trim(),
        'observacao': (observacao ?? '').trim(),
        'status': 'Agendada',
        if (agendadoPor != null) 'responsavelNome': agendadoPor,
        if (agendadoEmIso != null) 'dataHoraConclusao': agendadoEmIso,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Viaturas
  static Future<List<Map<String, dynamic>>> getViaturas() async {
    final db = await getDatabase();
    return db.query('viaturas', orderBy: 'numeroViatura ASC');
  }

  static Future<List<Map<String, dynamic>>> getViaturasPorSituacao(
    String situacao,
  ) async {
    final db = await getDatabase();
    return db.query(
      'viaturas',
      where: 'situacao = ?',
      whereArgs: [situacao],
      orderBy: 'numeroViatura ASC',
    );
  }

  // Todas as manutenções com dados da viatura.
  // Ordenação:
  //  - com dataAlvo primeiro (mais recentes); vazias por último
  //  - se dataAlvo em dd/MM/yyyy, converte para yyyy-MM-dd para ordenar corretamente
  static Future<List<Map<String, dynamic>>> getTodasManutencoes() async {
    final db = await getDatabase();
    return db.rawQuery('''
      SELECT m.*, v.numeroViatura, v.placa
      FROM manutencoes m
      LEFT JOIN viaturas v ON m.viaturaId = v.id
      ORDER BY
        CASE WHEN IFNULL(TRIM(m.dataAlvo),'') = '' THEN 1 ELSE 0 END ASC,
        CASE
          WHEN INSTR(m.dataAlvo,'/') = 3
            THEN SUBSTR(m.dataAlvo,7,4) || '-' || SUBSTR(m.dataAlvo,4,2) || '-' || SUBSTR(m.dataAlvo,1,2)
          ELSE m.dataAlvo
        END DESC,
        m.id DESC
    ''');
  }

  // Placa duplicada?
  static Future<bool> existePlaca(String placa, {int? ignorarId}) async {
    final db = await getDatabase();
    final rows = await db.query(
      'viaturas',
      where: ignorarId == null ? 'placa = ?' : 'placa = ? AND id <> ?',
      whereArgs: ignorarId == null ? [placa] : [placa, ignorarId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // Maior KM já registrado nas manutenções dessa viatura
  static Future<int> maxKmRegistrado(int viaturaId) async {
    final db = await getDatabase();
    final res = await db.rawQuery(
      'SELECT MAX(COALESCE(km,0)) AS maxKm FROM manutencoes WHERE viaturaId = ?',
      [viaturaId],
    );
    final val = res.first['maxKm'];
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }

  // Atualizar viatura (sem alterar id)
  static Future<void> atualizarViatura({
    required int id,
    required String numeroViatura,
    required String placa,
    required String modelo,
    required int kmAtual,
    String? tipo,
    required String situacao,
    String? ultimaAtualizacaoKm,
  }) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.update(
        'viaturas',
        {
          'numeroViatura': numeroViatura,
          'placa': placa,
          'modelo': modelo,
          'kmAtual': kmAtual,
          'tipo': (tipo ?? '').trim(),
          'situacao': situacao,
          if (ultimaAtualizacaoKm != null)
            'ultimaAtualizacaoKm': ultimaAtualizacaoKm,
        },
        where: 'id = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  // Quantidade de manutenções por viatura
  static Future<int> contarManutencoesDaViatura(int viaturaId) async {
    final db = await getDatabase();
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM manutencoes WHERE viaturaId = ?',
      [viaturaId],
    );
    final v = res.first['c'];
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  // Exclui viatura apenas se não houver manutenções
  static Future<bool> excluirViaturaSeSemManutencoes(int id) async {
    final db = await getDatabase();
    return await db.transaction<bool>((txn) async {
      final res = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM manutencoes WHERE viaturaId = ?',
        [id],
      );
      final v = res.first['c'];
      final count = v is int ? v : int.tryParse(v.toString()) ?? 0;

      if (count > 0) return false;

      final deleted = await txn.delete(
        'viaturas',
        where: 'id = ?',
        whereArgs: [id],
      );
      return deleted > 0;
    });
  }
}
