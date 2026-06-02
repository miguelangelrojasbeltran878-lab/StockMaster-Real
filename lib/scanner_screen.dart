import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'firebase_service.dart';
import 'dart:convert';
import 'package:barcode_widget/barcode_widget.dart' as bd;

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  MobileScannerController? _cameraCtrl;
  Map<String, dynamic>? _productoEncontrado;
  bool _buscando = false;
  bool _noEncontrado = false;
  bool _camaraActiva = false;
  bool _linterna = false;
  String? _ultimoCodigo;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _codeCtrl.dispose();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  Future<void> _buscarProducto(String codigo) async {
    if (codigo.isEmpty || codigo == _ultimoCodigo) return;
    _ultimoCodigo = codigo;
    setState(() {
      _buscando = true;
      _productoEncontrado = null;
      _noEncontrado = false;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    final productos = await StockService.instance.getProductos();
    final encontrado = productos.where((p) =>
        (p['codigo_barras'] ?? '').toString() == codigo ||
        (p['nombre'] ?? '').toLowerCase() ==
            codigo.toLowerCase()).toList();
    if (mounted) {
      setState(() {
        _buscando = false;
        if (encontrado.isNotEmpty) {
          _productoEncontrado = encontrado.first;
          _noEncontrado = false;
          // Detener camara al encontrar
          if (_camaraActiva) {
            _cameraCtrl?.stop();
            setState(() => _camaraActiva = false);
          }
        } else {
          _noEncontrado = true;
          _productoEncontrado = null;
        }
      });
    }
  }

  void _toggleCamara() {
    if (_camaraActiva) {
      _cameraCtrl?.dispose();
      _cameraCtrl = null;
      setState(() => _camaraActiva = false);
    } else {
      _cameraCtrl = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      setState(() {
        _camaraActiva = true;
        _productoEncontrado = null;
        _noEncontrado = false;
        _ultimoCodigo = null;
      });
    }
  }

  void _toggleLinterna() {
    _cameraCtrl?.toggleTorch();
    setState(() => _linterna = !_linterna);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Escaner',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          if (_camaraActiva)
            IconButton(
              icon: Icon(
                _linterna
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                color: _linterna ? Colors.yellow : null,
              ),
              onPressed: _toggleLinterna,
              tooltip: 'Linterna',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Visor de camara
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                height: _camaraActiva ? 280 : 200,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E2E)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _camaraActiva
                        ? const Color(0xFF1565C0)
                        : const Color(0xFF1565C0).withOpacity(0.2),
                    width: _camaraActiva ? 2 : 1,
                  ),
                ),
                child: _camaraActiva && _cameraCtrl != null
                    ? Stack(
                        children: [
                          MobileScanner(
                            controller: _cameraCtrl!,
                            onDetect: (capture) {
                              final barcodes = capture.barcodes;
                              for (final b in barcodes) {
                                final codigo = b.rawValue ?? '';
                                if (codigo.isNotEmpty) {
                                  _buscarProducto(codigo);
                                }
                              }
                            },
                          ),
                          // Overlay con esquinas
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ScannerOverlayPainter(),
                            ),
                          ),
                          // Linea de escaneo animada
                          Positioned(
                            left: 40, right: 40,
                            child: AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (ctx, _) {
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.1, end: 0.9),
                                  duration: const Duration(seconds: 2),
                                  builder: (ctx, val, _) => Positioned(
                                    top: 280 * val,
                                    child: Container(
                                      height: 2,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            const Color(0xFF1565C0)
                                                .withOpacity(0.8),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Instruccion
                          Positioned(
                            bottom: 12, left: 0, right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Apunta al codigo de barras o QR',
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ScaleTransition(
                        scale: _pulseAnim,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                size: 80,
                                color: const Color(0xFF1565C0)
                                    .withOpacity(0.15)),
                            ..._buildCorners(),
                            Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                Text('Camara inactiva',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  'Toca "Abrir camara" para escanear',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Botones de camara
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleCamara,
                    style: FilledButton.styleFrom(
                      backgroundColor: _camaraActiva
                          ? Colors.red
                          : const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(
                      _camaraActiva
                          ? Icons.stop_rounded
                          : Icons.camera_alt_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _camaraActiva ? 'Detener camara' : 'Abrir camara',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_camaraActiva) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _cameraCtrl?.switchCamera();
                    },
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.flip_camera_ios_rounded,
                          color: Color(0xFF1565C0), size: 20),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Busqueda manual
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E2E)
                    : Colors.white,
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
                  Text('Busqueda manual',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Ingresa el codigo o nombre del producto',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          style: GoogleFonts.inter(fontSize: 14),
                          onSubmitted: _buscarProducto,
                          decoration: InputDecoration(
                            hintText: 'Codigo o nombre...',
                            hintStyle:
                                GoogleFonts.inter(color: Colors.grey),
                            prefixIcon: const Icon(
                                Icons.search_rounded, size: 20),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF12121A)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _buscarProducto(_codeCtrl.text),
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Loading
            if (_buscando)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E2E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text('Buscando producto...',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),

            // Resultado encontrado
            if (_productoEncontrado != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (ctx, val, child) => Opacity(
                  opacity: val,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - val)),
                    child: child,
                  ),
                ),
                child: _ResultCard(
                    producto: _productoEncontrado!, isDark: isDark),
              ),

            // No encontrado
            if (_noEncontrado)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                builder: (ctx, val, child) =>
                    Opacity(opacity: val, child: child),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.search_off_rounded,
                            color: Colors.red, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('No encontrado',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text(
                                'No existe producto con ese codigo o nombre',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 28.0;
    const color = Color(0xFF1565C0);
    const thick = 3.0;
    const r = 6.0;

    Widget corner(AlignmentGeometry align, bool fx, bool fy) {
      return Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Transform.scale(
            scaleX: fx ? -1 : 1,
            scaleY: fy ? -1 : 1,
            child: SizedBox(
              width: size, height: size,
              child: CustomPaint(
                  painter: _CornerPainter(
                      color: color, thickness: thick, radius: r)),
            ),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft, false, false),
      corner(Alignment.topRight, true, false),
      corner(Alignment.bottomLeft, false, true),
      corner(Alignment.bottomRight, true, true),
    ];
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    const cutW = 220.0;
    const cutH = 160.0;
    final cutLeft = (size.width - cutW) / 2;
    final cutTop = (size.height - cutH) / 2;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cutLeft, cutTop, cutW, cutH),
          const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Borde del area de escaneo
    final borderPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cutLeft, cutTop, cutW, cutH),
            const Radius.circular(12)),
        borderPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double radius;

  _CornerPainter(
      {required this.color,
      required this.thickness,
      required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0),
          radius: Radius.circular(radius))
      ..lineTo(size.width * 0.6, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final bool isDark;

  const _ResultCard(
      {required this.producto, required this.isDark});

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
            : Colors.green;
    final imagenBase64 = producto['imagen'] as String?;
    
    final bytes = imagenBase64 != null && imagenBase64.isNotEmpty
        ? (() {
            try {
              return base64Decode(imagenBase64);
            } catch (_) {
              return null;
            }
          })()
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: color.withOpacity(0.08),
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
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imagenBase64 != null &&
                          imagenBase64.isNotEmpty
                      ? Image.memory(
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(producto['nombre'] ?? '',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text('Producto encontrado',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoChip(
                  label: 'Precio',
                  value: '\$${producto['precio']}',
                  color: Colors.blue),
              const SizedBox(width: 8),
              _InfoChip(
                  label: 'Stock',
                  value: '$stock uds',
                  color: color),
              const SizedBox(width: 8),
              _InfoChip(
                  label: 'Minimo',
                  value: '$min uds',
                  color: Colors.grey),
            ],
          ),
          if (isZero || isLow) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isZero
                        ? 'Este producto esta agotado'
                        : 'Stock por debajo del minimo',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          
          // Bloque visual del código de barras incorporado con éxito
          if ((producto['codigo_barras'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  bd.BarcodeWidget(
                    barcode: bd.Barcode.code128(),
                    data: producto['codigo_barras'],
                    width: double.infinity,
                    height: 70,
                    color: Colors.black,
                    drawText: false,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    producto['codigo_barras'],
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey,
                        letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.grey)),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}