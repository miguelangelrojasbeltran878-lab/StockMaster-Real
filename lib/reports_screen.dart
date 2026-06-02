import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'firebase_service.dart';
import 'history_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _productos = [];
  bool _loading = true;
  String _userName = '';
  late AnimationController _ctrl;
  int _reportTab = 0;

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
    final movs = await StockService.instance.getMovimientos();
    final prods = await StockService.instance.getProductos();
    if (mounted) {
      setState(() {
        _movimientos = movs;
        _productos = prods;
        _userName = prefs.getString('user_name') ?? 'Usuario';
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  Future<Uint8List> _generarPDF({bool soloStockBajo = false}) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    final lista = soloStockBajo
        ? _productos.where((p) =>
            (p['stock_actual'] as int? ?? 0) <=
            (p['stock_minimo'] as int? ?? 5)).toList()
        : _productos;
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('StockMaster',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 26,
                            color: PdfColors.white)),
                    pw.Text(
                      soloStockBajo
                          ? 'Reporte de Stock Bajo'
                          : 'Reporte de Inventario',
                      style: pw.TextStyle(
                          font: font, fontSize: 13, color: PdfColors.grey300),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('${now.day}/${now.month}/${now.year}',
                        style: pw.TextStyle(
                            font: font, fontSize: 12, color: PdfColors.white)),
                    pw.Text('Por: $_userName',
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey300)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(children: [
            _pdfStatBox('Total', '${_productos.length}', PdfColors.blue50, font,
                fontBold),
            pw.SizedBox(width: 10),
            _pdfStatBox(
                'Stock bajo',
                '${_productos.where((p) => (p['stock_actual'] as int? ?? 0) <= (p['stock_minimo'] as int? ?? 5)).length}',
                PdfColors.orange50,
                font,
                fontBold),
            pw.SizedBox(width: 10),
            _pdfStatBox(
                'Agotados',
                '${_productos.where((p) => (p['stock_actual'] as int? ?? 0) == 0).length}',
                PdfColors.red50,
                font,
                fontBold),
          ]),
          pw.SizedBox(height: 25),
          pw.Text('Detalles del Inventario',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 16, color: PdfColors.blueGrey900)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _pdfCell('Producto',
                      font: font, fontBold: fontBold, isHeader: true),
                  _pdfCell('Precio',
                      font: font, fontBold: fontBold, isHeader: true),
                  _pdfCell('Stock',
                      font: font, fontBold: fontBold, isHeader: true),
                  _pdfCell('Mínimo',
                      font: font, fontBold: fontBold, isHeader: true),
                  _pdfCell('Estado',
                      font: font, fontBold: fontBold, isHeader: true),
                ],
              ),
              ...lista.map((p) {
                final stock = p['stock_actual'] as int? ?? 0;
                final min = p['stock_minimo'] as int? ?? 5;
                final estado =
                    stock == 0 ? 'Agotado' : stock <= min ? 'Bajo' : 'OK';
                return pw.TableRow(
                  children: [
                    _pdfCell(p['nombre'] ?? ''),
                    _pdfCell('\$${p['precio']}'),
                    _pdfCell('$stock uds'),
                    _pdfCell('$min uds'),
                    _pdfCell(estado,
                        isAlert: stock <= min, isCritical: stock == 0),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Text('Últimos Movimientos de Stock',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 16, color: PdfColors.blueGrey900)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _pdfCell('Fecha',
                      font: font, fontBold: fontBold, isHeader: true),
                  _pdfCell('Producto',
                      font: font, fontBold: fontBold, isHeader: true),
                  _pdfCell('Cant.',
                      font: font, fontBold: fontBold, isHeader: true),
                  _pdfCell('Tipo',
                      font: font, fontBold: fontBold, isHeader: true),
                ],
              ),
              ..._movimientos.take(30).map((m) {
                String fecha = '';
                try {
                  final fechaRaw = m['fecha'];
                  if (fechaRaw is Timestamp) {
                    final dt = fechaRaw.toDate();
                    fecha = '${dt.day}/${dt.month}/${dt.year}';
                  } else if (fechaRaw is String) {
                    final dt = DateTime.parse(fechaRaw);
                    fecha = '${dt.day}/${dt.month}/${dt.year}';
                  }
                } catch (_) {
                  fecha = '-';
                }

                final isEntrada = m['tipo'] == 'entrada';
                return pw.TableRow(
                  children: [
                    _pdfCell(fecha),
                    _pdfCell(m['producto_nombre'] ?? 'Desconocido'),
                    _pdfCell('${m['cantidad']}'),
                    _pdfCell(isEntrada ? 'Entrada' : 'Salida',
                        isAlert: !isEntrada),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfStatBox(
      String t, String v, PdfColor bg, pw.Font f, pw.Font fb) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: bg, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(t,
                style: pw.TextStyle(font: f, fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(v,
                style: pw.TextStyle(
                    font: fb, fontSize: 20, color: PdfColors.blueGrey900)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String txt,
      {pw.Font? font,
      pw.Font? fontBold,
      bool isHeader = false,
      bool isAlert = false,
      bool isCritical = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        txt,
        style: pw.TextStyle(
          font: isHeader ? fontBold : font,
          fontSize: isHeader ? 11 : 10,
          color: isCritical
              ? PdfColors.red700
              : isAlert
                  ? PdfColors.orange700
                  : isHeader
                      ? PdfColors.blueGrey900
                      : PdfColors.grey900,
        ),
      ),
    );
  }

  Future<void> _exportarPDF({bool soloStockBajo = false}) async {
    final bytes = await _generarPDF(soloStockBajo: soloStockBajo);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _exportarCSV() async {
    final buffer = StringBuffer();
    buffer.writeln('Nombre,Precio,Stock Actual,Stock Minimo,Estado');
    for (final p in _productos) {
      final stock = p['stock_actual'] as int? ?? 0;
      final min = p['stock_minimo'] as int? ?? 5;
      final estado = stock == 0 ? 'Agotado' : stock <= min ? 'Bajo' : 'OK';
      buffer.writeln('${p['nombre']},${p['precio']},$stock,$min,$estado');
    }
    final bytes = Uint8List.fromList(buffer.toString().codeUnits);
    await Printing.sharePdf(bytes: bytes, filename: 'reporte_inventario.csv');
  }

  Future<void> _compartirPDF() async {
    final bytes = await _generarPDF();
    await Share.shareXFiles([
      XFile.fromData(bytes,
          name: 'reporte_inventario.pdf', mimeType: 'application/pdf')
    ]);
  }

  String _generarResumenQR() {
    final total = _productos.length;
    final bajo = _productos
        .where((p) =>
            (p['stock_actual'] as int? ?? 0) <=
            (p['stock_minimo'] as int? ?? 5))
        .length;
    final agotado =
        _productos.where((p) => (p['stock_actual'] as int? ?? 0) == 0).length;
    return 'StockMaster Reporte\nEmpresa: StockMaster App\nProductos Totales: $total\nBajo Stock: $bajo\nAgotados: $agotado\nFecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Reportes y Exportación',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.5)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E2E)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _tabBtn('Exportar', 0, isDark),
                        ),
                        Expanded(
                          child: _tabBtn('Historial', 1, isDark),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _reportTab == 0
                      ? _buildExportView(isDark)
                      : const HistoryScreen(),
                ),
              ],
            ),
    );
  }

  Widget _tabBtn(String label, int index, bool isDark) {
    final sel = _reportTab == index;
    return GestureDetector(
      onTap: () => setState(() => _reportTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1565C0) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildExportView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Documentos de Inventario',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _exportCard(
            'Reporte Completo (PDF)',
            'Genera un documento PDF con la lista completa de productos, stock actual y estados.',
            Icons.picture_as_pdf_rounded,
            Colors.red,
            isDark,
            onTap: () => _exportarPDF(soloStockBajo: false),
          ),
          const SizedBox(height: 10),
          _exportCard(
            'Reporte Stock Bajo (PDF)',
            'Documento enfocado únicamente en productos que alcanzaron o están por debajo del mínimo.',
            Icons.warning_amber_rounded,
            Colors.orange,
            isDark,
            onTap: () => _exportarPDF(soloStockBajo: true),
          ),
          const SizedBox(height: 10),
          _exportCard(
            'Exportar datos (CSV)',
            'Archivo compatible con Excel para auditorías o análisis externos de datos.',
            Icons.grid_on_rounded,
            Colors.green,
            isDark,
            onTap: _exportarCSV,
          ),
          const SizedBox(height: 24),
          Text('Resumen en Código QR',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 4))
                      ],
              ),
              child: QrImageView(
                data: _generarResumenQR(),
                version: QrVersions.auto,
                size: 160.0,
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: Color(0xFF1565C0)),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF1A1A2E)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'El QR contiene el resumen del inventario. Para el PDF completo usa "Compartir PDF".',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.blue),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _compartirPDF,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text('Compartir PDF',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _exportCard(String label, String subtitle, IconData icon, Color color,
      bool isDark,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ],
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _MovimientoCard extends StatelessWidget {
  final Map<String, dynamic> movimiento;
  final bool isDark;

  const _MovimientoCard({required this.movimiento, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isEntrada = movimiento['tipo'] == 'entrada';
    final color = isEntrada ? Colors.green : Colors.red;
    String fechaFormato = '';
    try {
      final fechaRaw = movimiento['fecha'];
      if (fechaRaw is Timestamp) {
        final dt = fechaRaw.toDate();
        fechaFormato = '${dt.day}/${dt.month}/${dt.year} '
            '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (fechaRaw is String) {
        final dt = DateTime.parse(fechaRaw);
        fechaFormato = '${dt.day}/${dt.month}/${dt.year} '
            '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        fechaFormato = fechaRaw?.toString() ?? '';
      }
    } catch (_) {
      fechaFormato = movimiento['fecha']?.toString() ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEntrada ? Icons.add_chart_rounded : Icons.unarchive_rounded,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movimiento['producto_nombre'] ?? 'Producto eliminado',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(fechaFormato,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${isEntrada ? '+' : '-'}${movimiento['cantidad']}',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(isEntrada ? 'Entrada' : 'Salida',
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ]),
    );
  }
}

class _QrStatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final bool isDark;

  const _QrStatChip(
      {required this.label,
      required this.sublabel,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(sublabel,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}