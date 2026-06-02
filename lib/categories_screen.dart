import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';
import 'auth_provider.dart'; // Importante para acceder a RolHelper.isAdmin

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _proveedores = [];
  List<Map<String, dynamic>> _ordenes = [];
  bool _loading = true;
  late AnimationController _ctrl;

  final List<Map<String, dynamic>> _iconOptions = [
    {'icon': Icons.fastfood_rounded, 'label': 'Alimentos', 'color': Colors.orange},
    {'icon': Icons.local_drink_rounded, 'label': 'Bebidas', 'color': Colors.blue},
    {'icon': Icons.clean_hands_rounded, 'label': 'Limpieza', 'color': Colors.cyan},
    {'icon': Icons.medical_services_rounded, 'label': 'Salud', 'color': Colors.red},
    {'icon': Icons.checkroom_rounded, 'label': 'Ropa', 'color': Colors.purple},
    {'icon': Icons.devices_rounded, 'label': 'Tecnologia', 'color': Colors.indigo},
    {'icon': Icons.grass_rounded, 'label': 'Agricola', 'color': Colors.green},
    {'icon': Icons.category_rounded, 'label': 'General', 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _loadData();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final cats = await StockService.instance.getCategorias();
    final prods = await StockService.instance.getProductos();
    final provs = await StockService.instance.getProveedores();
    final ords = await StockService.instance.getOrdenes();
    if (mounted) {
      setState(() {
        _categorias = cats;
        _productos = prods;
        _proveedores = provs;
        _ordenes = ords;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  int _countProductos(String catId) => _productos
      .where((p) => p['categoria_id'].toString() == catId)
      .length;

  // Helper para advertir a los usuarios sin permisos
  void _mostrarAvisoDenegado() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Acceso denegado: Se requieren permisos de Administrador.',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _addCategoria() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int iconIndex = 7;

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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
              Text('Nueva categoria',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: const Icon(Icons.label_outline, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Descripcion (opcional)',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Icono',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _iconOptions.length,
                  itemBuilder: (ctx, i) {
                    final opt = _iconOptions[i];
                    final sel = iconIndex == i;
                    return GestureDetector(
                      onTap: () => setS(() => iconIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        width: 60,
                        decoration: BoxDecoration(
                          color: sel
                              ? (opt['color'] as Color).withOpacity(0.15)
                              : Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? opt['color'] as Color
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(opt['icon'] as IconData,
                                color: sel
                                    ? opt['color'] as Color
                                    : Colors.grey,
                                size: 22),
                            const SizedBox(height: 3),
                            Text(opt['label'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 8,
                                    color: sel
                                        ? opt['color'] as Color
                                        : Colors.grey),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    await StockService.instance.insertCategoria({
                      'nombre': nameCtrl.text,
                      'descripcion': descCtrl.text,
                      'icono': iconIndex,
                    });
                    if (mounted) Navigator.pop(ctx);
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Guardar categoria',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addProveedor() async {
    final nombreCtrl = TextEditingController();
    final contactoCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
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
              Text('Nuevo proveedor',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _field(nombreCtrl, 'Empresa', Icons.business_rounded),
              const SizedBox(height: 10),
              _field(contactoCtrl, 'Contacto', Icons.person_outline),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(telefonoCtrl, 'Telefono',
                    Icons.phone_outlined,
                    type: TextInputType.phone)),
                const SizedBox(width: 10),
                Expanded(child: _field(emailCtrl, 'Email',
                    Icons.email_outlined,
                    type: TextInputType.emailAddress)),
              ]),
              const SizedBox(height: 10),
              _field(direccionCtrl, 'Direccion',
                  Icons.location_on_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    if (nombreCtrl.text.isEmpty) return;
                    await StockService.instance.insertProveedor({
                      'nombre': nombreCtrl.text,
                      'contacto': contactoCtrl.text,
                      'telefono': telefonoCtrl.text,
                      'email': emailCtrl.text,
                      'direccion': direccionCtrl.text,
                    });
                    if (mounted) Navigator.pop(ctx);
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Guardar proveedor',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addOrden() async {
    if (_proveedores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Primero agrega un proveedor',
            style: GoogleFonts.inter()),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    final productosCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    String? proveedorId;
    String estado = 'pendiente';

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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
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
                Text('Nueva orden de compra',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Proveedor',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _proveedores.map((p) {
                    final sel = proveedorId == p['id'].toString();
                    return GestureDetector(
                      onTap: () => setS(() => proveedorId =
                          sel ? null : p['id'].toString()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF1565C0).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p['nombre'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? Colors.white
                                    : const Color(0xFF1565C0))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _field(productosCtrl, 'Descripcion de productos',
                    Icons.inventory_2_outlined),
                const SizedBox(height: 10),
                _field(totalCtrl, 'Total estimado (\$)',
                    Icons.attach_money_rounded,
                    type: TextInputType.number),
                const SizedBox(height: 12),
                Text('Estado',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: ['pendiente', 'confirmada', 'recibida']
                      .map((e) {
                    final colors = {
                      'pendiente': Colors.orange,
                      'confirmada': Colors.blue,
                      'recibida': Colors.green,
                    };
                    final col = colors[e]!;
                    final sel = estado == e;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => estado = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(
                              right: e != 'recibida' ? 8 : 0),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? col.withOpacity(0.15)
                                : col.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? col : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(children: [
                            Icon(
                              e == 'pendiente'
                                  ? Icons.hourglass_empty_rounded
                                  : e == 'confirmada'
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.done_all_rounded,
                              color: sel ? col : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(height: 2),
                            Text(_cap(e),
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? col : Colors.grey)),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      if (proveedorId == null) return;
                      await StockService.instance.insertOrden({
                        'proveedor_id': proveedorId,
                        'productos': productosCtrl.text,
                        'total': double.tryParse(totalCtrl.text) ?? 0,
                        'estado': estado,
                        'fecha': DateTime.now().toIso8601String(),
                      });
                      if (mounted) Navigator.pop(ctx);
                      _loadData();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Crear orden',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabIndex == 0 ? 'Categorias' : _tabIndex == 1 ? 'Proveedores' : 'Ordenes',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.5),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E2E)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _TabBtn(
                  label: 'Categorias',
                  icon: Icons.category_rounded,
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                )),
                Expanded(child: _TabBtn(
                  label: 'Proveedores',
                  icon: Icons.business_rounded,
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                )),
                Expanded(child: _TabBtn(
                  label: 'Ordenes',
                  icon: Icons.receipt_long_rounded,
                  selected: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                )),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tabIndex == 0
              ? _buildCategorias(isDark)
              : _tabIndex == 1
                  ? _buildProveedores(isDark)
                  : _buildOrdenes(isDark),
      // EL BOTÓN FLOTANTE AHORA EVALÚA SI EL USUARIO ES ADMIN
      floatingActionButton: FloatingActionButton.extended(
              onPressed: _tabIndex == 0
                  ? _addCategoria
                  : _tabIndex == 1
                      ? _addProveedor
                      : _addOrden,
              backgroundColor: const Color(0xFF1565C0),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                _tabIndex == 0
                    ? 'Categoria'
                    : _tabIndex == 1
                        ? 'Proveedor'
                        : 'Orden',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Widget _buildCategorias(bool isDark) {
    if (_categorias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No hay categorias',
                style: GoogleFonts.inter(
                    fontSize: 16, color: Colors.grey,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(RolHelper.isAdmin ? 'Toca + para crear una' : 'No tienes categorías registradas',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _categorias.length,
      itemBuilder: (context, index) {
        final cat = _categorias[index];
        final iconIdx = (cat['icono'] as int? ?? 7)
            .clamp(0, _iconOptions.length - 1);
        final iconData = _iconOptions[iconIdx];
        final count = _countProductos(cat['id'].toString());

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 200 + (index * 60)),
          curve: Curves.easeOutCubic,
          builder: (ctx, val, child) => Opacity(
            opacity: val,
            child: Transform.translate(
                offset: Offset(0, 20 * (1 - val)), child: child),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? []
                  : [BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: (iconData['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData['icon'] as IconData,
                      color: iconData['color'] as Color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat['nombre'] ?? '',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      if ((cat['descripcion'] ?? '').isNotEmpty)
                        Text(cat['descripcion'],
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (iconData['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count producto${count != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: iconData['color'] as Color),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    // VALIDACIÓN DE ROL ANTES DE ELIMINAR
                    if (!RolHelper.isAdmin) {
                      _mostrarAvisoDenegado();
                      return;
                    }
                    if (count > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'No puedes eliminar una categoria con $count productos',
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ));
                      return;
                    }
                    await StockService.instance
                        .deleteCategoria(cat['id']);
                    _loadData();
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProveedores(bool isDark) {
    if (_proveedores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No hay proveedores',
                style: GoogleFonts.inter(
                    fontSize: 16, color: Colors.grey,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(RolHelper.isAdmin ? 'Toca + para agregar uno' : 'No tienes proveedores asignados',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _proveedores.length,
      itemBuilder: (ctx, i) {
        final p = _proveedores[i];
        final ords = _ordenes
            .where((o) =>
                o['proveedor_id'].toString() == p['id'].toString())
            .length;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 200 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (ctx, val, child) => Opacity(
            opacity: val,
            child: Transform.translate(
                offset: Offset(0, 15 * (1 - val)), child: child),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: isDark
                  ? []
                  : [BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (p['nombre'] ?? 'P')[0].toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: const Color(0xFF1565C0)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['nombre'] ?? '',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      if ((p['contacto'] ?? '').isNotEmpty)
                        Text(p['contacto'],
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey)),
                      Row(children: [
                        if ((p['telefono'] ?? '').isNotEmpty) ...[
                          Icon(Icons.phone_outlined,
                              size: 11, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(p['telefono'],
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.grey)),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$ords ordenes',
                              style: GoogleFonts.inter(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1565C0))),
                        ),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 20),
                  onPressed: () async {
                    // VALIDACIÓN DE ROL ANTES DE ELIMINAR PROVEEDOR
                    if (!RolHelper.isAdmin) {
                      _mostrarAvisoDenegado();
                      return;
                    }
                    await StockService.instance.deleteProveedor(p['id']);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdenes(bool isDark) {
    if (_ordenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No hay ordenes',
                style: GoogleFonts.inter(
                    fontSize: 16, color: Colors.grey,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(RolHelper.isAdmin ? 'Toca + para crear una' : 'No se encontraron órdenes de compra',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _ordenes.length,
      itemBuilder: (ctx, i) {
        final o = _ordenes[i];
        final proveedor = _proveedores.firstWhere(
          (p) => p['id'].toString() == o['proveedor_id'].toString(),
          orElse: () => {'nombre': 'Desconocido'},
        );
        final estadoColors = {
          'pendiente': Colors.orange,
          'confirmada': Colors.blue,
          'recibida': Colors.green,
        };
        final color = estadoColors[o['estado']] ?? Colors.grey;
        String fecha = '';
        try {
          final dt = DateTime.parse(o['fecha'] ?? '');
          fecha = '${dt.day}/${dt.month}/${dt.year}';
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: isDark
                ? []
                : [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(proveedor['nombre'] ?? '',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_cap(o['estado'] ?? ''),
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                ],
              ),
              if ((o['productos'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(o['productos'],
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(fecha,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.grey)),
                  ]),
                  if ((o['total'] as double? ?? 0) > 0)
                    Text('\$${o['total']}',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: const Color(0xFF1565C0))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: ['pendiente', 'confirmada', 'recibida']
                    .map((e) {
                  final ec = estadoColors[e]!;
                  final sel = o['estado'] == e;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        // VALIDACIÓN DE ROL ANTES DE CAMBIAR EL ESTADO DE LA ORDEN
                        if (!RolHelper.isAdmin) {
                          _mostrarAvisoDenegado();
                          return;
                        }
                        await StockService.instance
                            .updateOrden({...o, 'estado': e});
                        _loadData();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(
                            right: e != 'recibida' ? 6 : 0),
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? ec.withOpacity(0.15)
                              : ec.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? ec : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text(_cap(e),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: sel ? ec : Colors.grey)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.icon,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1565C0)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }
}