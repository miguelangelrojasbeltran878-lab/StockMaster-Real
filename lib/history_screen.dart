import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _filtroTipo = 'todos';
  String _filtroUsuario = 'todos';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  String _search = '';
  List<String> _usuarios = [];
  bool _showFilters = false;
  late AnimationController _ctrl;

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

  // 🔴 ESTA ES LA FUNCIÓN CLAVE QUE EVITA EL CRASH DE TIMESTAMP 🔴
  DateTime? _parseFecha(dynamic fechaRaw) {
    if (fechaRaw == null) return null;
    if (fechaRaw is Timestamp) return fechaRaw.toDate();
    if (fechaRaw is String) return DateTime.tryParse(fechaRaw);
    return null;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final movs = await StockService.instance.getMovimientos();
      final usuarios = movs
          .map((m) => m['usuario']?.toString() ?? 'Desconocido')
          .toSet()
          .toList();

      // Ordenar por fecha (Más recientes primero) de forma segura
      movs.sort((a, b) {
        final dtA = _parseFecha(a['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = _parseFecha(b['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });

      if (mounted) {
        setState(() {
          _movimientos = movs;
          _filtered = List.from(movs);
          _usuarios = usuarios;
          _loading = false;
        });
        _ctrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilters() {
    var temp = _movimientos.toList();

    if (_filtroTipo != 'todos') {
      temp = temp.where((m) => m['tipo'] == _filtroTipo).toList();
    }

    if (_filtroUsuario != 'todos') {
      temp = temp.where((m) => m['usuario'] == _filtroUsuario).toList();
    }

    if (_search.isNotEmpty) {
      temp = temp.where((m) => (m['producto_nombre'] ?? '')
          .toString()
          .toLowerCase()
          .contains(_search.toLowerCase())).toList();
    }

    if (_fechaDesde != null || _fechaHasta != null) {
      temp = temp.where((m) {
        final dt = _parseFecha(m['fecha']);
        if (dt == null) return true;
        if (_fechaDesde != null && dt.isBefore(_fechaDesde!)) return false;
        if (_fechaHasta != null && dt.isAfter(_fechaHasta!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
    }

    setState(() {
      _filtered = temp;
    });
  }

  Future<void> _selectFecha(bool isDesde) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDesde) {
          _fechaDesde = picked;
        } else {
          _fechaHasta = picked;
        }
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int totalEntradas = _filtered
        .where((m) => m['tipo'] == 'entrada')
        .fold(0, (sum, m) => sum + (m['cantidad'] as int? ?? 0));
    int totalSalidas = _filtered
        .where((m) => m['tipo'] == 'salida')
        .fold(0, (sum, m) => sum + (m['cantidad'] as int? ?? 0));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _StatChip(
                          label: 'Entradas',
                          value: '+$totalEntradas',
                          color: Colors.green),
                      const SizedBox(width: 12),
                      _StatChip(
                          label: 'Salidas',
                          value: '-$totalSalidas',
                          color: Colors.red),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) {
                            _search = val;
                            _applyFilters();
                          },
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar producto...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _showFilters ? const Color(0xFF1565C0) : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.tune_rounded, 
                            color: _showFilters ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                          onPressed: () => setState(() => _showFilters = !_showFilters),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showFilters)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tipo de movimiento', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(label: 'Todos', selected: _filtroTipo == 'todos', color: Colors.blue, onTap: () { setState(() => _filtroTipo = 'todos'); _applyFilters(); }),
                              _FilterChip(label: 'Entradas', selected: _filtroTipo == 'entrada', color: Colors.green, onTap: () { setState(() => _filtroTipo = 'entrada'); _applyFilters(); }),
                              _FilterChip(label: 'Salidas', selected: _filtroTipo == 'salida', color: Colors.red, onTap: () { setState(() => _filtroTipo = 'salida'); _applyFilters(); }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Por Usuario', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(label: 'Todos', selected: _filtroUsuario == 'todos', color: Colors.blueGrey, onTap: () { setState(() => _filtroUsuario = 'todos'); _applyFilters(); }),
                              ..._usuarios.map((u) => _FilterChip(label: u, selected: _filtroUsuario == u, color: Colors.blueGrey, onTap: () { setState(() => _filtroUsuario = u); _applyFilters(); })),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Rango de Fechas', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _selectFecha(true),
                                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                                label: Text(_fechaDesde != null ? '${_fechaDesde!.day}/${_fechaDesde!.month}/${_fechaDesde!.year}' : 'Desde', style: GoogleFonts.inter(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _selectFecha(false),
                                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                                label: Text(_fechaHasta != null ? '${_fechaHasta!.day}/${_fechaHasta!.month}/${_fechaHasta!.year}' : 'Hasta', style: GoogleFonts.inter(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                        if (_fechaDesde != null || _fechaHasta != null)
                           Padding(
                             padding: const EdgeInsets.only(top: 8),
                             child: Align(
                               alignment: Alignment.centerRight,
                               child: TextButton(
                                 onPressed: () {
                                   setState(() {
                                     _fechaDesde = null;
                                     _fechaHasta = null;
                                   });
                                   _applyFilters();
                                 },
                                 child: Text('Borrar fechas', style: GoogleFonts.inter(fontSize: 12, color: Colors.red)),
                               ),
                             ),
                           )
                      ],
                    ),
                  ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text('No hay movimientos registrados.',
                              style: GoogleFonts.inter(color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _MovimientoCard(
                              movimiento: _filtered[i], isDark: isDark),
                        ),
                ),
              ],
            ),
    );
  }
}

// ── WIDGETS AUXILIARES ──

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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

  // PROTECCIÓN INTERNA PARA LA TARJETA
  DateTime? _parseFecha(dynamic fechaRaw) {
    if (fechaRaw == null) return null;
    if (fechaRaw is Timestamp) return fechaRaw.toDate();
    if (fechaRaw is String) return DateTime.tryParse(fechaRaw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEntrada = movimiento['tipo'] == 'entrada';
    final color = isEntrada ? Colors.green : Colors.red;
    
    final dt = _parseFecha(movimiento['fecha']);
    final fechaFormato = dt != null 
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : 'Sin fecha';

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
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$fechaFormato • ${movimiento['usuario'] ?? 'Usuario'}', 
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${isEntrada ? '+' : '-'}${movimiento['cantidad']}',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(isEntrada ? 'Entrada' : 'Salida',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ]),
    );
  }
}