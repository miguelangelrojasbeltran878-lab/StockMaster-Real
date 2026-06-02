import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _register() async {
    // 1. Ocultamos el teclado al presionar el botón
    FocusScope.of(context).unfocus();

    final nombre = _nombreCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    final codigo = _codigoCtrl.text.trim();

    // 2. Validar campos vacíos y formato de correo
    if (nombre.isEmpty || email.isEmpty || pass.isEmpty || codigo.isEmpty) {
      setState(() => _error = 'Todos los campos son obligatorios');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Correo electrónico inválido');
      return;
    }

    // 🔴 3. VALIDACIÓN ESTRICTA DE CONTRASEÑA 🔴
    if (pass.length < 8) {
      setState(() {
        _error = 'La contraseña debe tener mínimo 8 caracteres';
        _passCtrl.clear();
        _confirmCtrl.clear();
      });
      return;
    }
    if (!pass.contains(RegExp(r'[A-Z]'))) {
      setState(() {
        _error = 'La contraseña debe tener al menos una MAYÚSCULA';
        _passCtrl.clear();
        _confirmCtrl.clear();
      });
      return;
    }
    if (!pass.contains(RegExp(r'[0-9]'))) {
      setState(() {
        _error = 'La contraseña debe tener al menos un número';
        _passCtrl.clear();
        _confirmCtrl.clear();
      });
      return;
    }
    if (!pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>\-_]'))) {
      setState(() {
        _error = 'Falta: Agrega un carácter especial (ej: @, !, #, *)';
        _passCtrl.clear();
        _confirmCtrl.clear();
      });
      return;
    }

    // 4. Confirmar que las contraseñas coinciden
    if (pass != confirm) {
      setState(() {
        _error = 'Las contraseñas no coinciden';
        _passCtrl.clear();
        _confirmCtrl.clear();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ok = await StockService.instance.unirseConCodigo(
        codigo: codigo,
        nombre: nombre,
        email: email,
        password: pass,
      );

      if (!ok) {
        setState(() {
          _error = 'Código de invitación inválido. Pídelo a tu administrador.';
          _loading = false;
          _passCtrl.clear();
          _confirmCtrl.clear();
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta creada exitosamente',
                style: GoogleFonts.inter()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // 🔴 5. INTERCEPTAR ERRORES DE FIREBASE PARA MOSTRARLOS EN ESPAÑOL 🔴
      String errorMsg = 'Error al crear cuenta. Intenta de nuevo.';
      String eStr = e.toString().toLowerCase();

      if (eStr.contains('email-already-in-use')) {
        errorMsg = 'Este correo ya está registrado en otra cuenta.';
      } else if (eStr.contains('invalid-email')) {
        errorMsg = 'El formato del correo es inválido.';
      } else if (eStr.contains('network-request-failed')) {
        errorMsg = 'Sin conexión. Revisa tu internet.';
      } else if (eStr.contains('weak-password')) {
        errorMsg = 'La contraseña es muy débil.'; // Por si acaso Firebase se queja de algo más
      }

      setState(() {
        _error = errorMsg;
        _loading = false;
        _passCtrl.clear();
        _confirmCtrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Unirse a empresa',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nuevo empleado',
                      style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Necesitas el código de invitación de tu empresa',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // Codigo de invitacion
                  TextField(
                    controller: _codigoCtrl,
                    enabled: !_loading,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2),
                    decoration: InputDecoration(
                      labelText: 'Código de invitación',
                      hintText: 'Ej: FARM-4821',
                      prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _nombreCtrl,
                    enabled: !_loading,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _emailCtrl,
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passCtrl,
                    enabled: !_loading,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  
                  // 🔴 TEXTO DE AYUDA VISUAL PARA EL USUARIO
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4, bottom: 6),
                    child: Text(
                      'Mínimo 8 caracteres, 1 mayúscula, 1 número y 1 símbolo.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  TextField(
                    controller: _confirmCtrl,
                    enabled: !_loading,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_loading) _register();
                    },
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade400, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.inter(
                                  color: Colors.red.shade700, fontSize: 13)),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _register,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text('Unirme a la empresa',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        if (!_loading) Navigator.pop(context);
                      },
                      child: Text('Ya tengo cuenta — Iniciar sesión',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF1565C0),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}