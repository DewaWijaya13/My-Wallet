import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/report_history.dart';
import '../models/schedule.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('my_wallet.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // On web, just use the filename directly
    return await openDatabase(
      filePath,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN foto_profil TEXT');
      } catch (e) {
        print("Migration error (foto_profil): $e");
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE schedules ADD COLUMN catatan TEXT');
      } catch (e) {
        print("Migration error (catatan): $e");
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE wallets (
            wallet_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            nama_dompet TEXT NOT NULL,
            deskripsi TEXT,
            warna TEXT NOT NULL,
            ikon TEXT NOT NULL,
            saldo_awal REAL DEFAULT 0,
            tanggal_dibuat TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
          )
        ''');
      } catch (e) {
        print("Migration error (wallets table): $e");
      }
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN wallet_id TEXT');
      } catch (e) {
        print("Migration error (wallet_id column): $e");
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE notifications (
            notification_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            tanggal TEXT NOT NULL,
            is_read INTEGER DEFAULT 0,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
          )
        ''');
      } catch (e) {
        print("Migration error (notifications table): $e");
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE schedules ADD COLUMN is_h1_active INTEGER DEFAULT 1');
      } catch (e) {
        print("Migration error (is_h1_active column): $e");
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE notifications ADD COLUMN is_deleted INTEGER DEFAULT 0');
      } catch (e) {
        print("Migration error (is_deleted column): $e");
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // USERS table
    await db.execute('''
      CREATE TABLE users (
        user_id TEXT PRIMARY KEY,
        nama_lengkap TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        no_hp TEXT,
        tanggal_lahir TEXT,
        jenis_kelamin TEXT,
        batas_budget REAL DEFAULT 0,
        foto_profil TEXT
      )
    ''');

    // CATEGORIES table
    await db.execute('''
      CREATE TABLE categories (
        kategori_id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_kategori TEXT NOT NULL,
        tipe TEXT NOT NULL,
        ikon TEXT NOT NULL,
        warna TEXT NOT NULL
      )
    ''');

    // TRANSACTIONS table
    await db.execute('''
      CREATE TABLE transactions (
        trx_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        kategori_id INTEGER NOT NULL,
        wallet_id TEXT,
        tipe_trx TEXT NOT NULL,
        nominal REAL NOT NULL,
        tanggal_trx TEXT NOT NULL,
        catatan TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id),
        FOREIGN KEY (kategori_id) REFERENCES categories(kategori_id)
      )
    ''');

    // WALLETS table
    await db.execute('''
      CREATE TABLE wallets (
        wallet_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        nama_dompet TEXT NOT NULL,
        deskripsi TEXT,
        warna TEXT NOT NULL,
        ikon TEXT NOT NULL,
        saldo_awal REAL DEFAULT 0,
        tanggal_dibuat TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ''');

    // REPORT_HISTORIES table
    await db.execute('''
      CREATE TABLE report_histories (
        report_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        tipe_laporan TEXT NOT NULL,
        tanggal_dibuat TEXT NOT NULL,
        file_path TEXT,
        periode_laporan TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ''');

    // SCHEDULES table
    await db.execute('''
      CREATE TABLE schedules (
        jadwal_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        kategori_id INTEGER NOT NULL,
        nama_tagihan TEXT NOT NULL,
        nominal REAL NOT NULL,
        tanggal_jatuh_tempo TEXT NOT NULL,
        is_reminder_active INTEGER DEFAULT 1,
        is_h1_active INTEGER DEFAULT 1,
        catatan TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id),
        FOREIGN KEY (kategori_id) REFERENCES categories(kategori_id)
      )
    ''');

    // NOTIFICATIONS table
    await db.execute('''
      CREATE TABLE notifications (
        notification_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ''');

    // Seed default categories
    final defaultCategories = [
      {'nama_kategori': 'Makanan', 'tipe': 'expense', 'ikon': 'restaurant', 'warna': '#6EE7B7'},
      {'nama_kategori': 'Transportasi', 'tipe': 'expense', 'ikon': 'directions_car', 'warna': '#93C5FD'},
      {'nama_kategori': 'Edukasi', 'tipe': 'expense', 'ikon': 'school', 'warna': '#C4B5FD'},
      {'nama_kategori': 'Belanja', 'tipe': 'expense', 'ikon': 'shopping_bag', 'warna': '#FCA5A5'},
      {'nama_kategori': 'Hiburan', 'tipe': 'expense', 'ikon': 'movie', 'warna': '#FDBA74'},
      {'nama_kategori': 'Kesehatan', 'tipe': 'expense', 'ikon': 'medical_services', 'warna': '#86EFAC'},
      {'nama_kategori': 'Tagihan', 'tipe': 'expense', 'ikon': 'receipt_long', 'warna': '#BFDBFE'},
      {'nama_kategori': 'Lainnya', 'tipe': 'expense', 'ikon': 'more_horiz', 'warna': '#D6D3D1'},
      {'nama_kategori': 'Gaji', 'tipe': 'income', 'ikon': 'account_balance', 'warna': '#A5D6A7'},
      {'nama_kategori': 'Transfer Masuk', 'tipe': 'income', 'ikon': 'swap_horiz', 'warna': '#90CAF9'},
    ];

    for (final cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  // ========================
  // USERS CRUD
  // ========================
  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> getUserById(String userId) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );
  }

  // ========================
  // CATEGORIES CRUD
  // ========================
  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories');
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }

  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'tipe = ?',
      whereArgs: [type],
    );
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'kategori_id = ?',
      whereArgs: [category.kategoriId],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'kategori_id = ?',
      whereArgs: [id],
    );
  }

  // ========================
  // TRANSACTIONS CRUD
  // ========================
  Future<int> insertTransaction(TransactionModel trx) async {
    final db = await database;
    return await db.insert('transactions', trx.toMap());
  }

  Future<List<TransactionModel>> getTransactionsByUser(String userId, {int? limit}) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT t.*, c.nama_kategori, c.tipe, c.ikon, c.warna
      FROM transactions t
      LEFT JOIN categories c ON t.kategori_id = c.kategori_id
      WHERE t.user_id = ?
      ORDER BY t.tanggal_trx DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', [userId]);
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(
    String userId, DateTime start, DateTime end,
  ) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT t.*, c.nama_kategori, c.tipe, c.ikon, c.warna
      FROM transactions t
      LEFT JOIN categories c ON t.kategori_id = c.kategori_id
      WHERE t.user_id = ? AND t.tanggal_trx BETWEEN ? AND ?
      ORDER BY t.tanggal_trx DESC
    ''', [userId, start.toIso8601String(), end.toIso8601String()]);
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<int> deleteTransaction(String trxId) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'trx_id = ?',
      whereArgs: [trxId],
    );
  }

  Future<double> getTotalByType(
    String userId, String type, DateTime start, DateTime end,
  ) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(nominal), 0) as total
      FROM transactions
      WHERE user_id = ? AND tipe_trx = ? AND tanggal_trx BETWEEN ? AND ?
    ''', [userId, type, start.toIso8601String(), end.toIso8601String()]);
    return (result.first['total'] as num).toDouble();
  }

  Future<Map<int, double>> getExpenseByCategory(
    String userId, DateTime start, DateTime end,
  ) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT kategori_id, SUM(nominal) as total
      FROM transactions
      WHERE user_id = ? AND tipe_trx = 'expense' AND tanggal_trx BETWEEN ? AND ?
      GROUP BY kategori_id
      ORDER BY total DESC
    ''', [userId, start.toIso8601String(), end.toIso8601String()]);

    final map = <int, double>{};
    for (final row in result) {
      map[row['kategori_id'] as int] = (row['total'] as num).toDouble();
    }
    return map;
  }

  // ========================
  // REPORT_HISTORIES CRUD
  // ========================
  Future<int> insertReport(ReportHistoryModel report) async {
    final db = await database;
    return await db.insert('report_histories', report.toMap());
  }

  Future<List<ReportHistoryModel>> getReportsByUser(String userId) async {
    final db = await database;
    final maps = await db.query(
      'report_histories',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'tanggal_dibuat DESC',
    );
    return maps.map((map) => ReportHistoryModel.fromMap(map)).toList();
  }

  Future<int> deleteReport(String reportId) async {
    final db = await database;
    return await db.delete(
      'report_histories',
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }

  // ========================
  // SCHEDULES CRUD
  // ========================
  Future<int> insertSchedule(ScheduleModel schedule) async {
    final db = await database;
    return await db.insert('schedules', schedule.toMap());
  }

  Future<List<ScheduleModel>> getSchedulesByUser(String userId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.*, c.nama_kategori, c.tipe, c.ikon, c.warna
      FROM schedules s
      LEFT JOIN categories c ON s.kategori_id = c.kategori_id
      WHERE s.user_id = ?
      ORDER BY s.tanggal_jatuh_tempo ASC
    ''', [userId]);
    return maps.map((map) => ScheduleModel.fromMap(map)).toList();
  }

  Future<List<ScheduleModel>> getUpcomingSchedules(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.rawQuery('''
      SELECT s.*, c.nama_kategori, c.tipe, c.ikon, c.warna
      FROM schedules s
      LEFT JOIN categories c ON s.kategori_id = c.kategori_id
      WHERE s.user_id = ? AND s.tanggal_jatuh_tempo >= ?
      ORDER BY s.tanggal_jatuh_tempo ASC
    ''', [userId, now]);
    return maps.map((map) => ScheduleModel.fromMap(map)).toList();
  }

  Future<int> updateSchedule(ScheduleModel schedule) async {
    final db = await database;
    return await db.update(
      'schedules',
      schedule.toMap(),
      where: 'jadwal_id = ?',
      whereArgs: [schedule.jadwalId],
    );
  }

  Future<int> deleteSchedule(String jadwalId) async {
    final db = await database;
    return await db.delete(
      'schedules',
      where: 'jadwal_id = ?',
      whereArgs: [jadwalId],
    );
  }

  // ========================
  // UTILITY
  // ========================
  Future<void> deleteAllUserData(String userId) async {
    final db = await database;
    await db.delete('transactions', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('schedules', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('report_histories', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('notifications', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> deleteAccount(String userId) async {
    final db = await database;
    await deleteAllUserData(userId);
    await db.delete('users', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ========================
  // CLOUD SYNC HELPERS
  // ========================
  Future<Map<String, dynamic>> exportUserDataToJson(String userId) async {
    final db = await database;
    
    final userResult = await db.query('users', where: 'user_id = ?', whereArgs: [userId]);
    final walletsResult = await db.query('wallets', where: 'user_id = ?', whereArgs: [userId]);
    final transactionsResult = await db.query('transactions', where: 'user_id = ?', whereArgs: [userId]);
    final schedulesResult = await db.query('schedules', where: 'user_id = ?', whereArgs: [userId]);
    final reportHistoriesResult = await db.query('report_histories', where: 'user_id = ?', whereArgs: [userId]);
    final notificationsResult = await db.query('notifications', where: 'user_id = ?', whereArgs: [userId]);
    
    // Categories are shared globally, but we can export custom ones if needed. 
    // Currently, we'll export all categories just in case the new device doesn't have them.
    final categoriesResult = await db.query('categories');

    return {
      'users': userResult,
      'wallets': walletsResult,
      'transactions': transactionsResult,
      'schedules': schedulesResult,
      'report_histories': reportHistoriesResult,
      'categories': categoriesResult,
      'notifications': notificationsResult,
    };
  }

  Future<void> importUserDataFromJson(String userId, Map<String, dynamic> data) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Clear existing data for this user to avoid duplication/conflicts
      await txn.delete('transactions', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('schedules', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('report_histories', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('wallets', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('users', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('notifications', where: 'user_id = ?', whereArgs: [userId]);
      // Categories are somewhat global, so we might want to be careful.
      // Easiest is to use REPLACE or INSERT OR IGNORE for categories.

      if (data['categories'] != null) {
        for (var cat in data['categories']) {
          await txn.insert('categories', Map<String, dynamic>.from(cat), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (data['users'] != null) {
        for (var u in data['users']) {
          await txn.insert('users', Map<String, dynamic>.from(u), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (data['wallets'] != null) {
        for (var w in data['wallets']) {
          await txn.insert('wallets', Map<String, dynamic>.from(w), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (data['transactions'] != null) {
        for (var t in data['transactions']) {
          await txn.insert('transactions', Map<String, dynamic>.from(t), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (data['schedules'] != null) {
        for (var s in data['schedules']) {
          await txn.insert('schedules', Map<String, dynamic>.from(s), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (data['report_histories'] != null) {
        for (var r in data['report_histories']) {
          await txn.insert('report_histories', Map<String, dynamic>.from(r), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (data['notifications'] != null) {
        for (var n in data['notifications']) {
          await txn.insert('notifications', Map<String, dynamic>.from(n), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  // ========================
  // NOTIFICATIONS CRUD
  // ========================
  Future<int> insertNotification(String notifId, String userId, String title, String body, String tanggal) async {
    final db = await database;
    final existing = await db.query(
      'notifications',
      where: 'notification_id = ?',
      whereArgs: [notifId],
    );
    if (existing.isNotEmpty) {
      return await db.update(
        'notifications',
        {
          'title': title,
          'body': body,
          'tanggal': tanggal,
        },
        where: 'notification_id = ?',
        whereArgs: [notifId],
      );
    } else {
      return await db.insert(
        'notifications',
        {
          'notification_id': notifId,
          'user_id': userId,
          'title': title,
          'body': body,
          'tanggal': tanggal,
          'is_read': 0,
          'is_deleted': 0,
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> getReceivedNotifications(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      'notifications',
      where: 'user_id = ? AND tanggal <= ? AND is_deleted = 0',
      whereArgs: [userId, now],
      orderBy: 'tanggal DESC',
    );
  }

  Future<bool> hasUnreadNotifications(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM notifications 
      WHERE user_id = ? AND tanggal <= ? AND is_read = 0 AND is_deleted = 0
    ''', [userId, now]);
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  Future<int> getUnreadNotificationsCount(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM notifications 
      WHERE user_id = ? AND tanggal <= ? AND is_read = 0 AND is_deleted = 0
    ''', [userId, now]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationAsRead(String notifId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'notification_id = ?',
      whereArgs: [notifId],
    );
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ? AND tanggal <= ? AND is_deleted = 0',
      whereArgs: [userId, now],
    );
  }

  Future<int> deleteNotification(String notifId) async {
    final db = await database;
    return await db.update(
      'notifications',
      {'is_deleted': 1},
      where: 'notification_id = ?',
      whereArgs: [notifId],
    );
  }

  Future<int> deleteAllNotifications(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'notifications',
      {'is_deleted': 1},
      where: 'user_id = ? AND tanggal <= ?',
      whereArgs: [userId, now],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
