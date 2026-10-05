import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/services/captura_camara.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/camera_config_model.dart';
import '../../data/models/zone_model.dart';
import '../../providers/camera_provider.dart';

/// Editor de Zonas de Interés (ROI): el usuario dibuja polígonos (puerta, reja,
/// calle…) sobre un frame real de su cámara. Las coordenadas se guardan
/// NORMALIZADAS (0..1). El motor de evaluación contextual usa estas zonas como contexto
/// para estimar intención con mayor precisión y menos falsos positivos.
class ZoneEditorScreen extends StatefulWidget {
  final String cameraId;
  const ZoneEditorScreen({super.key, required this.cameraId});

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

/// Tipos de zona disponibles: clave técnica → (etiqueta ES, color).
const _zoneTypes = <String, (String, Color)>{
  'door': ('Puerta', Color(0xFF34D399)),
  'gate': ('Reja', Color(0xFFF59E0B)),
  'window': ('Ventana', Color(0xFF60A5FA)),
  'yard': ('Jardín', Color(0xFF2DD4BF)),
  'street': ('Calle', Color(0xFF94A3B8)),
  'custom': ('Otra', Color(0xFFA78BFA)),
};

Color _colorFor(String type) => _zoneTypes[type]?.$2 ?? const Color(0xFFA78BFA);
String _labelFor(String type) => _zoneTypes[type]?.$1 ?? 'Otra';

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  final List<Zone> _zones = [];
  final List<Offset> _current = []; // polígono en curso (normalizado)
  Uint8List? _bg; // captura de fondo (JPEG crudo del video)
  double? _bgAspecto; // ancho / alto de la captura
  DateTime? _bgHora;
  bool _loadingBg = true;
  bool _sinVideo = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // El aviso «ya está transmitiendo» taparía los controles de dibujo.
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    final cam = _camera();
    if (cam != null) {
      _zones.addAll(parseZonesJson(cam.zonesJson));
      if (mounted) setState(() {});
    }
    await _loadBackground(cam);
  }

  CameraConfigModel? _camera() {
    final cams = context.read<CameraProvider>().cameras;
    for (final c in cams) {
      if (c.id == widget.cameraId) return c;
    }
    return null;
  }

  /// Fondo del editor: la última captura guardada de la cámara (abre al
  /// instante) o, si no hay, una captura nueva del video en vivo. La captura
  /// es el video CRUDO que recibe el servidor, con la misma orientación y
  /// encuadre que analiza el motor: las zonas dibujadas encima coinciden con
  /// lo que la IA ve.
  Future<void> _loadBackground(CameraConfigModel? cam) async {
    if (cam == null) {
      if (mounted) setState(() => _loadingBg = false);
      return;
    }
    final guardada = await context.read<CapturaCamara>().guardada(cam.id);
    if (guardada != null) {
      await _usarCaptura(guardada);
      return;
    }
    await _tomarCaptura();
  }

  /// «Actualizar captura»: toma una nueva del video en vivo.
  Future<void> _tomarCaptura() async {
    final cam = _camera();
    if (cam == null) return;
    setState(() {
      _loadingBg = true;
      _sinVideo = false;
    });
    final c = await context.read<CapturaCamara>().tomar(cam);
    if (!mounted) return;
    if (c == null) {
      setState(() {
        _loadingBg = false;
        _sinVideo = true;
      });
      return;
    }
    await _usarCaptura(c);
  }

  Future<void> _usarCaptura(Captura c) async {
    double? aspecto;
    try {
      final img = await decodeImageFromList(c.bytes);
      aspecto = img.width / img.height;
      img.dispose();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _bg = c.bytes;
      _bgAspecto = aspecto;
      _bgHora = c.tomada;
      _loadingBg = false;
      _sinVideo = false;
    });
  }

  String _antiguedad() {
    final h = _bgHora;
    if (h == null) return '';
    final m = DateTime.now().difference(h).inMinutes;
    if (m < 1) return 'Captura de hace un momento';
    if (m < 60) return 'Captura de hace $m min';
    final horas = m ~/ 60;
    return horas < 24
        ? 'Captura de hace $horas h'
        : 'Captura de hace ${horas ~/ 24} d';
  }

  void _onTapDown(TapDownDetails d, Size box) {
    if (box.width <= 0 || box.height <= 0) return;
    final nx = (d.localPosition.dx / box.width).clamp(0.0, 1.0);
    final ny = (d.localPosition.dy / box.height).clamp(0.0, 1.0);
    setState(() => _current.add(Offset(nx, ny)));
  }

  void _undoPoint() {
    if (_current.isNotEmpty) setState(() => _current.removeLast());
  }

  Future<void> _closeZone() async {
    if (_current.length < 3) return;
    final result = await _askTypeAndName();
    if (result == null) return;
    setState(() {
      _zones.add(
        Zone(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: result.$1,
          name: result.$2,
          points: List<Offset>.from(_current),
        ),
      );
      _current.clear();
    });
  }

  Future<(String, String)?> _askTypeAndName() async {
    String type = 'door';
    final nameCtrl = TextEditingController(text: _labelFor(type));
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Nueva zona',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipo',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _zoneTypes.entries.map((e) {
                  final selected = e.key == type;
                  return GestureDetector(
                    onTap: () => setLocal(() {
                      type = e.key;
                      nameCtrl.text = e.value.$1;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? e.value.$2.withAlpha(40)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? e.value.$2 : AppColors.border,
                        ),
                      ),
                      child: Text(
                        e.value.$1,
                        style: GoogleFonts.inter(
                          color: selected
                              ? e.value.$2
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim().isEmpty
                    ? _labelFor(type)
                    : nameCtrl.text.trim();
                Navigator.pop(ctx, (type, name));
              },
              child: Text(
                'Agregar',
                style: GoogleFonts.inter(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await context.read<CameraProvider>().updateZones(
      widget.cameraId,
      _zones,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Zonas guardadas' : 'No se pudieron guardar las zonas',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: ok ? AppColors.accent : AppColors.alertRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Zonas de interés',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(
                    'Guardar',
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      // En vertical: lienzo arriba y controles debajo. En horizontal (el
      // teléfono transmitiendo de lado sigue su posición física) no caben uno
      // encima del otro: lienzo a la izquierda y controles a la derecha.
      body: LayoutBuilder(
        builder: (ctx, c) {
          if (c.maxWidth > c.maxHeight) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _lienzo(c.maxWidth - 340 - 24, c.maxHeight - 24),
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _filaCaptura(),
                      _filaControles(),
                      const Divider(color: AppColors.border, height: 16),
                      _lista(),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: _lienzo(c.maxWidth - 24, c.maxHeight * 0.5),
              ),
              _filaCaptura(),
              _filaControles(),
              const Divider(color: AppColors.border, height: 24),
              _lista(),
            ],
          );
        },
      ),
    );
  }

  /// Lienzo con la proporción de la captura (vertical u horizontal), para
  /// mostrarla completa y sin deformar dentro de [anchoMax] × [altoMax].
  /// Antes era siempre 16:9 con la imagen estirada.
  Widget _lienzo(double anchoMax, double altoMax) {
    final aspecto = _bgAspecto ?? 16 / 9;
    var ancho = anchoMax;
    var alto = ancho / aspecto;
    if (alto > altoMax) {
      alto = altoMax;
      ancho = alto * aspecto;
    }
    final box = Size(ancho, alto);
    return Center(
      child: Container(
        width: ancho,
        height: alto,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: GestureDetector(
          onTapDown: (d) => _onTapDown(d, box),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_bg != null)
                Image.memory(_bg!, fit: BoxFit.fill, gaplessPlayback: true),
              if (_loadingBg)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tomando captura de la cámara…',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_bg == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_outlined,
                          color: AppColors.textMuted,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _sinVideo
                              ? 'Esta cámara no está transmitiendo. Inicia la transmisión y pulsa «Actualizar captura».'
                              : 'Sin captura.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              CustomPaint(painter: _ZonePainter(_zones, _current), size: box),
            ],
          ),
        ),
      ),
    );
  }

  /// Antigüedad de la captura y botón para tomar otra.
  Widget _filaCaptura() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _bg == null ? '' : _antiguedad(),
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _loadingBg ? null : _tomarCaptura,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Actualizar captura'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              disabledForegroundColor: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Instrucción y controles de dibujo.
  Widget _filaControles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _current.isEmpty
                  ? 'Toca para marcar los vértices de una zona.'
                  : '${_current.length} punto(s) — mín. 3 para cerrar.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: _current.isEmpty ? null : _undoPoint,
            icon: const Icon(Icons.undo, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Deshacer punto',
          ),
          TextButton.icon(
            onPressed: _current.length >= 3 ? _closeZone : null,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Cerrar zona'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              disabledForegroundColor: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Lista de zonas dibujadas.
  Widget _lista() {
    return Expanded(
      child: _zones.isEmpty
          ? Center(
              child: Text(
                'Sin zonas. Si no dibujas ninguna, el sistema funciona igual que antes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _zones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final z = _zones[i];
                final color = _colorFor(z.type);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${z.name}  ·  ${_labelFor(z.type)}',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _zones.removeAt(i)),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppColors.alertRed,
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Dibuja las zonas guardadas + el polígono en curso sobre el lienzo.
class _ZonePainter extends CustomPainter {
  final List<Zone> zones;
  final List<Offset> current;
  _ZonePainter(this.zones, this.current);

  Offset _denorm(Offset p, Size s) => Offset(p.dx * s.width, p.dy * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    for (final z in zones) {
      _drawPolygon(canvas, size, z.points, _colorFor(z.type), closed: true);
    }
    if (current.isNotEmpty) {
      _drawPolygon(canvas, size, current, AppColors.accent, closed: false);
    }
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    List<Offset> pts,
    Color color, {
    required bool closed,
  }) {
    if (pts.isEmpty) return;
    final path = Path();
    final first = _denorm(pts.first, size);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p = _denorm(pts[i], size);
      path.lineTo(p.dx, p.dy);
    }
    if (closed) path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withAlpha(46),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    for (final p in pts) {
      final d = _denorm(p, size);
      canvas.drawCircle(d, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePainter old) =>
      old.zones != zones || old.current != current;
}
