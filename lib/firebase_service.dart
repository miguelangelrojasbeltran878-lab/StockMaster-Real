import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class StockService {
  static final StockService instance = StockService._();
  StockService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Auth ───────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  // Registrar empresa + admin
  Future<Map<String, dynamic>> registrarEmpresa({
  required String nombreEmpresa,
  required String adminNombre,
  required String email,
  required String password,
}) async {
  late UserCredential cred;
  
  try {
    // 1. Crear usuario en Firebase Auth
    cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  } catch (e) {
    throw Exception('Error al crear cuenta: $e');
  }

  final uid = cred.user!.uid;
  final codigo = _generarCodigo(nombreEmpresa);

  try {
    // 2. Crear empresa
    final empresaRef = _db.collection('empresas').doc();
    
    await empresaRef.set({
      'nombre': nombreEmpresa,
      'codigo_invitacion': codigo,
      'admin_uid': uid,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'plan': 'free',
    });

    // 3. Crear usuario admin dentro de la empresa
    await empresaRef.collection('usuarios').doc(uid).set({
      'nombre': adminNombre,
      'email': email,
      'rol': 'administrador',
      'activo': true,
      'fecha_registro': FieldValue.serverTimestamp(),
    });

    return {
      'empresaId': empresaRef.id,
      'codigo': codigo,
      'uid': uid,
    };
  } catch (e) {
    // Si falla Firestore borra el usuario de Auth para no dejar basura
    await cred.user?.delete();
    throw Exception('Error al guardar empresa: $e');
  }
}

  // Login
  Future<Map<String, dynamic>?> login(String email, String password) async {
  try {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final uid = cred.user!.uid;

    // Buscar empresa donde es admin
    final empresasSnap = await _db.collection('empresas')
        .where('admin_uid', isEqualTo: uid)
        .limit(1)
        .get();

    String? empresaId;

    if (empresasSnap.docs.isNotEmpty) {
      empresaId = empresasSnap.docs.first.id;
    } else {
      // Buscar como empleado — revisar todas las empresas
      // donde exista un usuario con este uid
      final todasEmpresas = await _db.collection('empresas').get();
      for (final empresa in todasEmpresas.docs) {
        final userDoc = await _db
            .collection('empresas')
            .doc(empresa.id)
            .collection('usuarios')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          empresaId = empresa.id;
          break;
        }
      }
    }

    if (empresaId == null) return null;

    final userDoc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('usuarios')
        .doc(uid)
        .get();

    if (!userDoc.exists) return null;

    final userData = Map<String, dynamic>.from(userDoc.data()!);
    userData['empresaId'] = empresaId;
    userData['uid'] = uid;

    return userData;
  } catch (e) {
    return null;
  }
}

  // Unirse a empresa con codigo de invitacion
  Future<bool> unirseConCodigo({
    required String codigo,
    required String nombre,
    required String email,
    required String password,
  }) async {
    // Buscar empresa por codigo
    final snap = await _db.collection('empresas')
        .where('codigo_invitacion', isEqualTo: codigo.toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return false;

    final empresaId = snap.docs.first.id;

    // Crear usuario en Auth
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final uid = cred.user!.uid;

    // Agregar como empleado a la empresa
    await _db.collection('empresas')
        .doc(empresaId)
        .collection('usuarios')
        .doc(uid)
        .set({
      'nombre': nombre,
      'email': email,
      'rol': 'empleado',
      'activo': true,
      'fecha_registro': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<void> logout() async => await _auth.signOut();

  // ── Empresa ────────────────────────────────────────────
  String? _empresaId;
  String get empresaId => _empresaId ?? '';

  void setEmpresaId(String id) => _empresaId = id;

  // ── Productos ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProductos() async {
    final snap = await _db.collection('empresas')
        .doc(empresaId).collection('productos').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> insertProducto(Map<String, dynamic> data) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('productos').add(data);
  }

  Future<void> updateProducto(Map<String, dynamic> data) async {
    final id = data['id'];
    final d = Map<String, dynamic>.from(data)..remove('id');
    await _db.collection('empresas')
        .doc(empresaId).collection('productos').doc(id).update(d);
  }

  Future<void> deleteProducto(String id) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('productos').doc(id).delete();
  }

  Future<List<Map<String, dynamic>>> getProductosBajoStock() async {
    final prods = await getProductos();
    return prods.where((p) =>
        (p['stock_actual'] as int? ?? 0) <=
        (p['stock_minimo'] as int? ?? 5)).toList();
  }

  // ── Categorias ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCategorias() async {
    final snap = await _db.collection('empresas')
        .doc(empresaId).collection('categorias').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> insertCategoria(Map<String, dynamic> data) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('categorias').add(data);
  }

  Future<void> deleteCategoria(String id) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('categorias').doc(id).delete();
  }

  // ── Movimientos ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMovimientos() async {
    final snap = await _db.collection('empresas')
        .doc(empresaId).collection('movimientos')
        .orderBy('fecha', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> insertMovimiento(Map<String, dynamic> data) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('movimientos').add({
      ...data,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  // ── Proveedores ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getProveedores() async {
    final snap = await _db.collection('empresas')
        .doc(empresaId).collection('proveedores').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> insertProveedor(Map<String, dynamic> data) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('proveedores').add(data);
  }

  Future<void> deleteProveedor(String id) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('proveedores').doc(id).delete();
  }

  // ── Ordenes ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOrdenes() async {
    final snap = await _db.collection('empresas')
        .doc(empresaId).collection('ordenes')
        .orderBy('fecha', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> insertOrden(Map<String, dynamic> data) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('ordenes').add(data);
  }

  Future<void> updateOrden(Map<String, dynamic> data) async {
    final id = data['id'];
    final d = Map<String, dynamic>.from(data)..remove('id');
    await _db.collection('empresas')
        .doc(empresaId).collection('ordenes').doc(id).update(d);
  }

  // ── Usuarios de la empresa ─────────────────────────────
  Future<List<Map<String, dynamic>>> getUsuarios() async {
    final snap = await _db.collection('empresas')
        .doc(empresaId).collection('usuarios').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> updateUsuario(Map<String, dynamic> data) async {
    final id = data['uid'] ?? data['id'];
    final d = Map<String, dynamic>.from(data)
      ..remove('uid')..remove('id')..remove('empresaId');
    await _db.collection('empresas')
        .doc(empresaId).collection('usuarios').doc(id).update(d);
  }

  Future<void> desactivarUsuario(String uid) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('usuarios').doc(uid).update({
      'activo': false,
    });
  }

  // ── Log de actividad ───────────────────────────────────
  Future<void> logActividad({
    required String accion,
    required String usuario,
    String? detalle,
  }) async {
    await _db.collection('empresas')
        .doc(empresaId).collection('actividad').add({
      'accion': accion,
      'usuario': usuario,
      'detalle': detalle ?? '',
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getActividad() async {
    final snap = await _db.collection('empresas')
        .doc(empresaId).collection('actividad')
        .orderBy('fecha', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ── Limpiar datos ──────────────────────────────────────
  Future<void> limpiarDatos() async {
    final collections = ['productos', 'categorias', 'movimientos'];
    for (final col in collections) {
      final snap = await _db.collection('empresas')
          .doc(empresaId).collection(col).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────
  String _generarCodigo(String nombre) {
    final prefix = nombre.length >= 4
        ? nombre.substring(0, 4).toUpperCase()
        : nombre.toUpperCase().padRight(4, 'X');
    final num = Random().nextInt(9000) + 1000;
    return '$prefix-$num';
  }

  Future<Map<String, dynamic>> getEmpresaInfo() async {
  final doc = await _db.collection('empresas').doc(empresaId).get();
  return doc.data() ?? {};
  }

  Future<List<Map<String, dynamic>>> getEmpleados(String empresaId) async {
  final query = await FirebaseFirestore.instance
      .collection('usuarios')
      .where('empresaId', isEqualTo: empresaId)
      .get();

  // 🔴 ¡ESTA LÍNEA ES LA QUE TE FALTA!
  return query.docs.map((doc) {
    final data = doc.data();
    data['id'] = doc.id; // Asignamos el ID del documento al mapa
    return data;
  }).toList();
}

  Future<void> borrarEmpleado(String usuarioId) async {
    // Debes usar _empresaId para llegar a la ruta correcta
    await _db
        .collection('empresas')
        .doc(_empresaId) // Asegúrate de que _empresaId esté cargado
        .collection('usuarios')
       .doc(usuarioId)
        .delete();
  }
}