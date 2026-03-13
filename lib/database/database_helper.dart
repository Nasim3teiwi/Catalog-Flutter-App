import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/order.dart' as app;
import '../models/order_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'catalog_app.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        image TEXT,
        price REAL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_name TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        delivered_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        product_name TEXT,
        product_price REAL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await _seedProducts(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2 added categories table (now removed)
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
      // Drop categories table and category column from products
      await db.execute('DROP TABLE IF EXISTS categories');
      // SQLite doesn't support DROP COLUMN before 3.35.0, so we recreate
      await db.execute('''
        CREATE TABLE products_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          image TEXT,
          price REAL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        INSERT INTO products_new (id, name, description, image, price, is_active)
        SELECT id, name, description, image, price, is_active FROM products
      ''');
      await db.execute('DROP TABLE products');
      await db.execute('ALTER TABLE products_new RENAME TO products');
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
      );
      await db.execute('ALTER TABLE orders ADD COLUMN delivered_at TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE order_items ADD COLUMN product_name TEXT');
      await db.execute('ALTER TABLE order_items ADD COLUMN product_price REAL');
    }
  }

  Future<void> _seedProducts(Database db) async {
    final products = [
      {
        'name': 'سماعات لاسلكية',
        'description':
            'سماعات لاسلكية فاخرة بخاصية إلغاء الضوضاء وبطارية تدوم 30 ساعة. صوت نقي وباس عميق. تصميم مريح يغطي الأذن بالكامل للاستخدام المطوّل.',
        'image': 'assets/images/headphones.png',
        'price': 89.99,
      },
      {
        'name': 'ساعة ذكية',
        'description':
            'ساعة ذكية متعددة المزايا مع مراقبة صحية وتتبع GPS وبطارية تدوم 7 أيام. مقاومة للماء بشاشة AMOLED نابضة بالألوان.',
        'image': 'assets/images/smartwatch.png',
        'price': 199.99,
      },
      {
        'name': 'سماعة بلوتوث',
        'description':
            'سماعة بلوتوث محمولة مقاومة للماء بصوت محيطي 360 درجة. تشغيل مستمر 12 ساعة مع ميكروفون مدمج للمكالمات.',
        'image': 'assets/images/speaker.png',
        'price': 49.99,
      },
      {
        'name': 'حامل لابتوب',
        'description':
            'حامل لابتوب من الألومنيوم بتصميم مريح وارتفاع قابل للتعديل. يحسّن وضعية الجلوس ويبقي اللابتوب بارداً. قابل للطي لسهولة التنقل.',
        'image': 'assets/images/laptop_stand.png',
        'price': 34.99,
      },
      {
        'name': 'موزع USB-C',
        'description':
            'موزع USB-C بـ 7 منافذ يشمل HDMI وUSB 3.0 وقارئ بطاقات SD وشحن PD. متوافق مع جميع أجهزة اللابتوب والأجهزة اللوحية.',
        'image': 'assets/images/usb_hub.png',
        'price': 29.99,
      },
      {
        'name': 'لوحة مفاتيح ميكانيكية',
        'description':
            'لوحة مفاتيح ميكانيكية لاسلكية مدمجة بإضاءة RGB خلفية. مفاتيح Cherry MX لتجربة كتابة ممتازة. اتصال بلوتوث متعدد الأجهزة.',
        'image': 'assets/images/keyboard.png',
        'price': 74.99,
      },
      {
        'name': 'ماوس لاسلكي',
        'description':
            'ماوس لاسلكي مريح بدقة DPI قابلة للتعديل حتى 4000. نقرات صامتة وتتبع سلس للغاية. قابل للشحن عبر USB-C.',
        'image': 'assets/images/mouse.png',
        'price': 24.99,
      },
      {
        'name': 'غطاء هاتف',
        'description':
            'غطاء هاتف نحيف بحماية عسكرية من السقوط. متوفر بعدة ألوان بتشطيب مطفي مقاوم لبصمات الأصابع.',
        'image': 'assets/images/phone_case.png',
        'price': 14.99,
      },
      {
        'name': 'باور بانك',
        'description':
            'باور بانك محمول بسعة 20000mAh مع دعم الشحن السريع. منفذي USB للإخراج ومنفذ USB-C للإدخال. شاشة LED تعرض نسبة الشحن المتبقية.',
        'image': 'assets/images/power_bank.png',
        'price': 39.99,
      },
      {
        'name': 'كاميرا ويب HD',
        'description':
            'كاميرا ويب بدقة 1080p مع إضاءة حلقية مدمجة وميكروفون مزدوج. تركيز تلقائي وتصحيح الإضاءة المنخفضة لمكالمات فيديو احترافية.',
        'image': 'assets/images/webcam.png',
        'price': 59.99,
      },
      {
        'name': 'مصباح مكتب',
        'description':
            'مصباح مكتب LED بدرجة حرارة لونية وسطوع قابلين للتعديل. تحكم باللمس مع منفذ شحن USB. تقنية حماية العين.',
        'image': 'assets/images/desk_lamp.png',
        'price': 44.99,
      },
      {
        'name': 'طقم دفاتر',
        'description':
            'طقم دفاتر فاخرة بغلاف صلب يضم 3 دفاتر. صفحات منقطة ومسطرة وفارغة. ورق خالٍ من الحمض بوزن 120 جرام. تجليد مسطح.',
        'image': 'assets/images/notebook.png',
        'price': 19.99,
      },
    ];

    for (final product in products) {
      await db.insert('products', product);
    }
  }

  // Product operations
  Future<List<Product>> getProducts({bool activeOnly = false}) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap()..remove('id'));
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<Product?> getProduct(int id) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  // Order operations
  Future<int> insertOrder(app.Order order) async {
    final db = await database;
    return await db.insert('orders', order.toMap()..remove('id'));
  }

  Future<List<app.Order>> getOrders() async {
    final db = await database;
    final maps = await db.query('orders', orderBy: 'date DESC');
    return maps.map((map) => app.Order.fromMap(map)).toList();
  }

  Future<app.Order?> getOrder(int id) async {
    final db = await database;
    final maps = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return app.Order.fromMap(maps.first);
  }

  Future<void> deleteOrder(int id) async {
    final db = await database;
    await db.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateOrderStatus({
    required int orderId,
    required String status,
    DateTime? deliveredAt,
  }) async {
    final db = await database;
    await db.update(
      'orders',
      {
        'status': status,
        'delivered_at': deliveredAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> updateOrderDate({
    required int orderId,
    required DateTime date,
  }) async {
    final db = await database;
    await db.update(
      'orders',
      {'date': date.toIso8601String()},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // Order item operations
  Future<void> insertOrderItem(OrderItem item) async {
    final db = await database;
    await db.insert('order_items', item.toMap()..remove('id'));
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final db = await database;
    final maps = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    return maps.map((map) => OrderItem.fromMap(map)).toList();
  }

  Future<int> getOrderItemCount(int orderId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantity) as total FROM order_items WHERE order_id = ?',
      [orderId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> updateOrderItemQuantity({
    required int orderItemId,
    required int quantity,
  }) async {
    final db = await database;
    await db.update(
      'order_items',
      {'quantity': quantity},
      where: 'id = ?',
      whereArgs: [orderItemId],
    );
  }

  Future<void> deleteOrderItem(int orderItemId) async {
    final db = await database;
    await db.delete(
      'order_items',
      where: 'id = ?',
      whereArgs: [orderItemId],
    );
  }
}
