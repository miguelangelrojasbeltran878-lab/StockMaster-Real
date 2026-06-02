import 'package:hive_flutter/hive_flutter.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();
  static bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    if (!Hive.isBoxOpen('usuarios')) await Hive.openBox('usuarios');
    if (!Hive.isBoxOpen('productos')) await Hive.openBox('productos');
    if (!Hive.isBoxOpen('movimientos')) await Hive.openBox('movimientos');
    if (!Hive.isBoxOpen('categorias')) await Hive.openBox('categorias');
    _initialized = true;
  }

  Box _box(String name) => Hive.box(name);

  String _nextKey(String boxName) {
    final box = _box(boxName);
    final keys = box.keys.toList();
    if (keys.isEmpty) return '1';
    final maxKey = keys
        .map((k) => int.tryParse(k.toString()) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return (maxKey + 1).toString();
  }

  // ── USUARIOS ───────────────────────────────
  Future<void> insertUsuario(Map<String, dynamic> usuario) async {
    await init();
    final box = _box('usuarios');
    final existe =
        box.values.any((u) => (u as Map)['email'] == usuario['email']);
    if (existe) throw Exception('Email ya registrado');
    final key = _nextKey('usuarios');
    await box.put(key, Map<String, dynamic>.from({...usuario, 'id': key}));
  }

  Future<Map<String, dynamic>?> loginUsuario(
      String email, String password) async {
    await init();
    for (final u in _box('usuarios').values) {
      final user = Map<String, dynamic>.from(u as Map);
      if (user['email'].toString() == email &&
          user['password'].toString() == password) {
        return user;
      }
    }
    return null;
  }

  Future<bool> existeAlgunUsuario() async {
    await init();
    return _box('usuarios').isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getUsuarios() async {
    await init();
    return _box('usuarios')
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── PRODUCTOS ──────────────────────────────
  Future<void> insertProducto(Map<String, dynamic> producto) async {
    await init();
    final key = _nextKey('productos');
    await _box('productos')
        .put(key, Map<String, dynamic>.from({...producto, 'id': key}));
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    await init();
    final list = _box('productos')
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.sort((a, b) => (a['nombre'] ?? '')
        .toString()
        .compareTo((b['nombre'] ?? '').toString()));
    return list;
  }

  Future<void> updateProducto(Map<String, dynamic> producto) async {
    await init();
    await _box('productos')
        .put(producto['id'], Map<String, dynamic>.from(producto));
  }

  Future<void> deleteProducto(dynamic id) async {
    await init();
    await _box('productos').delete(id.toString());
  }

  Future<List<Map<String, dynamic>>> getProductosBajoStock() async {
    await init();
    return _box('productos')
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((p) =>
            (p['stock_actual'] as int? ?? 0) <=
            (p['stock_minimo'] as int? ?? 5))
        .toList();
  }

  // ── CATEGORIAS ─────────────────────────────
  Future<void> insertCategoria(Map<String, dynamic> categoria) async {
    await init();
    final key = _nextKey('categorias');
    await _box('categorias')
        .put(key, Map<String, dynamic>.from({...categoria, 'id': key}));
  }

  Future<List<Map<String, dynamic>>> getCategorias() async {
    await init();
    return _box('categorias')
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── MOVIMIENTOS ────────────────────────────
  Future<void> insertMovimiento(Map<String, dynamic> movimiento) async {
    await init();
    final key = _nextKey('movimientos');
    await _box('movimientos')
        .put(key, Map<String, dynamic>.from({...movimiento, 'id': key}));
  }

  Future<List<Map<String, dynamic>>> getMovimientos() async {
    await init();
    final list = _box('movimientos')
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.sort((a, b) =>
        (b['fecha'] ?? '').toString().compareTo((a['fecha'] ?? '').toString()));
    return list;
  }

  Future<void> deleteCategoria(dynamic id) async {
    await init();
    await _box('categorias').delete(id.toString());
  }

  Future<void> updateUsuario(Map<String, dynamic> usuario) async {
  await init();
  await _box('usuarios').put(
      usuario['id'].toString(),
      Map<String, dynamic>.from(usuario));
  }

  // ── PROVEEDORES ────────────────────────────
Future<void> insertProveedor(Map<String, dynamic> proveedor) async {
  await init();
  final key = _nextKey('proveedores');
  if (!Hive.isBoxOpen('proveedores')) await Hive.openBox('proveedores');
  await Hive.box('proveedores')
      .put(key, Map<String, dynamic>.from({...proveedor, 'id': key}));
}

Future<List<Map<String, dynamic>>> getProveedores() async {
  await init();
  if (!Hive.isBoxOpen('proveedores')) await Hive.openBox('proveedores');
  return Hive.box('proveedores')
      .values
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

Future<void> deleteProveedor(dynamic id) async {
  await init();
  await Hive.box('proveedores').delete(id.toString());
}

// ── ORDENES ────────────────────────────────
Future<void> insertOrden(Map<String, dynamic> orden) async {
  await init();
  if (!Hive.isBoxOpen('ordenes')) await Hive.openBox('ordenes');
  final key = _nextKey('ordenes');
  await Hive.box('ordenes')
      .put(key, Map<String, dynamic>.from({...orden, 'id': key}));
}

Future<List<Map<String, dynamic>>> getOrdenes() async {
  await init();
  if (!Hive.isBoxOpen('ordenes')) await Hive.openBox('ordenes');
  final list = Hive.box('ordenes')
      .values
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  list.sort((a, b) =>
      (b['fecha'] ?? '').toString().compareTo((a['fecha'] ?? '').toString()));
  return list;
}

Future<void> updateOrden(Map<String, dynamic> orden) async {
  await init();
  await Hive.box('ordenes')
      .put(orden['id'].toString(), Map<String, dynamic>.from(orden));
}

// ── LIMPIAR DATOS ──────────────────────────
Future<void> limpiarDatos() async {
  await init();
  await Hive.box('productos').clear();
  await Hive.box('categorias').clear();
  await Hive.box('movimientos').clear();
}
}
