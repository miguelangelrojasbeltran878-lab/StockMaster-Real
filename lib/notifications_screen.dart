import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _alertas = [];
  bool _loading = true;
  bool _notifActivas = true;
  int _stockMinGlobal = 5;
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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final bajos = await StockService.instance.getProductosBajoStock();
    final productos = await StockService.instance.getProductos();

    final List<Map<String, dynamic>> alertas = [];

    // ── Alertas de stock bajo y agotados ──────────────────
    for (final p in bajos) {
      final stock = p['stock_actual'] as int? ?? 0;
      final min = p['stock_minimo'] as int? ?? 5;
      alertas.add({
        'tipo': stock == 0 ? 'agotado' : 'bajo',
        'nombre': p['nombre'],
        'stock': stock,
        'minimo': min,
        'id': p['id'],
      });
    }

    // ── Alertas de vencimiento proximos (7 dias) ──────────
    final vencidos = productos.where((p) {
      final fecha = p['fecha_vencimiento'] ?? '';
      if (fecha.isEmpty) return false;
      try {
        final parts = fecha.split('/');
        if (parts.length != 3) return false;
        final dt = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        return dt.isBefore(DateTime.now().add(const Duration(days: 7)));
      } catch (_) {
        return false;
      }
    }).toList();

    for (final p in vencidos) {
      alertas.add({
        'tipo': 'vencimiento',
        'nombre': p['nombre'],
        'fecha': p['fecha_vencimiento'],
        'id': p['id'],
      });
    }

    // ── Eventos del calendario de HOY y MANANA ────────────
    final hoy = DateTime.now();
    final manana = hoy.add(const Duration(days: 1));
    final eventosGuardados = prefs.getStringList('eventos_manuales') ?? [];

    for (final raw in eventosGuardados) {
      final parts = raw.split('||');
      if (parts.length < 3) continue;
      try {
        final fechaEvento = DateTime.parse(parts[0]);
        final titulo = parts[1];
        final tipo = parts[2];
        final hora = parts.length > 3 ? parts[3] : '';

        final esHoy = fechaEvento.day == hoy.day &&
            fechaEvento.month == hoy.month &&
            fechaEvento.year == hoy.year;
        final esManana = fechaEvento.day == manana.day &&
            fechaEvento.month == manana.month &&
            fechaEvento.year == manana.year;

        if (esHoy || esManana) {
          alertas.add({
            'tipo': 'calendario',
            'subtipo': tipo,
            'nombre': titulo,
            'hora': hora,
            'cuando': esHoy ? 'hoy' : 'manana',
            'fecha_raw': parts[0],
          });
        }
      } catch (_) {}
    }

    // ── Auditorias automaticas de HOY y MANANA ────────────
    final intervaloDias = prefs.getInt('auditoria_intervalo') ?? 7;
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);

    for (int i = 0; i <= 180; i += intervaloDias) {
      final fechaAuditoria = inicio.add(Duration(days: i));
      final esHoy = fechaAuditoria.day == hoy.day &&
          fechaAuditoria.month == hoy.month &&
          fechaAuditoria.year == hoy.year;
      final esManana = fechaAuditoria.day == manana.day &&
          fechaAuditoria.month == manana.month &&
          fechaAuditoria.year == manana.year;

      if (esHoy || esManana) {
        alertas.add({
          'tipo': 'calendario',
          'subtipo': 'auditoria',
          'nombre': 'Auditoria de inventario',
          'hora': '09:00',
          'cuando': esHoy ? 'hoy' : 'manana',
          'auto': true,
        });
        break;
      }
    }

    if (mounted) {
      setState(() {
        _alertas = alertas;
        _notifActivas = prefs.getBool('notif_activas') ?? true;
        _stockMinGlobal = prefs.getInt('stock_min_global') ?? 5;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_activas', _notifActivas);
    await prefs.setInt('stock_min_global', _stockMinGlobal);
  }

  // Agrupa las alertas por categoria
  Map<String, List<Map<String, dynamic>>> _agrupar() {
    final Map<String, List<Map<String, dynamic>>> grupos = {
      'calendario': [],
      'stock': [],
      'vencimiento': [],
    };
    for (final a in _alertas) {
      final tipo = a['tipo'] as String;
      if (tipo == 'calendario') {
        grupos['calendario']!.add(a);
      } else if (tipo == 'vencimiento') {
        grupos['vencimiento']!.add(a);
      } else {
        grupos['stock']!.add(a);
      }
    }
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grupos = _agrupar();

    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          if (_alertas.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_alertas.length}',
                  style: GoogleFonts.inter(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Config card ────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark
                          ? []
                          : [BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.tune_rounded,
                              color: Color(0xFF1565C0), size: 18),
                          const SizedBox(width: 8),
                          Text('Configuracion',
                              style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alertas activas',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text('Recibir avisos de stock',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Switch.adaptive(
                              value: _notifActivas,
                              activeColor: const Color(0xFF1565C0),
                              onChanged: (v) {
                                setState(() => _notifActivas = v);
                                _savePrefs();
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text('Stock minimo global',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                            'Alerta cuando el stock baje de $_stockMinGlobal unidades',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                              ),
                              child: Slider(
                                value: _stockMinGlobal.toDouble(),
                                min: 1,
                                max: 100,
                                divisions: 99,
                                activeColor: const Color(0xFF1565C0),
                                onChanged: (v) {
                                  setState(() => _stockMinGlobal = v.toInt());
                                  _savePrefs();
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 44, height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('$_stockMinGlobal',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1565C0),
                                      fontSize: 13)),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Sin alertas ────────────────────────────
                  if (_alertas.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.check_circle_rounded,
                              size: 52, color: Colors.green.shade300),
                          const SizedBox(height: 12),
                          Text('Sin notificaciones',
                              style: GoogleFonts.inter(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Todo el inventario esta en orden',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.grey)),
                        ]),
                      ),
                    )
                  else ...[

                    // ── Grupo: Calendario ──────────────────
                    if (grupos['calendario']!.isNotEmpty) ...[
                      _GrupoHeader(
                        icon: Icons.calendar_month_rounded,
                        label: 'Calendario',
                        count: grupos['calendario']!.length,
                        color: const Color(0xFF1565C0),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(grupos['calendario']!.length, (i) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 200 + (i * 60)),
                          curve: Curves.easeOutCubic,
                          builder: (ctx, val, child) => Opacity(
                            opacity: val,
                            child: Transform.translate(
                                offset: Offset(0, 15 * (1 - val)),
                                child: child),
                          ),
                          child: _AlertaCard(
                              alerta: grupos['calendario']![i],
                              isDark: isDark),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── Grupo: Stock ───────────────────────
                    if (grupos['stock']!.isNotEmpty) ...[
                      _GrupoHeader(
                        icon: Icons.inventory_2_rounded,
                        label: 'Stock',
                        count: grupos['stock']!.length,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(grupos['stock']!.length, (i) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 200 + (i * 60)),
                          curve: Curves.easeOutCubic,
                          builder: (ctx, val, child) => Opacity(
                            opacity: val,
                            child: Transform.translate(
                                offset: Offset(0, 15 * (1 - val)),
                                child: child),
                          ),
                          child: _AlertaCard(
                              alerta: grupos['stock']![i], isDark: isDark),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── Grupo: Vencimientos ────────────────
                    if (grupos['vencimiento']!.isNotEmpty) ...[
                      _GrupoHeader(
                        icon: Icons.event_busy_rounded,
                        label: 'Vencimientos proximos',
                        count: grupos['vencimiento']!.length,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(grupos['vencimiento']!.length, (i) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 200 + (i * 60)),
                          curve: Curves.easeOutCubic,
                          builder: (ctx, val, child) => Opacity(
                            opacity: val,
                            child: Transform.translate(
                                offset: Offset(0, 15 * (1 - val)),
                                child: child),
                          ),
                          child: _AlertaCard(
                              alerta: grupos['vencimiento']![i],
                              isDark: isDark),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

// ── WIDGETS ────────────────────────────────────────────────

class _GrupoHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _GrupoHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }
}

class _AlertaCard extends StatelessWidget {
  final Map<String, dynamic> alerta;
  final bool isDark;

  const _AlertaCard({required this.alerta, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tipo = alerta['tipo'] as String;

    // ── Tipo calendario ────────────────────────────────────
    if (tipo == 'calendario') {
      final subtipo = alerta['subtipo'] as String? ?? '';
      final cuando = alerta['cuando'] as String? ?? '';
      final hora = alerta['hora'] as String? ?? '';
      final esAuto = alerta['auto'] as bool? ?? false;

      final color = subtipo == 'auditoria'
          ? Colors.green
          : subtipo == 'alerta'
              ? Colors.orange
              : subtipo == 'reunion'
                  ? Colors.blue
                  : Colors.purple;

      final icon = subtipo == 'auditoria'
          ? Icons.assignment_turned_in_rounded
          : subtipo == 'alerta'
              ? Icons.warning_amber_rounded
              : subtipo == 'reunion'
                  ? Icons.groups_rounded
                  : Icons.event_rounded;

      final cuandoLabel = cuando == 'hoy' ? 'HOY' : 'MANANA';
      final cuandoColor = cuando == 'hoy' ? Colors.red : Colors.orange;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alerta['nombre'] ?? '',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  if (hora.isNotEmpty) ...[
                    Icon(Icons.access_time_rounded,
                        size: 11, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(hora, style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 8),
                  ],
                  if (esAuto)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Auto', style: GoogleFonts.inter(
                          fontSize: 9, color: Colors.grey)),
                    ),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: cuandoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(cuandoLabel, style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: cuandoColor)),
          ),
        ]),
      );
    }

    // ── Tipo stock / vencimiento ───────────────────────────
    final color = tipo == 'agotado'
        ? Colors.red
        : tipo == 'vencimiento'
            ? Colors.purple
            : Colors.orange;
    final icon = tipo == 'agotado'
        ? Icons.remove_circle_rounded
        : tipo == 'vencimiento'
            ? Icons.calendar_today_rounded
            : Icons.warning_amber_rounded;
    final titulo = tipo == 'agotado'
        ? 'Agotado'
        : tipo == 'vencimiento'
            ? 'Vence pronto'
            : 'Stock bajo';
    final subtitulo = tipo == 'vencimiento'
        ? 'Vence: ${alerta['fecha']}'
        : 'Stock: ${alerta['stock']} | Minimo: ${alerta['minimo']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alerta['nombre'] ?? '',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitulo, style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(titulo, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}