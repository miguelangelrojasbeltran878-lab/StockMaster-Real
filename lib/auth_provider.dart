import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends InheritedWidget {
  final String rol;
  final String userName;
  final String empresaId;

  const AuthProvider({
    super.key,
    required this.rol,
    required this.userName,
    required this.empresaId,
    required super.child,
  });

  static AuthProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthProvider>();

  bool get isAdmin => rol.toLowerCase() == 'administrador' || rol.toLowerCase() == 'admin';
  
  bool get isEmpleado => rol.toLowerCase() == 'empleado';

  @override
  bool updateShouldNotify(AuthProvider oldWidget) =>
      rol != oldWidget.rol || userName != oldWidget.userName;
}

// Helper global para leer el rol sin context
class RolHelper {
  static String _rol = 'empleado';
  static String _userName = '';
  static String _empresaId = '';

  static String get rol => _rol;
  static String get userName => _userName;
  static String get empresaId => _empresaId;
  
  // 🔴 MODIFICACIÓN: Mismo criterio aquí
  static bool get isAdmin => _rol.toLowerCase() == 'administrador' || _rol.toLowerCase() == 'admin';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _rol = prefs.getString('user_rol') ?? 'empleado';
    _userName = prefs.getString('user_name') ?? '';
    _empresaId = prefs.getString('empresa_id') ?? '';
  }

  static void set({
    required String rol,
    required String userName,
    required String empresaId,
  }) {
    _rol = rol;
    _userName = userName;
    _empresaId = empresaId;
  }
}