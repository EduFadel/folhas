// novo arquivo: lib/database_helper.dart

import 'package:folhas/detection_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('detections.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE detection_history (
        id TEXT PRIMARY KEY,
        imagePath TEXT NOT NULL,
        detectionDate TEXT NOT NULL,
        imageWidth REAL NOT NULL,
        imageHeight REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE detection_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        historyId TEXT NOT NULL,
        className TEXT NOT NULL,
        confidence REAL NOT NULL,
        x1_norm REAL NOT NULL,
        y1_norm REAL NOT NULL,
        x2_norm REAL NOT NULL,
        y2_norm REAL NOT NULL,
        FOREIGN KEY (historyId) REFERENCES detection_history (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> insertDetection(
    DetectionHistory history,
    List<DetectionResult> results,
  ) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('detection_history', history.toMap());
      for (var result in results) {
        await txn.insert('detection_results', result.toMap());
      }
    });
  }

  Future<List<DetectionHistory>> getFullHistory() async {
    final db = await instance.database;
    final historyMaps = await db.query(
      'detection_history',
      orderBy: 'detectionDate DESC',
    );

    if (historyMaps.isEmpty) {
      return [];
    }

    List<DetectionHistory> historyList = [];
    for (var historyMap in historyMaps) {
      final history = DetectionHistory.fromMap(historyMap);
      final resultsMaps = await db.query(
        'detection_results',
        where: 'historyId = ?',
        whereArgs: [history.id],
      );
      history.results = resultsMaps.map((resultMap) {
        return DetectionResult(
          id: resultMap['id'] as int,
          historyId: resultMap['historyId'] as String,
          className: resultMap['className'] as String,
          confidence: resultMap['confidence'] as double,
          x1_norm: resultMap['x1_norm'] as double,
          y1_norm: resultMap['y1_norm'] as double,
          x2_norm: resultMap['x2_norm'] as double,
          y2_norm: resultMap['y2_norm'] as double,
        );
      }).toList();
      historyList.add(history);
    }
    return historyList;
  }

  Future<void> clearAllHistory() async {
    final db = await instance.database;
    // Usamos uma transação para garantir que ambas as tabelas sejam limpas com sucesso.
    await db.transaction((txn) async {
      await txn.delete('detection_results');
      await txn.delete('detection_history');
    });
    print('Histórico de detecções apagado.');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
