import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() =>
      _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _empresaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _esNuevaEmpresa = true;
  String? _error;

  Future<void> _registrar() async {
    // 1. Ocultar teclado
    FocusScope.of(context).unfocus();

    final empresa = _empresaCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    final codigo = _codigoCtrl.text.trim();

    // 2. Validación de campos vacíos dependiendo de la pestaña
    if (_esNuevaEmpresa && empresa.isEmpty) {
      setState(() => _error = 'El nombre de la empresa es obligatorio');
      return;
    }
    if (!_esNuevaEmpresa && codigo.isEmpty) {
      setState(() => _error = 'El código de invitación es obligatorio');
      return;
    }
    if (nombre.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Por favor, completa todos los campos');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Ingresa un correo electrónico válido');
      return;
    }

    // 🔴 3. VALIDACIÓN ESTRICTA DE CONTRASEÑA 🔴
    if (pass.length < 8) {
      setState(() {
        _error = 'La contraseña debe tener mínimo 8 caracteres';
        _passCtrl.clear();
      });
      return;
    }
    if (!pass.contains(RegExp(r'[A-Z]'))) {
      setState(() {
        _error = 'La contraseña debe tener al menos una MAYÚSCULA';
        _passCtrl.clear();
      });
      return;
    }
    if (!pass.contains(RegExp(r'[0-9]'))) {
      setState(() {
        _error = 'La contraseña debe tener al menos un número';
        _passCtrl.clear();
      });
      return;
    }
    if (!pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>\-_]'))) {
      setState(() {
        _error = 'Falta: Agrega un carácter especial (ej: @, !, #, *)';
        _passCtrl.clear();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_esNuevaEmpresa) {
        final result = await StockService.instance.registrarEmpresa(
          nombreEmpresa: empresa,
          adminNombre: nombre,
          email: email,
          password: pass,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('empresa_id', result['empresaId']);
        await prefs.setString('user_name', nombre);
        await prefs.setString('user_email', email);
        await prefs.setString('user_rol', 'administrador');
        await prefs.setBool('is_logged', true);
        StockService.instance.setEmpresaId(result['empresaId']);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Empresa creada',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 52),
                  const SizedBox(height: 12),
                  Text('Tu código de invitación:',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(result['codigo'],
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: const Color(0xFF1565C0))),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Comparte este código con tus empleados para que se unan a tu empresa',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0)),
                  child: Text('Entrar a StockMaster',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
      } else {
        // Unirse con codigo
        final ok = await StockService.instance.unirseConCodigo(
          codigo: codigo,
          nombre: nombre,
          email: email,
          password: pass,
        );
        if (!ok) {
          setState(() {
            _error = 'Código de invitación inválido';
            _loading = false;
            _passCtrl.clear();
          });
          return;
        }
        // Login automatico
        final userData = await StockService.instance.login(email, pass);
        if (userData != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('empresa_id', userData['empresaId']);
          await prefs.setString('user_name', userData['nombre'] ?? '');
          await prefs.setString('user_email', email);
          await prefs.setString('user_rol', userData['rol'] ?? 'empleado');
          await prefs.setBool('is_logged', true);
          StockService.instance.setEmpresaId(userData['empresaId']);
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      // 🔴 4. TRADUCCIÓN DE ERRORES DE FIREBASE
      String errorMsg = 'Error al procesar la solicitud. Intenta de nuevo.';
      String eStr = e.toString().toLowerCase();

      if (eStr.contains('email-already-in-use')) {
        errorMsg = 'Este correo ya está registrado en otra cuenta.';
      } else if (eStr.contains('invalid-email')) {
        errorMsg = 'El formato del correo es inválido.';
      } else if (eStr.contains('network-request-failed')) {
        errorMsg = 'Sin conexión. Revisa tu internet.';
      } else {
        // Si es otro error custom de tu backend, lo limpiamos un poco
        errorMsg = e.toString().replaceAll('Exception: ', '');
      }

      setState(() {
        _error = errorMsg;
        _loading = false;
        _passCtrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.inventory_2_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text('StockMaster',
                        style: GoogleFonts.inter(
                            fontSize: 26, fontWeight: FontWeight.w700,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Gestión de inventario profesional',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Tabs nueva empresa / unirse
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E2E)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () {
                      if (!_loading) setState(() => _esNuevaEmpresa = true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _esNuevaEmpresa
                            ? const Color(0xFF1565C0)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Icon(Icons.business_rounded, size: 18,
                            color: _esNuevaEmpresa
                                ? Colors.white : Colors.grey),
                        const SizedBox(height: 3),
                        Text('Nueva empresa',
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: _esNuevaEmpresa
                                    ? Colors.white : Colors.grey)),
                      ]),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      if (!_loading) setState(() => _esNuevaEmpresa = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_esNuevaEmpresa
                            ? const Color(0xFF1565C0)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Icon(Icons.group_add_rounded, size: 18,
                            color: !_esNuevaEmpresa
                                ? Colors.white : Colors.grey),
                        const SizedBox(height: 3),
                        Text('Unirse con código',
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: !_esNuevaEmpresa
                                    ? Colors.white : Colors.grey)),
                      ]),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 24),

              if (_esNuevaEmpresa)
                _inputField(_empresaCtrl, 'Nombre de la empresa',
                    Icons.business_rounded, enabled: !_loading),
              const SizedBox(height: 12),
              
              _inputField(_nombreCtrl, 'Tu nombre',
                  Icons.person_outline_rounded, enabled: !_loading),
              const SizedBox(height: 12),
              
              if (!_esNuevaEmpresa) ...[
                _inputField(_codigoCtrl, 'Código de invitación',
                    Icons.vpn_key_rounded, enabled: !_loading),
                const SizedBox(height: 12),
              ],
              
              _inputField(_emailCtrl, 'Correo electrónico',
                  Icons.email_outlined,
                  type: TextInputType.emailAddress, enabled: !_loading),
              const SizedBox(height: 12),
              
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                enabled: !_loading,
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
                ),
              ),

              // 🔴 TEXTO DE AYUDA VISUAL
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

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.red))),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _registrar,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _esNuevaEmpresa
                              ? 'Crear empresa'
                              : 'Unirme a la empresa',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (!_loading) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
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
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool enabled = true}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      enabled: enabled,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}