import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_service.dart';
import 'auth_provider.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    setState(() => _loading = true);
    final users = await StockService.instance.getUsuarios();
    if (mounted) setState(() {
      _usuarios = users;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Equipo',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info codigo invitacion
                FutureBuilder<String>(
                  future: _getCodigoEmpresa(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const SizedBox();
                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        const Icon(Icons.vpn_key_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Codigo de invitacion',
                                style: GoogleFonts.inter(
                                    color: Colors.white70, fontSize: 11)),
                            Text(snap.data!,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2)),
                          ],
                        )),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Codigo copiado',
                                    style: GoogleFonts.inter()),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                        ),
                      ]),
                    );
                  },
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _usuarios.length,
                    itemBuilder: (ctx, i) {
                      final u = _usuarios[i];
                      final rol = u['rol'] ?? 'empleado';
                      final activo = u['activo'] as bool? ?? true;
                      final esAdmin = rol == 'administrador';
                      final esMiCuenta =
                          u['email'] == RolHelper.userName;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? []
                              : [BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))],
                          border: !activo
                              ? Border.all(
                                  color: Colors.red.withOpacity(0.2))
                              : null,
                        ),
                        child: Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: esAdmin
                                  ? const Color(0xFF1565C0).withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: Text(
                                (u['nombre'] ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: esAdmin
                                        ? const Color(0xFF1565C0)
                                        : Colors.green),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(u['nombre'] ?? '',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                if (esMiCuenta) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Tu',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ]),
                              Text(u['email'] ?? '',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          )),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: esAdmin
                                      ? const Color(0xFF1565C0).withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  esAdmin ? 'Admin' : 'Empleado',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: esAdmin
                                          ? const Color(0xFF1565C0)
                                          : Colors.green),
                                ),
                              ),
                              if (!esAdmin && !esMiCuenta) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () async {
                                    await StockService.instance
                                        .desactivarUsuario(
                                            u['id'] ?? u['uid'] ?? '');
                                    _loadUsuarios();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: activo
                                          ? Colors.red.withOpacity(0.08)
                                          : Colors.green.withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      activo ? 'Desactivar' : 'Activar',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: activo
                                              ? Colors.red
                                              : Colors.green),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<String> _getCodigoEmpresa() async {
    try {
      final doc = await StockService.instance.getEmpresaInfo();
      return doc['codigo_invitacion'] ?? '----';
    } catch (_) {
      return '----';
    }
  }
}