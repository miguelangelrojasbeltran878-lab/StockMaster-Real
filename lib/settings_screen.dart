import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'firebase_service.dart';
import 'auth_provider.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {

  List<Map<String, dynamic>> _empleados = [];
  bool _cargandoEmpleados = false;
  bool _notifActivas = true;
  bool _alertaVencimiento = true;
  int _stockMinGlobal = 5;
  int _diasAuditoria = 7;
  String _moneda = 'COP';
  String _nombreEmpresa = 'Mi Empresa';
  String _codigoInvitacion = '';
  bool _loading = true;
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  final _empresaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _loadSettings();
    if (RolHelper.isAdmin) {
      _cargarEmpleados();
      _cargarCodigoEmpresa();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _empresaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCodigoEmpresa() async {
    try {
      final info = await StockService.instance.getEmpresaInfo();
      if (mounted) {
        setState(() => _codigoInvitacion = info['codigo_invitacion'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _cargarEmpleados() async {
    setState(() => _cargandoEmpleados = true);
    try {
      final lista = await StockService.instance.getUsuarios();
      if (mounted) {
        setState(() {
          _empleados = lista;
          _cargandoEmpleados = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoEmpleados = false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notifActivas = prefs.getBool('notif_activas') ?? true;
        _alertaVencimiento = prefs.getBool('alerta_vencimiento') ?? true;
        _stockMinGlobal = prefs.getInt('stock_min_global') ?? 5;
        _diasAuditoria = prefs.getInt('auditoria_intervalo') ?? 7;
        _moneda = prefs.getString('moneda') ?? 'COP';
        _nombreEmpresa = prefs.getString('nombre_empresa') ?? 'Mi Empresa';
        _empresaCtrl.text = _nombreEmpresa;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_activas', _notifActivas);
    await prefs.setBool('alerta_vencimiento', _alertaVencimiento);
    await prefs.setInt('stock_min_global', _stockMinGlobal);
    await prefs.setInt('auditoria_intervalo', _diasAuditoria);
    await prefs.setString('moneda', _moneda);
    await prefs.setString('nombre_empresa', _empresaCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Configuracion guardada', style: GoogleFonts.inter()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _eliminarEmpleado(Map<String, dynamic> usuario) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar usuario',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
            'Eliminar a "${usuario['nombre']}" del equipo?\nEsta accion no se puede deshacer.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final idParaBorrar = usuario['id'] ?? usuario['uid'];
  
  // 🔴 DEPURACIÓN: ¿Esto imprime un ID válido o sale null/vacío?
  print("DEBUG: Intentando borrar ID: '$idParaBorrar'"); 

  if (idParaBorrar == null || idParaBorrar.toString().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error: No se encontró el ID del usuario'),
        backgroundColor: Colors.red));
    return;
  }

  await StockService.instance.borrarEmpleado(idParaBorrar);
  await _cargarEmpleados(); // Agregamos await aquí para asegurar la recarga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Usuario eliminado', style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  Future<void> _mostrarGeneradorCodigoBarras() async {
    final codigoCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    String codigoGenerado = '';
    String tipo = 'CODE128';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                const SizedBox(height: 16),
                Text('Generar codigo de barras',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: nombreCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Nombre del producto',
                    prefixIcon: const Icon(Icons.label_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codigoCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Codigo (ej: 7501234567890)',
                    prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setS(() => codigoGenerado = v),
                ),
                const SizedBox(height: 12),
                Text('Tipo de codigo',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['CODE128', 'EAN13', 'EAN8', 'QR'].map((t) {
                      final sel = tipo == t;
                      return GestureDetector(
                        onTap: () => setS(() => tipo = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF1565C0)
                                : const Color(0xFF1565C0).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(t,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : const Color(0xFF1565C0))),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (codigoGenerado.isNotEmpty)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    builder: (ctx, val, child) => Opacity(opacity: val, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12, offset: const Offset(0, 3))],
                      ),
                      child: Column(children: [
                        if (nombreCtrl.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(nombreCtrl.text,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                          ),
                        tipo == 'QR'
                            ? BarcodeWidget(
                                barcode: Barcode.qrCode(),
                                data: codigoGenerado,
                                width: 150, height: 150, color: Colors.black)
                            : BarcodeWidget(
                                barcode: tipo == 'EAN13'
                                    ? Barcode.ean13()
                                    : tipo == 'EAN8'
                                        ? Barcode.ean8()
                                        : Barcode.code128(),
                                data: codigoGenerado,
                                width: double.infinity, height: 80, color: Colors.black),
                        const SizedBox(height: 8),
                        Text(codigoGenerado,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey, letterSpacing: 2)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: codigoGenerado.isEmpty
                          ? null
                          : () async {
                              final productos = await StockService.instance.getProductos();
                              final coincide = productos.where((p) =>
                                  (p['nombre'] ?? '').toLowerCase()
                                      .contains(nombreCtrl.text.toLowerCase())).toList();
                              if (coincide.isNotEmpty) {
                                await StockService.instance.updateProducto({
                                  ...coincide.first,
                                  'codigo_barras': codigoGenerado,
                                });
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        'Codigo asignado a "${coincide.first['nombre']}"',
                                        style: GoogleFonts.inter()),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ));
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('No se encontro el producto',
                                      style: GoogleFonts.inter()),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                ));
                              }
                            },
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: Text('Asignar a producto',
                          style: GoogleFonts.inter(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _limpiarDatos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Limpiar datos',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
            'Esto eliminara TODOS los productos, categorias y movimientos. Esta accion no se puede deshacer.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Limpiar todo'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StockService.instance.limpiarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Datos eliminados', style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = StockMasterApp.of(context);
    final esAdmin = RolHelper.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configuracion',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.5)),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text('Guardar',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Empresa ─────────────────────────
                    _SettingsSection(
                      title: 'Empresa',
                      icon: Icons.business_rounded,
                      isDark: isDark,
                      children: [
                        TextField(
                          controller: _empresaCtrl,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Nombre de la empresa',
                            prefixIcon: const Icon(Icons.business_outlined, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF12121A)
                                : Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Moneda',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['COP', 'USD', 'EUR', 'MXN', 'ARS', 'BRL'].map((m) {
                              final sel = _moneda == m;
                              return GestureDetector(
                                onTap: () => setState(() => _moneda = m),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? const Color(0xFF1565C0)
                                        : const Color(0xFF1565C0).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(m,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: sel ? Colors.white : const Color(0xFF1565C0))),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Equipo (solo admin) ─────────────
                    if (esAdmin) ...[
                      _SettingsSection(
                        title: 'Equipo',
                        icon: Icons.group_rounded,
                        isDark: isDark,
                        children: [
                          // Codigo de invitacion
                          if (_codigoInvitacion.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                const Icon(Icons.vpn_key_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Codigo de invitacion',
                                        style: GoogleFonts.inter(
                                            color: Colors.white70, fontSize: 11)),
                                    Text(_codigoInvitacion,
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2)),
                                  ],
                                )),
                                Text('Comparte este\ncodigo con\ntus empleados',
                                    style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 10),
                                    textAlign: TextAlign.right),
                              ]),
                            ),

                          // Header empleados
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Text('Empleados',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1565C0).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${_empleados.length}',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1565C0))),
                                ),
                              ]),
                              GestureDetector(
                                onTap: _cargarEmpleados,
                                child: const Icon(Icons.refresh_rounded,
                                    color: Color(0xFF1565C0), size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (_cargandoEmpleados)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (_empleados.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text('No hay empleados registrados',
                                    style: GoogleFonts.inter(
                                        fontSize: 13, color: Colors.grey)),
                              ),
                            )
                          else
                            ..._empleados.map((u) {
                              final rol = u['rol'] ?? 'empleado';
                              final esAdminUser = rol == 'administrador';
                              final activo = u['activo'] as bool? ?? true;
                              final esMiCuenta =
                                  u['email'] == RolHelper.userName;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF12121A)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: !activo
                                      ? Border.all(color: Colors.red.withOpacity(0.2))
                                      : null,
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color: esAdminUser
                                          ? const Color(0xFF1565C0).withOpacity(0.12)
                                          : Colors.green.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (u['nombre'] ?? 'U')[0].toUpperCase(),
                                        style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: esAdminUser
                                                ? const Color(0xFF1565C0)
                                                : Colors.green),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                          child: Text(u['nombre'] ?? '',
                                              style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        if (esMiCuenta)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('Tu',
                                                style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.w600)),
                                          ),
                                      ]),
                                      Text(u['email'] ?? '',
                                          style: GoogleFonts.inter(
                                              fontSize: 11, color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  )),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: esAdminUser
                                              ? const Color(0xFF1565C0).withOpacity(0.1)
                                              : Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          esAdminUser ? 'Admin' : 'Empleado',
                                          style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: esAdminUser
                                                  ? const Color(0xFF1565C0)
                                                  : Colors.green),
                                        ),
                                      ),
                                      if (!esAdminUser && !esMiCuenta) ...[
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () => _eliminarEmpleado(u),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text('Eliminar',
                                                style: GoogleFonts.inter(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.red)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ]),
                              );
                            }),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Notificaciones ──────────────────
                    _SettingsSection(
                      title: 'Notificaciones',
                      icon: Icons.notifications_rounded,
                      isDark: isDark,
                      children: [
                        _ToggleRow(
                          label: 'Alertas de stock',
                          subtitle: 'Avisar cuando el stock baje',
                          value: _notifActivas,
                          onChanged: (v) => setState(() => _notifActivas = v),
                        ),
                        const Divider(height: 1),
                        _ToggleRow(
                          label: 'Alertas de vencimiento',
                          subtitle: 'Avisar productos proximos a vencer',
                          value: _alertaVencimiento,
                          onChanged: (v) => setState(() => _alertaVencimiento = v),
                        ),
                        const Divider(height: 16),
                        Text('Stock minimo global: $_stockMinGlobal uds',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _stockMinGlobal.toDouble(),
                            min: 1, max: 100, divisions: 99,
                            activeColor: const Color(0xFF1565C0),
                            onChanged: (v) => setState(() => _stockMinGlobal = v.toInt()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Auditorias ──────────────────────
                    _SettingsSection(
                      title: 'Auditorias',
                      icon: Icons.assignment_rounded,
                      isDark: isDark,
                      children: [
                        Text('Intervalo de auditoria: $_diasAuditoria dias',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                            'Las auditorias se programan automaticamente cada $_diasAuditoria dias en el calendario',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _diasAuditoria.toDouble(),
                            min: 1, max: 30, divisions: 29,
                            activeColor: Colors.green,
                            onChanged: (v) => setState(() => _diasAuditoria = v.toInt()),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [1, 3, 7, 14, 30].map((d) {
                            final sel = _diasAuditoria == d;
                            return GestureDetector(
                              onTap: () => setState(() => _diasAuditoria = d),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel ? Colors.green : Colors.green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$d dias',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: sel ? Colors.white : Colors.green)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Codigos de barras ────────────────
                    _SettingsSection(
                      title: 'Codigos de barras',
                      icon: Icons.qr_code_rounded,
                      isDark: isDark,
                      children: [
                        Text('Genera e imprime codigos de barras para tus productos',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _mostrarGeneradorCodigoBarras,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text('Generar codigo de barras',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFF1565C0)),
                              foregroundColor: const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Apariencia ──────────────────────
                    _SettingsSection(
                      title: 'Apariencia',
                      icon: Icons.palette_rounded,
                      isDark: isDark,
                      children: [
                        _ActionRow(
                          label: isDark ? 'Modo oscuro' : 'Modo claro',
                          subtitle: 'Cambiar tema de la aplicacion',
                          icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          iconColor: isDark ? Colors.indigo : Colors.orange,
                          onTap: () => appState?.toggleAndSave(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Datos ───────────────────────────
                    _SettingsSection(
                      title: 'Datos',
                      icon: Icons.storage_rounded,
                      isDark: isDark,
                      children: [
                        _ActionRow(
                          label: 'Limpiar todos los datos',
                          subtitle: 'Elimina productos, categorias y movimientos',
                          icon: Icons.delete_forever_rounded,
                          iconColor: Colors.red,
                          onTap: _limpiarDatos,
                          destructive: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: Text('StockMaster v1.0 · Flutter 3.27',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── WIDGETS ────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.children,
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
            : [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey)),
            ],
          )),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF1565C0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: destructive ? Colors.red : null)),
              Text(subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: Colors.grey.shade400, size: 20),
        ]),
      ),
    );
  }
}