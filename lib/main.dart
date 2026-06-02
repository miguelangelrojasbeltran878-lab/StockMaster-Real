import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_service.dart';
import 'register_company_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'categories_screen.dart';
import 'scanner_screen.dart';
import 'reports_screen.dart';
import 'auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const StockMasterApp());
}

class StockMasterApp extends StatefulWidget {
  const StockMasterApp({super.key});

  static _StockMasterAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_StockMasterAppState>();

  @override
  State<StockMasterApp> createState() => _StockMasterAppState();
}

class _StockMasterAppState extends State<StockMasterApp> {
  ThemeMode _themeMode = ThemeMode.light;

  bool get isDark => _themeMode == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool('dark_mode') ?? false;
    setState(() =>
        _themeMode = dark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggleAndSave() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockMaster',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(), // Cambiar por RegisterScreen
        '/register': (context) => const RegisterCompanyScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: brightness,
      ),
      textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: brightness).textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            isDark ? const Color(0xFF12121A) : Colors.white,
        foregroundColor:
            isDark ? Colors.white : const Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF12121A) : const Color(0xFFF5F6FA),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor:
            isDark ? const Color(0xFF1E1E2E) : Colors.white,
        indicatorColor:
            const Color(0xFF1565C0).withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ── SPLASH ─────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
  await Future.delayed(const Duration(milliseconds: 1200));
  final prefs = await SharedPreferences.getInstance();
  final isLogged = prefs.getBool('is_logged') ?? false;
  final empresaId = prefs.getString('empresa_id') ?? '';

    if (isLogged && empresaId.isNotEmpty) {
      // Cargar rol en el helper global
      await RolHelper.load();
      StockService.instance.setEmpresaId(empresaId);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/register');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      size: 52, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text('StockMaster',
                    style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Gestion de inventario',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white60,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(
                      color: Colors.white54, strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── MAIN SCREEN — 5 TABS ───────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    InventoryScreen(),
    CategoriesScreen(),
    ScannerScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded),
            label: 'Categorias',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Escaner',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}