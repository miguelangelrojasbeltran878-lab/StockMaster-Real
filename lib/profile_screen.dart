import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  String _nombre = '';
  String _email = '';
  String _rol = '';
  String? _fotoBase64;
  bool _loading = true;
  bool _saving = false;
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  final ImagePicker _picker = ImagePicker();

  final _nombreCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nombreCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    final nombre = prefs.getString('user_name') ?? '';
    final rol = prefs.getString('user_rol') ?? 'empleado';
    final foto = prefs.getString('user_foto');

    if (mounted) {
      setState(() {
        _nombre = nombre;
        _email = email;
        _rol = rol;
        _fotoBase64 = foto;
        _nombreCtrl.text = nombre;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  String _hash(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  Future<void> _pickFoto() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Foto de perfil',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pop(ctx, ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(children: [
                        const Icon(Icons.camera_alt_rounded,
                            color: Colors.blue, size: 32),
                        const SizedBox(height: 8),
                        Text('Camara',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pop(ctx, ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(children: [
                        const Icon(Icons.photo_library_rounded,
                            color: Colors.purple, size: 32),
                        const SizedBox(height: 8),
                        Text('Galeria',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.purple)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_fotoBase64 != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.remove('user_foto');
                    if (mounted) setState(() => _fotoBase64 = null);
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  label: Text('Quitar foto',
                      style: GoogleFonts.inter(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (source == null) return;
    try {
      final XFile? image = await _picker.pickImage(
          source: source, imageQuality: 80);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_foto', base64Str);
      if (mounted) setState(() => _fotoBase64 = base64Str);
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      _showSnack('El nombre no puede estar vacio', Colors.red);
      return;
    }
    if (_passCtrl.text.isNotEmpty &&
        _passCtrl.text != _confirmCtrl.text) {
      _showSnack('Las contrasenas no coinciden', Colors.red);
      return;
    }
    if (_passCtrl.text.isNotEmpty && _passCtrl.text.length < 6) {
      _showSnack('La contrasena debe tener minimo 6 caracteres',
          Colors.red);
      return;
    }

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nombreCtrl.text.trim());

      final usuarios = await StockService.instance.getUsuarios();
      final email = prefs.getString('user_email') ?? _email;

      Map<String, dynamic>? usuario;
      for (final u in usuarios) {
        if (u['email'] == email) {
          usuario = u;
          break;
        }
      }

      if (usuario != null) {
        final updates = Map<String, dynamic>.from(usuario);
        updates['nombre'] = _nombreCtrl.text.trim();
        if (_passCtrl.text.isNotEmpty) {
          updates['password'] = _hash(_passCtrl.text);
        }
        await StockService.instance.updateUsuario(updates);
      }

      if (mounted) {
        setState(() {
          _nombre = _nombreCtrl.text.trim();
          _saving = false;
        });
        _passCtrl.clear();
        _confirmCtrl.clear();
        _showSnack('Perfil actualizado correctamente', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack('Error al guardar: $e', Colors.red);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rolColor = _rol == 'administrador'
        ? const Color(0xFF1565C0)
        : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mi perfil',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Guardar',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1565C0))),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── Avatar ──────────────────────────
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickFoto,
                            child: Stack(
                              children: [
                                Container(
                                  width: 100, height: 100,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1565C0)
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF1565C0)
                                          .withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: _fotoBase64 != null
                                      ? ClipOval(
                                          child: Image.memory(
                                            base64Decode(_fotoBase64!),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => Center(
                                              child: Text(
                                                _nombre.isNotEmpty
                                                    ? _nombre[0]
                                                        .toUpperCase()
                                                    : 'U',
                                                style: GoogleFonts.inter(
                                                    fontSize: 36,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: const Color(
                                                        0xFF1565C0)),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            _nombre.isNotEmpty
                                                ? _nombre[0]
                                                    .toUpperCase()
                                                : 'U',
                                            style: GoogleFonts.inter(
                                                fontSize: 36,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: const Color(
                                                    0xFF1565C0)),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1565C0),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF12121A)
                                              : Colors.white,
                                          width: 2),
                                    ),
                                    child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(_nombre,
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: rolColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _rol == 'administrador'
                                  ? 'Administrador'
                                  : 'Empleado',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: rolColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Info cuenta ─────────────────────
                    _SectionCard(
                      title: 'Informacion de cuenta',
                      icon: Icons.person_rounded,
                      isDark: isDark,
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'Correo',
                            value: _email.isNotEmpty
                                ? _email
                                : 'No disponible',
                            icon: Icons.email_outlined,
                          ),
                          const Divider(height: 1),
                          _InfoRow(
                            label: 'Rol',
                            value: _rol == 'administrador'
                                ? 'Administrador'
                                : 'Empleado',
                            icon: Icons.badge_outlined,
                            valueColor: rolColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Editar nombre ───────────────────
                    _SectionCard(
                      title: 'Editar nombre',
                      icon: Icons.edit_rounded,
                      isDark: isDark,
                      child: TextField(
                        controller: _nombreCtrl,
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: const Icon(
                              Icons.person_outline, size: 20),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF12121A)
                              : Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Cambiar contrasena ──────────────
                    _SectionCard(
                      title: 'Cambiar contrasena',
                      icon: Icons.lock_rounded,
                      isDark: isDark,
                      child: Column(
                        children: [
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: GoogleFonts.inter(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Nueva contrasena',
                              prefixIcon: const Icon(
                                  Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(
                                    () => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF12121A)
                                  : Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _confirmCtrl,
                            obscureText: _obscure,
                            style: GoogleFonts.inter(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Confirmar contrasena',
                              prefixIcon: const Icon(
                                  Icons.lock_outline, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF12121A)
                                  : Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.06),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.blue, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Deja en blanco si no quieres cambiar la contrasena',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.blue),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Actividad ───────────────────────
                    _SectionCard(
                      title: 'Tu actividad',
                      icon: Icons.bar_chart_rounded,
                      isDark: isDark,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: StockService.instance.getMovimientos(),
                        builder: (ctx, snap) {
                          final movs = snap.data ?? [];
                          final misMovs = movs
                              .where((m) => m['usuario'] == _nombre)
                              .toList();
                          final entradas = misMovs
                              .where((m) => m['tipo'] == 'entrada')
                              .length;
                          final salidas = misMovs
                              .where((m) => m['tipo'] == 'salida')
                              .length;

                          return Row(
                            children: [
                              Expanded(
                                child: _ActivityStat(
                                  label: 'Movimientos',
                                  value: '${misMovs.length}',
                                  color: const Color(0xFF1565C0),
                                  icon: Icons.swap_vert_rounded,
                                ),
                              ),
                              Expanded(
                                child: _ActivityStat(
                                  label: 'Entradas',
                                  value: '$entradas',
                                  color: Colors.green,
                                  icon: Icons.add_circle_rounded,
                                ),
                              ),
                              Expanded(
                                child: _ActivityStat(
                                  label: 'Salidas',
                                  value: '$salidas',
                                  color: Colors.red,
                                  icon: Icons.remove_circle_rounded,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Boton guardar ───────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.save_rounded,
                                size: 18),
                        label: Text(
                          _saving
                              ? 'Guardando...'
                              : 'Guardar cambios',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── WIDGETS ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ActivityStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}