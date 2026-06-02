import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();

    // 🟢 LÓGICA CORRECTA: En el Login NO se valida si tiene mayúsculas o símbolos.
    // Solo validamos que el usuario no haya dejado los campos en blanco.
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Mandamos la clave tal cual a Firebase. Si es correcta, entra.
      final userData = await StockService.instance.login(email, pass);

      if (userData != null) {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('is_logged', true);
        await prefs.setString('empresa_id', userData['empresaId'] ?? '');
        await prefs.setString('user_name', userData['nombre'] ?? '');
        await prefs.setString('user_email', email);
        await prefs.setString('user_rol', userData['rol'] ?? 'empleado');
        
        RolHelper.set(
          rol: userData['rol'] ?? 'empleado', 
          userName: userData['nombre'] ?? '', 
          empresaId: userData['empresaId'] ?? ''
        );

        StockService.instance.setEmpresaId(userData['empresaId'] ?? '');
        
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _error = 'Correo o contraseña incorrectos';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al iniciar sesión. Verifica tus datos.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      size: 44, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text('StockMaster',
                    style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Gestión de inventario profesional',
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 32),

                Container(
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
                      Text('Iniciar sesión',
                          style: GoogleFonts.inter(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Bienvenido de nuevo',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 24),

                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !_loading,
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
                      const SizedBox(height: 14),

                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        enabled: !_loading,
                        onSubmitted: (_) {
                          if (!_loading) _login();
                        },
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

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade400, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: GoogleFonts.inter(
                                      color: Colors.red.shade700,
                                      fontSize: 13)),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
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
                              : Text('Iniciar sesión',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: GestureDetector(
                          onTap: () {
                            if (!_loading) {
                              Navigator.pushReplacementNamed(context, '/register');
                            }
                          },
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(fontSize: 13),
                              children: [
                                TextSpan(
                                    text: '¿No tienes cuenta? ',
                                    style: TextStyle(color: Colors.grey.shade600)),
                                const TextSpan(
                                    text: 'Crear empresa',
                                    style: TextStyle(
                                        color: Color(0xFF1565C0),
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}