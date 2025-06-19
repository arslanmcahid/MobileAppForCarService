import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = "car_maintenance.db";
  static const _databaseVersion = 1;

  static Database? _database;
  static DatabaseHelper? _instance;

  // Singleton instance
  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  // Private constructor
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Cars tablosu
    await db.execute('''
      CREATE TABLE cars (
        id TEXT PRIMARY KEY,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        year TEXT NOT NULL,
        license_plate TEXT NOT NULL,
        color TEXT,
        vin TEXT,
        mileage INTEGER,
        fuel_type TEXT,
        engine_size TEXT,
        image_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Maintenance tablosu
    await db.execute('''
      CREATE TABLE maintenance (
        id TEXT PRIMARY KEY,
        car_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        date_performed TEXT NOT NULL,
        mileage_at_service INTEGER,
        cost REAL,
        service_provider TEXT,
        notes TEXT,
        status TEXT NOT NULL,
        next_service_date TEXT,
        next_service_mileage INTEGER,
        attachments TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (car_id) REFERENCES cars (id) ON DELETE CASCADE
      )
    ''');

    // Maintenance reminders tablosu
    await db.execute('''
      CREATE TABLE maintenance_reminders (
        id TEXT PRIMARY KEY,
        car_id TEXT NOT NULL,
        maintenance_type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        reminder_date TEXT NOT NULL,
        reminder_mileage INTEGER,
        is_recurring INTEGER DEFAULT 0,
        recurring_interval_days INTEGER,
        recurring_interval_mileage INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (car_id) REFERENCES cars (id) ON DELETE CASCADE
      )
    ''');

    // Maintenance history tablosu
    await db.execute('''
      CREATE TABLE maintenance_history (
        id TEXT PRIMARY KEY,
        car_id TEXT NOT NULL,
        maintenance_id TEXT,
        action TEXT NOT NULL,
        old_values TEXT,
        new_values TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (car_id) REFERENCES cars (id) ON DELETE CASCADE,
        FOREIGN KEY (maintenance_id) REFERENCES maintenance (id) ON DELETE SET NULL
      )
    ''');

    // İndeksler
    await db.execute('CREATE INDEX idx_maintenance_car_id ON maintenance (car_id)');
    await db.execute('CREATE INDEX idx_maintenance_date ON maintenance (date_performed)');
    await db.execute('CREATE INDEX idx_maintenance_status ON maintenance (status)');
    await db.execute('CREATE INDEX idx_reminders_car_id ON maintenance_reminders (car_id)');
    await db.execute('CREATE INDEX idx_reminders_date ON maintenance_reminders (reminder_date)');
    await db.execute('CREATE INDEX idx_history_car_id ON maintenance_history (car_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Gelecekteki veritabanı güncellemeleri için
    if (oldVersion < 2) {
      // Örnek güncelleme
      // await db.execute('ALTER TABLE cars ADD COLUMN new_column TEXT');
    }
  }

  // Genel CRUD operasyonları
  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table,
    String where, [
    List<dynamic>? whereArgs,
  ]) async {
    Database db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<Map<String, dynamic>?> queryById(String table, String id) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> update(String table, Map<String, dynamic> row) async {
    Database db = await database;
    String id = row['id'];
    return await db.update(table, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, String id) async {
    Database db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    Database db = await database;
    await db.close();
  }

  // Özel sorgular
  Future<List<Map<String, dynamic>>> getMaintenanceByCarId(String carId) async {
    Database db = await database;
    return await db.query(
      'maintenance',
      where: 'car_id = ?',
      whereArgs: [carId],
      orderBy: 'date_performed DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingMaintenance() async {
    Database db = await database;
    String today = DateTime.now().toIso8601String();
    String nextWeek = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    
    return await db.query(
      'maintenance',
      where: 'status = ? AND next_service_date BETWEEN ? AND ?',
      whereArgs: ['scheduled', today, nextWeek],
      orderBy: 'next_service_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getOverdueMaintenance() async {
    Database db = await database;
    String today = DateTime.now().toIso8601String();
    
    return await db.query(
      'maintenance',
      where: 'status = ? AND next_service_date < ?',
      whereArgs: ['scheduled', today],
      orderBy: 'next_service_date ASC',
    );
  }
} 