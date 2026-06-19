import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bcrypt/bcrypt.dart';

import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;
  static String? _databasePath;

  static Future<String> get databasePath async {
    if (_databasePath != null) return _databasePath!;
    final documentsDir = await getApplicationDocumentsDirectory();
    _databasePath = p.join(documentsDir.path, AppConstants.dbName);
    return _databasePath!;
  }

  static bool _ffiInitialized = false;

  static Future<void> ensureInitialized() async {
    if (!_ffiInitialized &&
        (defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.linux ||
         defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    await ensureInitialized();
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, AppConstants.dbName);

    final db = await openDatabase(
      dbPath,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schema_version (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.execute("INSERT INTO schema_version (version) VALUES ($version)");

    await db.execute('''
      CREATE TABLE gyms (
        gym_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        owner_name TEXT,
        phone TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        address TEXT,
        logo_path TEXT,
        email TEXT,
        whatsapp TEXT,
        opening_time TEXT,
        closing_time TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE super_admin (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        must_change_password INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await _seedSuperAdmin(db);

    await db.execute('''
      CREATE TABLE packages (
        package_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        name TEXT NOT NULL,
        duration_days INTEGER NOT NULL,
        price INTEGER NOT NULL,
        monthly_fee INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        member_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        full_name TEXT NOT NULL,
        father_name TEXT,
        cnic TEXT,
        phone TEXT,
        emergency_contact TEXT,
        gender TEXT,
        dob TEXT,
        address TEXT,
        photo_path TEXT,
        height REAL,
        weight REAL,
        bmi REAL,
        fitness_goal TEXT,
        fingerprint_template BLOB,
        qr_data TEXT,
        registration_date TEXT NOT NULL DEFAULT (datetime('now')),
        package_id TEXT,
        start_date TEXT,
        expiry_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        fee_status TEXT NOT NULL DEFAULT 'paid',
        last_fee_paid_date TEXT,
        fee_due_date TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE,
        FOREIGN KEY (package_id) REFERENCES packages(package_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        attendance_id INTEGER PRIMARY KEY AUTOINCREMENT,
        gym_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        date TEXT NOT NULL,
        check_in TEXT,
        check_out TEXT,
        method TEXT NOT NULL DEFAULT 'manual',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        payment_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        package_id TEXT,
        amount INTEGER NOT NULL,
        discount INTEGER NOT NULL DEFAULT 0,
        tax INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL,
        method TEXT NOT NULL,
        remarks TEXT,
        received_by TEXT,
        payment_date TEXT NOT NULL DEFAULT (datetime('now')),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        invoice_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        payment_id TEXT,
        invoice_number TEXT NOT NULL,
        package_name TEXT,
        amount INTEGER NOT NULL,
        discount INTEGER NOT NULL DEFAULT 0,
        tax INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'paid',
        invoice_date TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
        FOREIGN KEY (payment_id) REFERENCES payments(payment_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE trainers (
        trainer_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        cnic TEXT,
        salary INTEGER NOT NULL DEFAULT 0,
        specialization TEXT,
        joining_date TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE trainer_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trainer_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        gym_id TEXT NOT NULL,
        assigned_date TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (trainer_id) REFERENCES trainers(trainer_id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE,
        UNIQUE(trainer_id, member_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE equipment (
        equipment_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        name TEXT NOT NULL,
        brand TEXT,
        category TEXT NOT NULL DEFAULT 'general',
        purchase_date TEXT,
        cost INTEGER NOT NULL DEFAULT 0,
        warranty_date TEXT,
        condition TEXT NOT NULL DEFAULT 'Good',
        status TEXT NOT NULL DEFAULT 'In Use',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance (
        maintenance_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        equipment_id TEXT NOT NULL,
        service_date TEXT NOT NULL DEFAULT (datetime('now')),
        technician_name TEXT,
        repair_cost INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        next_service_date TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE,
        FOREIGN KEY (equipment_id) REFERENCES equipment(equipment_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        expense_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        description TEXT,
        expense_date TEXT NOT NULL DEFAULT (datetime('now')),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory (
        item_id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        cost_price INTEGER NOT NULL DEFAULT 0,
        selling_price INTEGER NOT NULL DEFAULT 0,
        reorder_level INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        setting_id INTEGER PRIMARY KEY AUTOINCREMENT,
        gym_id TEXT NOT NULL UNIQUE,
        theme TEXT NOT NULL DEFAULT 'system',
        currency TEXT NOT NULL DEFAULT 'PKR',
        backup_frequency TEXT NOT NULL DEFAULT 'daily',
        receipt_header TEXT,
        receipt_footer TEXT,
        expiry_warning_days INTEGER NOT NULL DEFAULT 7,
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
        gym_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        reference_id TEXT,
        reference_type TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gym_id) REFERENCES gyms(gym_id) ON DELETE CASCADE
      )
    ''');

    await _createSessionTable(db);
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSessionTable(db);
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE packages ADD COLUMN monthly_fee INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE members ADD COLUMN fee_status TEXT NOT NULL DEFAULT 'paid'");
      await db.execute("ALTER TABLE members ADD COLUMN last_fee_paid_date TEXT");
      await db.execute("ALTER TABLE members ADD COLUMN fee_due_date TEXT");
    }
    await db.execute("INSERT INTO schema_version (version) VALUES ($newVersion)");
  }

  Future<void> _createSessionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        session_data TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_members_gym ON members(gym_id)');
    await db.execute('CREATE INDEX idx_members_status ON members(status)');
    await db.execute('CREATE INDEX idx_attendance_gym ON attendance(gym_id)');
    await db.execute('CREATE INDEX idx_attendance_member ON attendance(member_id)');
    await db.execute('CREATE INDEX idx_attendance_date ON attendance(date)');
    await db.execute('CREATE INDEX idx_payments_gym ON payments(gym_id)');
    await db.execute('CREATE INDEX idx_payments_member ON payments(member_id)');
    await db.execute('CREATE INDEX idx_payments_date ON payments(payment_date)');
    await db.execute('CREATE INDEX idx_expenses_gym ON expenses(gym_id)');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(expense_date)');
    await db.execute('CREATE INDEX idx_inventory_gym ON inventory(gym_id)');
    await db.execute('CREATE INDEX idx_notifications_gym ON notifications(gym_id)');
    await db.execute('CREATE INDEX idx_packages_gym ON packages(gym_id)');
    await db.execute('CREATE INDEX idx_trainers_gym ON trainers(gym_id)');
    await db.execute('CREATE INDEX idx_equipment_gym ON equipment(gym_id)');
  }

  Future<void> _seedSuperAdmin(Database db) async {
    final hash = BCrypt.hashpw(AppConstants.defaultAdminPassword, BCrypt.gensalt());
    await db.insert('super_admin', {
      'username': AppConstants.defaultAdminUsername,
      'password_hash': hash,
      'must_change_password': 1,
    });
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
