import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firebase_service.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'dart:math';
import 'auth_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _categorias = [];
  bool _loading = true;
  String _search = '';
  String _userName = '';
  String? _filtroCategoria;
  String _filtroEstado = 'todos';
  String _ordenar = 'nombre';
  bool _showFilters = false;
  late AnimationController _ctrl;
  final ImagePicker _picker = ImagePicker();

  String _generateUniqueBarcode() {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final int randomNum = Random().nextInt(900) + 100; // Evita duplicados si se crean muy rápido
    return "SM$timestamp$randomNum"; // Genera algo como: SM1716215340000842
  }

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
    final prefs = await SharedPreferences.getInstance();
    final prods = await StockService.instance.getProductos();
    final cats = await StockService.instance.getCategorias();
    if (mounted) {
      setState(() {
        _products = prods;
        _categorias = cats;
        _userName = prefs.getString('user_name') ?? 'Usuario';
        _loading = false;
        _applyFilter();
      });
      _ctrl.forward(from: 0);
    }
  }

  void _applyFilter() {
    var lista = List<Map<String, dynamic>>.from(_products);

    // Filtro busqueda
    if (_search.isNotEmpty) {
      lista = lista.where((p) =>
          (p['nombre'] ?? '').toLowerCase().contains(_search.toLowerCase()) ||
          (p['codigo_barras'] ?? '').contains(_search)).toList();
    }

    // Filtro categoria
    if (_filtroCategoria != null) {
      lista = lista.where((p) =>
          p['categoria_id'].toString() == _filtroCategoria).toList();
    }

    // Filtro estado
    switch (_filtroEstado) {
      case 'bajo':
        lista = lista.where((p) {
          final s = p['stock_actual'] as int? ?? 0;
          final m = p['stock_minimo'] as int? ?? 5;
          return s <= m && s > 0;
        }).toList();
        break;
      case 'agotado':
        lista = lista
            .where((p) => (p['stock_actual'] as int? ?? 0) == 0)
            .toList();
        break;
      case 'ok':
        lista = lista.where((p) {
          final s = p['stock_actual'] as int? ?? 0;
          final m = p['stock_minimo'] as int? ?? 5;
          return s > m;
        }).toList();
        break;
    }

    // Ordenar
    switch (_ordenar) {
      case 'nombre':
        lista.sort((a, b) =>
            (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
        break;
      case 'stock_asc':
        lista.sort((a, b) =>
            (a['stock_actual'] as int? ?? 0)
                .compareTo(b['stock_actual'] as int? ?? 0));
        break;
      case 'stock_desc':
        lista.sort((a, b) =>
            (b['stock_actual'] as int? ?? 0)
                .compareTo(a['stock_actual'] as int? ?? 0));
        break;
      case 'precio_asc':
        lista.sort((a, b) =>
            (a['precio'] as double? ?? 0)
                .compareTo(b['precio'] as double? ?? 0));
        break;
      case 'precio_desc':
        lista.sort((a, b) =>
            (b['precio'] as double? ?? 0)
                .compareTo(a['precio'] as double? ?? 0));
        break;
    }

    setState(() => _filtered = lista);
  }

  Future<String?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
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
              Text('Foto del producto',
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
                        child: Column(
                          children: [
                            const Icon(Icons.camera_alt_rounded,
                                color: Colors.blue, size: 32),
                            const SizedBox(height: 8),
                            Text('Camara',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue)),
                          ],
                        ),
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
                        child: Column(
                          children: [
                            const Icon(Icons.photo_library_rounded,
                                color: Colors.purple, size: 32),
                            const SizedBox(height: 8),
                            Text('Galeria',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Sin imagen',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return null;
    try {
      final XFile? image = await _picker.pickImage(
          source: source, imageQuality: 70);
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showProductForm({Map<String, dynamic>? producto}) async {
    final isEdit = producto != null;
    final nameCtrl = TextEditingController(
        text: isEdit ? producto['nombre'] : '');
    final priceCtrl = TextEditingController(
        text: isEdit ? '${producto['precio']}' : '');
    final stockCtrl = TextEditingController(
        text: isEdit ? '${producto['stock_actual']}' : '');
    final minCtrl = TextEditingController(
        text: isEdit ? '${producto['stock_minimo']}' : '');
    final fechaCtrl = TextEditingController(
        text: isEdit ? (producto['fecha_vencimiento'] ?? '') : '');
    final codigoCtrl = TextEditingController(
        text: isEdit ? (producto['codigo_barras'] ?? '') : '');
    String? catSeleccionada =
        isEdit ? producto['categoria_id']?.toString() : null;
    String? imagenBase64 =
        isEdit ? producto['imagen'] : null;

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
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? 'Editar producto' : 'Nuevo producto',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    if (isEdit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Editando',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Imagen
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final img = await _pickImage();
                      if (img != null) setS(() => imagenBase64 = img);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: imagenBase64 != null
                            ? Colors.transparent
                            : const Color(0xFF1565C0).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: imagenBase64 != null
                              ? Colors.transparent
                              : const Color(0xFF1565C0).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: imagenBase64 != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.memory(
                                base64Decode(imagenBase64!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: Color(0xFF1565C0),
                                    size: 28),
                                const SizedBox(height: 4),
                                Text('Foto',
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF1565C0),
                                        fontWeight: FontWeight.w500)),
                                Text('opcional',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                ),
                if (imagenBase64 != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: GestureDetector(
                      onTap: () => setS(() => imagenBase64 = null),
                      child: Text('Quitar imagen',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                _inputField(nameCtrl, 'Nombre del producto',
                    Icons.label_outline),
                const SizedBox(height: 10),
                _inputField(codigoCtrl, 'Codigo de barras',
                    Icons.qr_code_rounded),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _inputField(priceCtrl, 'Precio',
                          Icons.attach_money_rounded,
                          type: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _inputField(stockCtrl, 'Stock',
                          Icons.inventory_2_outlined,
                          type: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _inputField(minCtrl, 'Stock minimo',
                          Icons.warning_amber_outlined,
                          type: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _inputField(fechaCtrl, 'Vencimiento',
                          Icons.calendar_today_outlined,
                          hint: 'DD/MM/AAAA')),
                ]),
                const SizedBox(height: 10),

                // Categorias
                if (_categorias.isNotEmpty) ...[
                  Text('Categoria',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _categorias.map((cat) {
                      final sel = catSeleccionada ==
                          cat['id'].toString();
                      return GestureDetector(
                        onTap: () => setS(() => catSeleccionada =
                            sel ? null : cat['id'].toString()),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF1565C0)
                                : const Color(0xFF1565C0)
                                    .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.check_rounded,
                                      size: 13, color: Colors.white),
                                ),
                              Text(cat['nombre'] ?? '',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : const Color(0xFF1565C0))),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty) return;
                      String CodigoFinal = codigoCtrl.text.trim();
                      if (CodigoFinal.isEmpty) {
                        CodigoFinal = _generateUniqueBarcode();
                      }
                      final data = {
                        'nombre': nameCtrl.text,
                        'precio':
                            double.tryParse(priceCtrl.text) ?? 0,
                        'stock_actual':
                            int.tryParse(stockCtrl.text) ?? 0,
                        'stock_minimo':
                            int.tryParse(minCtrl.text) ?? 5,
                        'fecha_vencimiento': fechaCtrl.text,
                        'codigo_barras': CodigoFinal,
                        'categoria_id': catSeleccionada,
                        'imagen': imagenBase64,
                      };
                      if (isEdit) {
                        await StockService.instance
                            .updateProducto({...producto!, ...data});
                      } else {
                        await StockService.instance
                            .insertProducto(data);
                      }
                      if (mounted) Navigator.pop(ctx);
                      _loadData();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                        isEdit ? 'Guardar cambios' : 'Guardar producto',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
      TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Future<void> _editarStock(Map<String, dynamic> producto) async {
    final cantCtrl = TextEditingController();
    String tipo = 'entrada';

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
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Ajustar stock',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Text(producto['nombre'] ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setS(() => tipo = 'entrada'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tipo == 'entrada'
                            ? Colors.green.withOpacity(0.12)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tipo == 'entrada'
                              ? Colors.green
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(children: [
                        Icon(Icons.add_circle_rounded,
                            color: tipo == 'entrada'
                                ? Colors.green
                                : Colors.grey,
                            size: 28),
                        const SizedBox(height: 4),
                        Text('Entrada',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: tipo == 'entrada'
                                    ? Colors.green
                                    : Colors.grey)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setS(() => tipo = 'salida'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tipo == 'salida'
                            ? Colors.red.withOpacity(0.12)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tipo == 'salida'
                              ? Colors.red
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(children: [
                        Icon(Icons.remove_circle_rounded,
                            color: tipo == 'salida'
                                ? Colors.red
                                : Colors.grey,
                            size: 28),
                        const SizedBox(height: 4),
                        Text('Salida',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: tipo == 'salida'
                                    ? Colors.red
                                    : Colors.grey)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text('Stock actual: ${producto['stock_actual']}',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cantCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  prefixIcon: Icon(
                    tipo == 'entrada'
                        ? Icons.add_rounded
                        : Icons.remove_rounded,
                    color: tipo == 'entrada'
                        ? Colors.green
                        : Colors.red,
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    final cant = int.tryParse(cantCtrl.text) ?? 0;
                    if (cant <= 0) return;
                    final stockActual =
                        producto['stock_actual'] as int? ?? 0;
                    final nuevoStock = tipo == 'entrada'
                        ? stockActual + cant
                        : (stockActual - cant).clamp(0, 99999);
                    await StockService.instance.updateProducto(
                        {...producto, 'stock_actual': nuevoStock});
                    await StockService.instance.insertMovimiento({
                      'tipo': tipo.toString(),
                      'cantidad': cant,
                      'motivo': tipo == 'entrada' ? 'Ingreso de stock' : 'Salida de stock',
                      'fecha': DateTime.now().toIso8601String(),
                      'producto_id': producto['id'].toString(),
                      'producto_nombre': '${producto['nombre']}'.trim(),
                      'usuario': _userName,
                    });
                    if (mounted) Navigator.pop(ctx);
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        tipo == 'entrada' ? Colors.green : Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Confirmar ${tipo == 'entrada' ? 'entrada' : 'salida'}',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verLongevidad(Map<String, dynamic> producto) async {
    final consumoCtrl = TextEditingController();
    int dias = 0;
    String resultado = '';
    Color colorResultado = Colors.green;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void calcular(String val) {
            final stock = producto['stock_actual'] as int? ?? 0;
            final consumo = int.tryParse(val) ?? 0;
            if (consumo > 0 && stock > 0) {
              dias = (stock / consumo).floor();
              final fecha =
                  DateTime.now().add(Duration(days: dias));
              resultado =
                  'Dura aprox. $dias dias\nHasta el ${fecha.day}/${fecha.month}/${fecha.year}';
              colorResultado = dias <= 3
                  ? Colors.red
                  : dias <= 7
                      ? Colors.orange
                      : Colors.green;
            } else if (stock == 0) {
              dias = 0;
              resultado = 'Producto agotado';
              colorResultado = Colors.red;
            } else {
              resultado = '';
            }
            setS(() {});
          }

          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20,
                MediaQuery.of(ctx).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.timer_outlined,
                        color: Colors.purple, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calculadora longevidad',
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        Text(producto['nombre'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Stock disponible',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.blue)),
                      Text(
                          '${producto['stock_actual'] ?? 0} unidades',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: consumoCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: GoogleFonts.inter(fontSize: 14),
                  onChanged: calcular,
                  decoration: InputDecoration(
                    labelText: 'Consumo diario estimado',
                    hintText: 'Ej: 10',
                    prefixIcon: const Icon(
                        Icons.trending_down_rounded,
                        color: Colors.purple),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: resultado.isEmpty ? 0 : 72,
                  child: resultado.isEmpty
                      ? const SizedBox()
                      : Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorResultado.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    colorResultado.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            Icon(
                              dias <= 3
                                  ? Icons.warning_rounded
                                  : dias <= 7
                                      ? Icons.info_rounded
                                      : Icons.check_circle_rounded,
                              color: colorResultado, size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(resultado,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: colorResultado,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cerrar',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hayFiltros = _filtroCategoria != null ||
        _filtroEstado != 'todos' ||
        _ordenar != 'nombre';

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventario',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          // Contador de productos
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${_filtered.length}',
                style: GoogleFonts.inter(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          // Boton filtros
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  _showFilters
                      ? Icons.filter_list_off_rounded
                      : Icons.filter_list_rounded,
                ),
                onPressed: () =>
                    setState(() => _showFilters = !_showFilters),
              ),
              if (hayFiltros)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showFilters ? 140 : 60),
          child: Column(
            children: [
              // Barra busqueda
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) {
                    _search = v;
                    _applyFilter();
                  },
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o codigo...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey),
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // Panel de filtros
              if (_showFilters)
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filtro estado
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'Todos',
                              selected: _filtroEstado == 'todos',
                              color: Colors.blue,
                              onTap: () {
                                _filtroEstado = 'todos';
                                _applyFilter();
                              },
                            ),
                            _FilterChip(
                              label: 'OK',
                              selected: _filtroEstado == 'ok',
                              color: Colors.green,
                              onTap: () {
                                _filtroEstado = 'ok';
                                _applyFilter();
                              },
                            ),
                            _FilterChip(
                              label: 'Stock bajo',
                              selected: _filtroEstado == 'bajo',
                              color: Colors.orange,
                              onTap: () {
                                _filtroEstado = 'bajo';
                                _applyFilter();
                              },
                            ),
                            _FilterChip(
                              label: 'Agotado',
                              selected: _filtroEstado == 'agotado',
                              color: Colors.red,
                              onTap: () {
                                _filtroEstado = 'agotado';
                                _applyFilter();
                              },
                            ),
                            if (_categorias.isNotEmpty)
                              ..._categorias.map((cat) => _FilterChip(
                                    label: cat['nombre'] ?? '',
                                    selected: _filtroCategoria ==
                                        cat['id'].toString(),
                                    color: Colors.purple,
                                    onTap: () {
                                      _filtroCategoria =
                                          _filtroCategoria ==
                                                  cat['id'].toString()
                                              ? null
                                              : cat['id'].toString();
                                      _applyFilter();
                                    },
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Ordenar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text('Ordenar: ',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600)),
                            _FilterChip(
                                label: 'A-Z',
                                selected: _ordenar == 'nombre',
                                color: Colors.teal,
                                onTap: () {
                                  _ordenar = 'nombre';
                                  _applyFilter();
                                }),
                            _FilterChip(
                                label: 'Stock ↑',
                                selected: _ordenar == 'stock_asc',
                                color: Colors.teal,
                                onTap: () {
                                  _ordenar = 'stock_asc';
                                  _applyFilter();
                                }),
                            _FilterChip(
                                label: 'Stock ↓',
                                selected: _ordenar == 'stock_desc',
                                color: Colors.teal,
                                onTap: () {
                                  _ordenar = 'stock_desc';
                                  _applyFilter();
                                }),
                            _FilterChip(
                                label: 'Precio ↑',
                                selected: _ordenar == 'precio_asc',
                                color: Colors.teal,
                                onTap: () {
                                  _ordenar = 'precio_asc';
                                  _applyFilter();
                                }),
                            _FilterChip(
                                label: 'Precio ↓',
                                selected: _ordenar == 'precio_desc',
                                color: Colors.teal,
                                onTap: () {
                                  _ordenar = 'precio_desc';
                                  _applyFilter();
                                }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        hayFiltros || _search.isNotEmpty
                            ? 'Sin resultados'
                            : 'No hay productos',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hayFiltros || _search.isNotEmpty
                            ? 'Prueba con otros filtros'
                            : 'Toca + para agregar uno',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey),
                      ),
                      if (hayFiltros) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filtroCategoria = null;
                              _filtroEstado = 'todos';
                              _ordenar = 'nombre';
                            });
                            _applyFilter();
                          },
                          child: const Text('Limpiar filtros'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration:
                          Duration(milliseconds: 200 + (index * 40)),
                      curve: Curves.easeOutCubic,
                      builder: (ctx, val, child) => Opacity(
                        opacity: val,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - val)),
                          child: child,
                        ),
                      ),
                      child: _ProductCard(
                        producto: _filtered[index],
                        isDark: isDark,
                        onEdit: () =>
                            _showProductForm(producto: _filtered[index]),
                        onEditStock: () =>
                            _editarStock(_filtered[index]),
                        onLongevidad: () =>
                            _verLongevidad(_filtered[index]),
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(20)),
                              title: Text('Eliminar producto',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700)),
                              content: Text(
                                  '¿Eliminar "${_filtered[index]['nombre']}"?',
                                  style:
                                      GoogleFonts.inter(fontSize: 14)),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancelar')),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await StockService.instance
                                .deleteProducto(_filtered[index]['id']);
                            _loadData();
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showProductForm(),
              backgroundColor: const Color(0xFF1565C0),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Producto',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color)),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onEditStock;
  final VoidCallback onLongevidad;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.producto,
    required this.isDark,
    required this.onEdit,
    required this.onEditStock,
    required this.onLongevidad,
    required this.onDelete,
  });

  void _verificarPermiso(BuildContext context, VoidCallback accionPermitida) {
    if (RolHelper.isAdmin) {
      accionPermitida();
    } else {
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
  }

  @override
  Widget build(BuildContext context) {
    final stock = producto['stock_actual'] as int? ?? 0;
    final min = producto['stock_minimo'] as int? ?? 5;
    final isZero = stock == 0;
    final isLow = stock <= min && stock > 0;
    final color = isZero
        ? Colors.red
        : isLow
            ? Colors.orange
            : const Color(0xFF1565C0);
    final imagenBase64 = producto['imagen'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
        border: isZero || isLow
            ? Border.all(color: color.withOpacity(0.2))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar / imagen
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: imagenBase64 != null &&
                        imagenBase64.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(
                          base64Decode(imagenBase64),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              (producto['nombre'] ?? 'P')[0]
                                  .toUpperCase(),
                              style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: color),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          (producto['nombre'] ?? 'P')[0]
                              .toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(producto['nombre'] ?? '',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isZero)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('AGOTADO',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('\$${producto['precio']}',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Stock: $stock',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ),
                      ],
                    ),
                    if ((producto['codigo_barras'] ?? '').isNotEmpty)
                      Text(
                        key: ValueKey(producto['codigo_barras']),
                        producto['codigo_barras'],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.grey,
                            letterSpacing: 1),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 20, thickness: 1, indent: 4, endIndent: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF1565C0),
                    onTap: onEdit),
                const SizedBox(height: 4),
                _ActionBtn(
                    icon: Icons.swap_vert_rounded,
                    color: Colors.green,
                    onTap: onEditStock),
                const SizedBox(height: 4),
                _ActionBtn(
                    icon: Icons.timer_outlined,
                    color: Colors.purple,
                    onTap: onLongevidad),
                const SizedBox(height: 4),
                _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    onTap: onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}