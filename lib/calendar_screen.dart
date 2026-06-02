import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _notifPlugin =
    FlutterLocalNotificationsPlugin();

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _eventos = {};
  int _intervaloDias = 7;
  bool _loading = true;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _initNotifications();
    _loadData();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifPlugin.initialize(settings: const InitializationSettings(android: android));
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const android = AndroidNotificationDetails(
      'calendar_channel',
      'Calendario StockMaster',
      channelDescription: 'Recordatorios de auditorias y eventos',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _notifPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: android),
      payload: payload,
    );
  }

  DateTime _normalizar(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _intervaloDias = prefs.getInt('auditoria_intervalo') ?? 7;

    final Map<DateTime, List<Map<String, dynamic>>> eventos = {};
    final inicio = DateTime.now();
    final hoy = _normalizar(inicio);

    // Generar auditorias automaticas
    for (int i = 0; i <= 180; i += _intervaloDias) {
      final fecha = _normalizar(inicio.add(Duration(days: i)));
      eventos[fecha] = [
        {
          'titulo': 'Auditoria de inventario',
          'tipo': 'auditoria',
          'hora': '09:00',
          'auto': true,
        }
      ];
    }

    // Cargar eventos manuales guardados
    final manualRaw = prefs.getStringList('eventos_manuales') ?? [];
    for (final raw in manualRaw) {
      final parts = raw.split('||');
      if (parts.length >= 3) {
        try {
          final fecha = _normalizar(DateTime.parse(parts[0]));
          eventos[fecha] ??= [];
          eventos[fecha]!.add({
            'titulo': parts[1],
            'tipo': parts[2],
            'hora': parts.length > 3 ? parts[3] : '',
            'auto': false,
          });
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _eventos = eventos;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  List<Map<String, dynamic>> _getEventos(DateTime day) =>
      _eventos[_normalizar(day)] ?? [];

  Future<void> _agregarEvento() async {
    final tituloCtrl = TextEditingController();
    final horaCtrl = TextEditingController(text: '09:00');
    String tipo = 'reunion';
    DateTime fechaEvento = _selectedDay ?? DateTime.now();
    bool notificar = true;

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
                Text('Nuevo evento',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Fecha: ${fechaEvento.day}/${fechaEvento.month}/${fechaEvento.year}',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tituloCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Titulo del evento',
                    prefixIcon: const Icon(Icons.event_rounded, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: horaCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Hora (HH:MM)',
                    prefixIcon:
                        const Icon(Icons.access_time_rounded, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Tipo de evento',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TipoBtn(
                      label: 'Reunion',
                      icon: Icons.groups_rounded,
                      color: Colors.blue,
                      selected: tipo == 'reunion',
                      onTap: () => setS(() => tipo = 'reunion'),
                    ),
                    const SizedBox(width: 8),
                    _TipoBtn(
                      label: 'Auditoria',
                      icon: Icons.assignment_rounded,
                      color: Colors.green,
                      selected: tipo == 'auditoria',
                      onTap: () => setS(() => tipo = 'auditoria'),
                    ),
                    const SizedBox(width: 8),
                    _TipoBtn(
                      label: 'Alerta',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                      selected: tipo == 'alerta',
                      onTap: () => setS(() => tipo = 'alerta'),
                    ),
                    const SizedBox(width: 8),
                    _TipoBtn(
                      label: 'Otro',
                      icon: Icons.bookmark_rounded,
                      color: Colors.purple,
                      selected: tipo == 'otro',
                      onTap: () => setS(() => tipo = 'otro'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Toggle notificacion
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: notificar
                        ? Colors.blue.withOpacity(0.06)
                        : Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_rounded,
                              size: 18,
                              color: notificar
                                  ? Colors.blue
                                  : Colors.grey),
                          const SizedBox(width: 8),
                          Text('Notificarme el dia del evento',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: notificar
                                      ? Colors.blue
                                      : Colors.grey)),
                        ],
                      ),
                      Switch.adaptive(
                        value: notificar,
                        activeColor: Colors.blue,
                        onChanged: (v) => setS(() => notificar = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      if (tituloCtrl.text.isEmpty) return;
                      final prefs =
                          await SharedPreferences.getInstance();
                      final lista = prefs
                              .getStringList('eventos_manuales') ??
                          [];
                      lista.add(
                          '${fechaEvento.toIso8601String()}||${tituloCtrl.text}||$tipo||${horaCtrl.text}');
                      await prefs.setStringList(
                          'eventos_manuales', lista);

                      if (mounted) Navigator.pop(ctx);
                      _loadData();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Guardar evento',
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

  Future<void> _eliminarEvento(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('eventos_manuales') ?? [];
    if (index < lista.length) {
      lista.removeAt(index);
      await prefs.setStringList('eventos_manuales', lista);
      _loadData();
    }
  }

  Future<void> _configurarIntervalo() async {
    int temp = _intervaloDias;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Intervalo de auditorias',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cada cuantos dias realizar auditoria',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CounterBtn(
                    icon: Icons.remove_rounded,
                    color: Colors.red,
                    onTap: () => setS(() => temp = (temp - 1).clamp(1, 90)),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text('$temp',
                          style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1565C0))),
                    ),
                  ),
                  _CounterBtn(
                    icon: Icons.add_rounded,
                    color: Colors.green,
                    onTap: () => setS(() => temp = (temp + 1).clamp(1, 90)),
                  ),
                ],
              ),
              Text('dias',
                  style:
                      GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 3, 7, 14, 30].map((d) {
                  return GestureDetector(
                    onTap: () => setS(() => temp = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: temp == d
                            ? const Color(0xFF1565C0)
                            : const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$d dias',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: temp == d
                                  ? Colors.white
                                  : const Color(0xFF1565C0))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('auditoria_intervalo', temp);
                Navigator.pop(ctx);
                _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Auditorias programadas cada $temp dias',
                          style: GoogleFonts.inter()),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventosHoy = _getEventos(_selectedDay ?? DateTime.now());
    final hoy = _normalizar(DateTime.now());
    final esHoy = _selectedDay != null &&
        _normalizar(_selectedDay!) == hoy;

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendario',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [         
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _configurarIntervalo,
            tooltip: 'Configurar intervalo',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Alerta si hay eventos hoy
                if ((_eventos[hoy] ?? []).isNotEmpty)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    builder: (ctx, val, child) => Opacity(
                      opacity: val,
                      child: Transform.translate(
                        offset: Offset(0, -10 * (1 - val)),
                        child: child,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1565C0),
                            Color(0xFF1976D2)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.today_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tienes ${(_eventos[hoy] ?? []).length} evento(s) hoy',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDay = hoy),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Ver',
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Calendario
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.now()
                        .subtract(const Duration(days: 365)),
                    lastDay: DateTime.now()
                        .add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    eventLoader: _getEventos,
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      selectedDecoration: const BoxDecoration(
                        color: Color(0xFF1565C0),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.bold),
                      markerDecoration: const BoxDecoration(
                        color: Color(0xFF1565C0),
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : Colors.grey.shade600),
                      defaultTextStyle: TextStyle(
                          color:
                              isDark ? Colors.white : Colors.black87),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1565C0)),
                      rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1565C0)),
                    ),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    onPageChanged: (focused) {
                      _focusedDay = focused;
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Header de eventos del dia
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            esHoy
                                ? 'Hoy'
                                : _selectedDay != null
                                    ? '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                                    : 'Selecciona un dia',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Auditoria cada $_intervaloDias dias',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (eventosHoy.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1565C0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${eventosHoy.length} eventos',
                              style: GoogleFonts.inter(
                                  color: const Color(0xFF1565C0),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Lista de eventos
                Expanded(
                  child: eventosHoy.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available_rounded,
                                  size: 48,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Sin eventos este dia',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('Toca + para agregar uno',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade400)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: eventosHoy.length,
                          itemBuilder: (ctx, i) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                  milliseconds: 200 + (i * 60)),
                              curve: Curves.easeOutCubic,
                              builder: (ctx, val, child) => Opacity(
                                opacity: val,
                                child: Transform.translate(
                                  offset: Offset(0, 15 * (1 - val)),
                                  child: child,
                                ),
                              ),
                              child: _EventoCard(
                                evento: eventosHoy[i],
                                isDark: isDark,
                                esHoy: esHoy,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarEvento,
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Evento',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CounterBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _TipoBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TipoBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.15)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? color : Colors.grey, size: 18),
              const SizedBox(height: 3),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: selected ? color : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventoCard extends StatelessWidget {
  final Map<String, dynamic> evento;
  final bool isDark;
  final bool esHoy;

  const _EventoCard({
    required this.evento,
    required this.isDark,
    required this.esHoy,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = evento['tipo'] as String;
    final isAuto = evento['auto'] as bool? ?? false;
    final hora = evento['hora'] as String? ?? '';

    final color = tipo == 'auditoria'
        ? Colors.green
        : tipo == 'alerta'
            ? Colors.orange
            : tipo == 'reunion'
                ? Colors.blue
                : Colors.purple;

    final icon = tipo == 'auditoria'
        ? Icons.assignment_turned_in_rounded
        : tipo == 'alerta'
            ? Icons.warning_amber_rounded
            : tipo == 'reunion'
                ? Icons.groups_rounded
                : Icons.bookmark_rounded;

    final tipoLabel = tipo == 'auditoria'
        ? 'Auditoria'
        : tipo == 'alerta'
            ? 'Alerta'
            : tipo == 'reunion'
                ? 'Reunion'
                : 'Otro';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(esHoy ? 0.4 : 0.15)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: color.withOpacity(esHoy ? 0.1 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evento['titulo'] ?? '',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tipoLabel,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                    if (hora.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.access_time_rounded,
                          size: 11, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(hora,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey)),
                    ],
                    if (isAuto) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Auto',
                            style: GoogleFonts.inter(
                                fontSize: 9, color: Colors.grey)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (esHoy)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Hoy',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
        ],
      ),
    );
  }
}