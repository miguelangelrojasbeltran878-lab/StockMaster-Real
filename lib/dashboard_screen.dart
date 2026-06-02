import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'firebase_service.dart';
import 'main.dart';
import 'notifications_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'auth_provider.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _total = 0;
  int _bajoStock = 0;
  int _sinStock = 0;
  int _categorias = 0;
  bool _loading = true;
  String _userName = '';
  String _userRol = '';
  String? _fotoBase64;
  List<Map<String, dynamic>> _alertas = [];
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _productos = [];
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
    final productos = await StockService.instance.getProductos();
    final bajos = await StockService.instance.getProductosBajoStock();
    final cats = await StockService.instance.getCategorias();
    final movs = await StockService.instance.getMovimientos();

    if (mounted) {
      setState(() {
        _total = productos.length;
        _bajoStock = bajos.length;
        _sinStock =
            productos.where((p) => (p['stock_actual'] ?? 0) == 0).length;
        _categorias = cats.length;
        _alertas = bajos.take(5).toList();
        _movimientos = movs.take(30).toList();
        _productos = productos;
        _userName = prefs.getString('user_name') ?? 'Usuario';
        _userRol = prefs.getString('user_rol') ?? 'empleado';
        _fotoBase64 = prefs.getString('user_foto');
        _loading = false;
      });

      RolHelper.set(
        rol: _userRol,
        userName: _userName,
        empresaId: prefs.getString('empresa_id') ?? '',
      );

      setState(() {});
      
      _ctrl.forward(from: 0);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _irAPerfil() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => const ProfileScreen(),
        transitionsBuilder: (ctx, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ).then((_) => _loadData()); // recargar al volver
  }

  List<BarChartGroupData> _getMovimientosChartData() {
    final Map<String, Map<String, int>> porDia = {};
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final fecha = now.subtract(Duration(days: i));
      final key = '${fecha.day}/${fecha.month}';
      porDia[key] = {'entradas': 0, 'salidas': 0};
    }

    for (final m in _movimientos) {
      try {
        final dt = DateTime.parse(m['fecha'] ?? '');
        final key = '${dt.day}/${dt.month}';
        if (porDia.containsKey(key)) {
          if (m['tipo'] == 'entrada') {
            porDia[key]!['entradas'] =
                (porDia[key]!['entradas'] ?? 0) + (m['cantidad'] as int? ?? 0);
          } else {
            porDia[key]!['salidas'] =
                (porDia[key]!['salidas'] ?? 0) + (m['cantidad'] as int? ?? 0);
          }
        }
      } catch (_) {}
    }

    final entries = porDia.entries.toList();
    return List.generate(entries.length, (i) {
      final data = entries[i].value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (data['entradas'] ?? 0).toDouble(),
            color: Colors.green,
            width: 8,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: (data['salidas'] ?? 0).toDouble(),
            color: Colors.red.withOpacity(0.7),
            width: 8,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  List<String> _getDiaLabels() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final fecha = now.subtract(Duration(days: 6 - i));
      return '${fecha.day}/${fecha.month}';
    });
  }

  List<PieChartSectionData> _getPieData() {
    final ok = _total - _bajoStock;
    final bajo = _bajoStock - _sinStock;
    final agotado = _sinStock;
    final total = _total == 0 ? 1 : _total;

    return [
      if (ok > 0)
        PieChartSectionData(
          value: ok.toDouble(),
          color: Colors.green,
          title: '${((ok / total) * 100).round()}%',
          radius: 50,
          titleStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      if (bajo > 0)
        PieChartSectionData(
          value: bajo.toDouble(),
          color: Colors.orange,
          title: '${((bajo / total) * 100).round()}%',
          radius: 50,
          titleStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      if (agotado > 0)
        PieChartSectionData(
          value: agotado.toDouble(),
          color: Colors.red,
          title: '${((agotado / total) * 100).round()}%',
          radius: 50,
          titleStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      if (_total == 0)
        PieChartSectionData(
          value: 1,
          color: Colors.grey.shade300,
          title: 'Sin datos',
          radius: 50,
          titleStyle:
              GoogleFonts.inter(fontSize: 10, color: Colors.grey),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = StockMasterApp.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('StockMaster',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          // Toggle tema
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: () => appState?.toggleAndSave(),
          ),
          // Notificaciones
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (ctx, anim, _) =>
                        const NotificationsScreen(),
                    transitionsBuilder: (ctx, anim, _, child) =>
                        SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  ),
                ),
              ),
              if (_bajoStock > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$_bajoStock',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          // Calendario
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (ctx, anim, _) => const CalendarScreen(),
                transitionsBuilder: (ctx, anim, _, child) =>
                    SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            ),
          ),
          // Botón de Configuración (Settings) condicional para Administradores
          if (_userRol == 'admin' || RolHelper.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (ctx, anim, _) => const SettingsScreen(),
                  transitionsBuilder: (ctx, anim, _, child) =>
                      SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
              ),
            ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isDark),
                      const SizedBox(height: 20),
                      _buildStatsGrid(isDark),
                      const SizedBox(height: 24),
                      _buildPieChart(isDark),
                      const SizedBox(height: 24),
                      _buildBarChart(isDark),
                      const SizedBox(height: 24),
                      _buildTopProductos(isDark),
                      const SizedBox(height: 24),
                      _buildAlertas(isDark),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, $_userName 👋',
                    style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 4),
                Text('Resumen del inventario',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _headerChip(
                        '$_total productos', Icons.inventory_2_rounded),
                    const SizedBox(width: 8),
                    _headerChip(
                        '$_categorias categorias', Icons.category_rounded),
                    const SizedBox(width: 8),
                    _headerChip(_userRol, Icons.person_rounded),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _irAPerfil,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: _fotoBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        Uri.parse(
                                'data:image/jpeg;base64,$_fotoBase64')
                            .data!
                            .contentAsBytes(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'U',
                            style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        _userName.isNotEmpty
                            ? _userName[0].toUpperCase()
                            : 'U',
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(String label, IconData icon) { // Corrección menor de nombre consistente
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Método alias para mantener compatibilidad exacta con tu llamada interna original
  Widget _headerChip(String label, IconData icon) => _buildHeaderChip(label, icon);

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Total',
          value: '$_total',
          subtitle: 'productos',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF1565C0),
          isDark: isDark,
        ),
        _StatCard(
          title: 'Stock bajo',
          value: '$_bajoStock',
          subtitle: 'productos',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFF57C00),
          isDark: isDark,
        ),
        _StatCard(
          title: 'Agotados',
          value: '$_sinStock',
          subtitle: 'sin stock',
          icon: Icons.remove_circle_rounded,
          color: const Color(0xFFD32F2F),
          isDark: isDark,
        ),
        _StatCard(
          title: 'Categorias',
          value: '$_categorias',
          subtitle: 'registradas',
          icon: Icons.category_rounded,
          color: const Color(0xFF2E7D32),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPieChart(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text('Estado del inventario',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Distribucion por estado de stock',
              style:
                  GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sections: _getPieData(),
                    centerSpaceRadius: 35,
                    sectionsSpace: 3,
                    pieTouchData: PieTouchData(enabled: false),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeyendaItem(
                        color: Colors.green,
                        label: 'Stock OK',
                        value: '${_total - _bajoStock}'),
                    const SizedBox(height: 8),
                    _LeyendaItem(
                        color: Colors.orange,
                        label: 'Stock bajo',
                        value: '${_bajoStock - _sinStock}'),
                    const SizedBox(height: 8),
                    _LeyendaItem(
                        color: Colors.red,
                        label: 'Agotados',
                        value: '$_sinStock'),
                    const SizedBox(height: 8),
                    _LeyendaItem(
                        color: const Color(0xFF1565C0),
                        label: 'Total',
                        value: '$_total'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(bool isDark) {
    final labels = _getDiaLabels();
    final barData = _getMovimientosChartData();
    final hasData = _movimientos.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movimientos (7 dias)',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('Entradas y salidas de stock',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
              Row(
                children: [
                  _LeyendaDot(
                      color: Colors.green, label: 'Entrada'),
                  const SizedBox(width: 10),
                  _LeyendaDot(
                      color: Colors.red.withOpacity(0.7),
                      label: 'Salida'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('Sin movimientos registrados',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
          else
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  barGroups: barData,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt().toString(),
                          style: GoogleFonts.inter(
                              fontSize: 9, color: Colors.grey),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= labels.length)
                            return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[idx],
                                style: GoogleFonts.inter(
                                    fontSize: 8, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gIdx, rod, rIdx) =>
                          BarTooltipItem(
                        '${rod.toY.toInt()}',
                        GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopProductos(bool isDark) {
    if (_productos.isEmpty) return const SizedBox();

    final sorted = List<Map<String, dynamic>>.from(_productos)
      ..sort((a, b) => (b['stock_actual'] as int? ?? 0)
          .compareTo(a['stock_actual'] as int? ?? 0));
    final top5 = sorted.take(5).toList();
    final maxStock =
        top5.isEmpty ? 1 : (top5.first['stock_actual'] as int? ?? 1);

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text('Top productos por stock',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Los 5 con mayor cantidad disponible',
              style:
                  GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          ...top5.asMap().entries.map((e) {
            final idx = e.key;
            final p = e.value;
            final stock = p['stock_actual'] as int? ?? 0;
            final pct = maxStock > 0 ? stock / maxStock : 0.0;
            final colorList = [
              const Color(0xFF1565C0),
              Colors.green,
              Colors.orange,
              Colors.purple,
              Colors.teal,
            ];
            final color = colorList[idx % colorList.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(p['nombre'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('$stock uds',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration:
                        Duration(milliseconds: 600 + (idx * 100)),
                    curve: Curves.easeOutCubic,
                    builder: (ctx, val, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: val,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlertas(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Alertas',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            if (_bajoStock > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$_bajoStock',
                    style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_alertas.isEmpty)
          _emptyAlertas(isDark)
        else
          ...List.generate(_alertas.length, (i) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (i * 80)),
              curve: Curves.easeOutCubic,
              builder: (ctx, val, child) => Opacity(
                opacity: val,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - val)),
                  child: child,
                ),
              ),
              child:
                  _AlertCard(producto: _alertas[i], isDark: isDark),
            );
          }),
      ],
    );
  }

  Widget _emptyAlertas(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Todo en orden',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text('No hay alertas de stock',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── WIDGETS AUXILIARES ──────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween:
                    Tween(begin: 0, end: double.tryParse(value) ?? 0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (ctx, val, _) => Text(
                  val.toInt().toString(),
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5),
                ),
              ),
              Text('$title · $subtitle',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LeyendaItem(
      {required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey)),
        ),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _LeyendaDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LeyendaDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> producto;
  final bool isDark;

  const _AlertCard({required this.producto, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final stock = producto['stock_actual'] as int? ?? 0;
    final min = producto['stock_minimo'] as int? ?? 5;
    final isZero = stock == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isZero
              ? Colors.red.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (isZero ? Colors.red : Colors.orange)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isZero
                  ? Icons.remove_circle_rounded
                  : Icons.warning_amber_rounded,
              color: isZero ? Colors.red : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(producto['nombre'] ?? '',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Stock: $stock | Minimo: $min',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isZero ? Colors.red : Colors.orange)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isZero ? 'Agotado' : 'Bajo',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isZero ? Colors.red : Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}