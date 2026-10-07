import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_user.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/supplier.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;
  String? _dbPath;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  String get databaseFile => _dbPath ?? '';

  Future<bool> databaseFileExists() async {
    if (_dbPath != null) return File(_dbPath!).existsSync();
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'boutix', 'boutique.db');
    return File(path).existsSync();
  }

  Future<Database> _init() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    _dbPath = p.join(dir.path, 'boutix', 'boutique.db');
    await Directory(p.dirname(_dbPath!)).create(recursive: true);

    final db = await openDatabase(
      _dbPath!,
      version: 1,
      onCreate: _onCreate,
    );
    await _seedIfNeeded(db);
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        full_name TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        size TEXT NOT NULL DEFAULT '',
        color TEXT NOT NULL DEFAULT '',
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        barcode TEXT NOT NULL DEFAULT '',
        supplier_id INTEGER REFERENCES suppliers(id),
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute(
        "CREATE UNIQUE INDEX idx_products_barcode ON products(barcode) WHERE barcode != ''");

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        created_at TEXT NOT NULL,
        subtotal_ht REAL NOT NULL,
        tva_rate REAL NOT NULL,
        tva_amount REAL NOT NULL,
        discount_pct REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        total_ttc REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        customer_name TEXT,
        customer_email TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id),
        quantity INTEGER NOT NULL,
        unit_price_ht REAL NOT NULL,
        line_total_ht REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        qty_delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        ref_sale_id INTEGER,
        user_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _seedIfNeeded(Database db) async {
    // Pas de compte admin par défaut : créé à la 1re utilisation.

    const defaults = {
      'shop_name': 'Ma Boutique',
      'shop_phone': '',
      'shop_address': '',
      'tva_rate': '0',
      'low_stock_threshold': '5',
      'logo_path': '',
      'currency_label': 'DA',
      'setup_completed': '0',
    };

    for (final entry in defaults.entries) {
      final existing = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [entry.key],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('app_settings', {
          'key': entry.key,
          'value': entry.value,
        });
      }
    }
  }

  /// True si aucun utilisateur n'existe encore (1re utilisation).
  Future<bool> needsFirstRunSetup() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM users');
    final count = (r.first['c'] as num?)?.toInt() ?? 0;
    return count == 0;
  }

  // --- Settings ---

  Future<String> getSetting(String key, [String fallback = '']) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return fallback;
    return rows.first['value'] as String? ?? fallback;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double> getTvaRate() async {
    final s = await getSetting('tva_rate', '0');
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }

  Future<int> getLowStockThreshold() async {
    final s = await getSetting('low_stock_threshold', '5');
    return int.tryParse(s) ?? 5;
  }

  Future<String> getCurrency() async {
    final c = (await getSetting('currency_label', 'DA')).trim();
    return c.isEmpty ? 'DA' : c;
  }

  // --- Users ---

  Future<List<AppUser>> getActiveUsers() async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'active = 1',
      orderBy: 'username COLLATE NOCASE',
    );
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<List<AppUser>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'username COLLATE NOCASE');
    return rows.map((r) => AppUser.fromMap(r)).toList();
  }

  Future<AppUser?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [username.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<int> insertUser(AppUser user) async {
    final db = await database;
    return db.insert('users', user.toMap()..remove('id'));
  }

  Future<void> updateUser(AppUser user) async {
    final db = await database;
    await db.update('users', user.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [user.id]);
  }

  Future<bool> hasUsers() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM users');
    return (r.first['c'] as int) > 0;
  }

  // --- Products ---

  Future<List<Product>> getProducts({
    String? search,
    String? category,
    String? size,
    bool lowStockOnly = false,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (search != null && search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR barcode LIKE ?)');
      final like = '%${search.trim()}%';
      args.addAll([like, like]);
    }
    if (category != null && category.trim().isNotEmpty) {
      where.add('category = ?');
      args.add(category.trim());
    }
    if (size != null && size.trim().isNotEmpty) {
      where.add('size = ?');
      args.add(size.trim());
    }
    if (lowStockOnly) {
      final low = await getLowStockThreshold();
      where.add('stock < ?');
      args.add(low);
    }

    final rows = await db.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query('products', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap()..remove('id'));
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final rows = await db.rawQuery(
        "SELECT DISTINCT category FROM products WHERE category != '' ORDER BY category");
    return rows.map((r) => r['category'] as String).toList();
  }

  // --- Suppliers ---

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final rows = await db.query('suppliers', orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => Supplier.fromMap(r)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final db = await database;
    final rows =
        await db.query('suppliers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Supplier.fromMap(rows.first);
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return db.insert('suppliers', supplier.toMap()..remove('id'));
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await database;
    await db.update('suppliers', supplier.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<void> deleteSupplier(int id) async {
    final db = await database;
    await db.update('products', {'supplier_id': null},
        where: 'supplier_id = ?', whereArgs: [id]);
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // --- Stock movements ---

  Future<List<Map<String, Object?>>> getStockMovements({int limit = 400}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT m.*, p.name as product_name, p.barcode
      FROM stock_movements m
      LEFT JOIN products p ON p.id = m.product_id
      ORDER BY m.created_at DESC, m.id DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<void> adjustStock({
    required int productId,
    required int newStock,
    int? userId,
    String note = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
      if (rows.isEmpty) throw Exception('Article introuvable.');
      final current = rows.first['stock'] as int;
      final delta = newStock - current;
      if (delta == 0) return;
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'products',
        {'stock': newStock, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );
      final reason = note.trim().isEmpty ? 'adjust' : 'adjust:${note.trim()}';
      await txn.insert('stock_movements', {
        'product_id': productId,
        'qty_delta': delta,
        'reason': reason,
        'ref_sale_id': null,
        'user_id': userId,
        'created_at': now,
      });
    });
  }

  // --- Sales ---

  Future<int> createSale({
    required int userId,
    required List<({int productId, int qty, double unitPriceHt, double lineTotalHt})> lines,
    required double tvaRate,
    required double discountPct,
    required double discountAmount,
    required String paymentMethod,
    String? customerName,
    String? customerEmail,
    String? notes,
  }) async {
    if (lines.isEmpty) throw Exception('Le panier est vide.');

    final db = await database;
    return db.transaction((txn) async {
      for (final line in lines) {
        final rows = await txn.query('products', where: 'id = ?', whereArgs: [line.productId], limit: 1);
        if (rows.isEmpty) throw Exception('Produit introuvable.');
        final stock = rows.first['stock'] as int;
        final name = rows.first['name'] as String;
        if (stock < line.qty) {
          throw Exception('Stock insuffisant pour « $name » ($stock disponible(s)).');
        }
      }

      final subtotalHt = lines.fold<double>(0, (s, l) => s + l.lineTotalHt);
      final discPctVal = discountPct > 0 ? subtotalHt * (discountPct / 100) : 0;
      final htAfter = (subtotalHt - discPctVal - discountAmount).clamp(0, double.infinity);
      final tvaAmount = htAfter * tvaRate;
      final totalTtc = htAfter + tvaAmount;
      final now = DateTime.now().toIso8601String();

      final saleId = await txn.insert('sales', {
        'user_id': userId,
        'created_at': now,
        'subtotal_ht': double.parse(subtotalHt.toStringAsFixed(2)),
        'tva_rate': tvaRate,
        'tva_amount': double.parse(tvaAmount.toStringAsFixed(2)),
        'discount_pct': discountPct,
        'discount_amount': double.parse(discountAmount.toStringAsFixed(2)),
        'total_ttc': double.parse(totalTtc.toStringAsFixed(2)),
        'payment_method': paymentMethod,
        'customer_name': customerName?.trim().isEmpty == true ? null : customerName?.trim(),
        'customer_email': customerEmail?.trim().isEmpty == true ? null : customerEmail?.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      });

      for (final line in lines) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': line.productId,
          'quantity': line.qty,
          'unit_price_ht': double.parse(line.unitPriceHt.toStringAsFixed(2)),
          'line_total_ht': double.parse(line.lineTotalHt.toStringAsFixed(2)),
        });

        final rows = await txn.query('products', where: 'id = ?', whereArgs: [line.productId], limit: 1);
        final stock = rows.first['stock'] as int;
        await txn.update(
          'products',
          {'stock': stock - line.qty, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [line.productId],
        );
        await txn.insert('stock_movements', {
          'product_id': line.productId,
          'qty_delta': -line.qty,
          'reason': 'sale',
          'ref_sale_id': saleId,
          'user_id': userId,
          'created_at': now,
        });
      }

      return saleId;
    });
  }

  Future<List<Map<String, Object?>>> listSales({
    DateTime? from,
    DateTime? to,
    int limit = 2000,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (from != null) {
      where.add('date(s.created_at) >= date(?)');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('date(s.created_at) <= date(?)');
      args.add(to.toIso8601String());
    }

    return db.rawQuery('''
      SELECT s.*, u.username
      FROM sales s
      LEFT JOIN users u ON u.id = s.user_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY s.created_at DESC
      LIMIT ?
    ''', [...args, limit]);
  }

  Future<Map<String, Object?>?> getSaleWithItems(int saleId) async {
    final db = await database;
    final sales = await db.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
    if (sales.isEmpty) return null;

    final items = await db.rawQuery('''
      SELECT si.*, p.name as product_name
      FROM sale_items si
      JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
    ''', [saleId]);

    return {'sale': sales.first, 'items': items};
  }

  // --- Statistics ---

  Future<Map<String, dynamic>> getDashboardKpis() async {
    final db = await database;
    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day).toIso8601String();
    final monthStart = DateTime(today.year, today.month, 1).toIso8601String();
    final low = await getLowStockThreshold();

    final caToday = await db.rawQuery('''
      SELECT COALESCE(SUM(total_ttc), 0) as v, COUNT(*) as c
      FROM sales WHERE date(created_at) >= date(?)
    ''', [todayStr]);

    final caMonth = await db.rawQuery('''
      SELECT COALESCE(SUM(total_ttc), 0) as v, COUNT(*) as c
      FROM sales WHERE date(created_at) >= date(?)
    ''', [monthStart]);

    final productsCountRow =
        await db.rawQuery('SELECT COUNT(*) as c FROM products');
    final productsCount = productsCountRow.first['c'] as int? ?? 0;
    final lowStockRow = await db.rawQuery(
        'SELECT COUNT(*) as c FROM products WHERE stock < ?', [low]);
    final lowStock = lowStockRow.first['c'] as int? ?? 0;

    return {
      'ca_today': (caToday.first['v'] as num?)?.toDouble() ?? 0,
      'ventes_today': caToday.first['c'] as int? ?? 0,
      'ca_month': (caMonth.first['v'] as num?)?.toDouble() ?? 0,
      'ventes_month': caMonth.first['c'] as int? ?? 0,
      'products_count': productsCount,
      'low_stock_count': lowStock,
    };
  }

  Future<List<Map<String, Object?>>> getTopProducts30d({int limit = 8}) async {
    final db = await database;
    final from = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    return db.rawQuery('''
      SELECT p.name, SUM(si.quantity) as qty
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      JOIN products p ON p.id = si.product_id
      WHERE s.created_at >= ?
      GROUP BY si.product_id
      ORDER BY qty DESC
      LIMIT ?
    ''', [from, limit]);
  }

  Future<List<Map<String, Object?>>> getLowStockProducts({int limit = 12}) async {
    final db = await database;
    final low = await getLowStockThreshold();
    return db.query(
      'products',
      columns: ['name', 'stock'],
      where: 'stock < ?',
      whereArgs: [low],
      orderBy: 'stock ASC',
      limit: limit,
    );
  }

  Future<void> backupDatabase(String destPath) async {
    await database;
    final dest = File(destPath);
    await dest.parent.create(recursive: true);
    await File(_dbPath!).copy(destPath);
  }

  /// Export vers Documents/Boutix/exports (chemin retourné).
  Future<String> exportDatabaseDefault() async {
    await database;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Boutix', 'exports'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final path = p.join(dir.path, 'boutix_export_$stamp.db');
    await File(_dbPath!).copy(path);
    return path;
  }

  Future<void> _ensureFfi() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<String> _resolveDbPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'boutix', 'boutique.db');
  }

  /// Remplace la base locale par un fichier .db exporté.
  Future<void> restoreDatabase(String sourcePath) async {
    final src = File(sourcePath);
    if (!src.existsSync()) {
      throw Exception('Fichier introuvable: $sourcePath');
    }
    final bytes = await src.openRead(0, 16).first;
    final header = String.fromCharCodes(bytes.take(15));
    if (!header.startsWith('SQLite format 3')) {
      throw Exception('Ce fichier n\'est pas une base SQLite valide.');
    }

    await _ensureFfi();
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    _dbPath = await _resolveDbPath();
    await Directory(p.dirname(_dbPath!)).create(recursive: true);
    await src.copy(_dbPath!);

    final db = await openDatabase(
      _dbPath!,
      version: 1,
      onCreate: _onCreate,
    );
    // Vérifie que la structure attendue existe.
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='users'",
    );
    if (tables.isEmpty) {
      await db.close();
      throw Exception('Base invalide: table users absente.');
    }
    await _seedIfNeeded(db);
    _db = db;
  }

  int _countFrom(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  /// Purge des ventes (fin d'année) : conserve articles, stock, fournisseurs,
  /// utilisateurs et paramètres. Efface ventes + lignes + mouvements de vente.
  Future<({int sales, int items, int movements})> purgeSalesHistory() async {
    final db = await database;
    return db.transaction((txn) async {
      final salesCount = _countFrom(
        await txn.rawQuery('SELECT COUNT(*) AS c FROM sales'),
      );
      final itemsCount = _countFrom(
        await txn.rawQuery('SELECT COUNT(*) AS c FROM sale_items'),
      );
      final movCount = _countFrom(
        await txn.rawQuery(
          "SELECT COUNT(*) AS c FROM stock_movements WHERE reason = 'sale' OR ref_sale_id IS NOT NULL",
        ),
      );

      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete(
        'stock_movements',
        where: "reason = 'sale' OR ref_sale_id IS NOT NULL",
      );

      await txn.insert(
        'app_settings',
        {
          'key': 'last_sales_purge_at',
          'value': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return (sales: salesCount, items: itemsCount, movements: movCount);
    });
  }
}
