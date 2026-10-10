import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/security_event_model.dart';
import '../../data/services/face_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dev_settings_provider.dart';

/// Rostro del evento, en el detalle de un acceso reconocido o de una persona
/// desconocida.
///
/// La IA sube la imagen junto a la foto del evento, con el mismo nombre y un
/// sufijo (`_reconocido.jpg`: comparación con la foto registrada;
/// `_desconocido.jpg`: el rostro ampliado). Si no existe (eventos anteriores o
/// rostro demasiado chico), la sección no se muestra.
///
/// En una persona desconocida, si la IA consiguió tres fotos buenas de su cara
/// (`_desconocido_1..3.jpg`), el residente principal puede registrarla como
/// conocida con esas fotos, por el mismo camino que la pantalla Rostros.
class RostroDelEvento extends StatefulWidget {
  final SecurityEventModel evento;
  const RostroDelEvento({super.key, required this.evento});

  static bool aplica(SecurityEventModel ev) =>
      ev.imageCapturePath != null &&
      (ev.eventType == 'FaceRecognized' || ev.eventType == 'UnknownFace');

  @override
  State<RostroDelEvento> createState() => _RostroDelEventoState();
}

class _RostroDelEventoState extends State<RostroDelEvento> {
  String? _imagen;
  List<String> _fotos = const [];
  bool _registrando = false;
  bool _registrado = false;

  bool get _desconocido => widget.evento.eventType == 'UnknownFace';

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  static String? _base(String url) {
    final sin = url.split('?').first;
    if (!sin.toLowerCase().endsWith('.jpg')) return null;
    return sin.substring(0, sin.length - 4);
  }

  static Future<bool> _existe(String url) async {
    try {
      final r = await Dio().head(url,
          options: Options(validateStatus: (_) => true,
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8)));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _buscar() async {
    final base = _base(widget.evento.imageCapturePath!);
    if (base == null) return;
    final imagen = '$base${_desconocido ? '_desconocido' : '_reconocido'}.jpg';
    if (!await _existe(imagen)) return;
    var fotos = <String>[];
    if (_desconocido) {
      final candidatas = [for (var k = 1; k <= 3; k++) '${base}_desconocido_$k.jpg'];
      final hay = await Future.wait(candidatas.map(_existe));
      if (hay.every((x) => x)) fotos = candidatas;
    }
    if (mounted) setState(() { _imagen = imagen; _fotos = fotos; });
  }

  Future<void> _registrar() async {
    final s = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nombre = await _pedirNombre();
    if (nombre == null || nombre.trim().isEmpty || !mounted) return;
    setState(() => _registrando = true);
    try {
      final dir = await getTemporaryDirectory();
      final archivos = <XFile>[];
      for (var k = 0; k < _fotos.length; k++) {
        final ruta = '${dir.path}/rostro_evento_${DateTime.now().millisecondsSinceEpoch}_$k.jpg';
        await Dio().download(_fotos[k], ruta);
        archivos.add(XFile(ruta, name: 'rostro_${k + 1}.jpg'));
      }
      if (!mounted) return;
      await FaceService(context.read<ApiClient>()).addFace(nombre.trim(), archivos);
      if (!mounted) return;
      setState(() { _registrando = false; _registrado = true; });
      messenger.showSnackBar(SnackBar(content: Text(s.rostroRegistrado(nombre.trim()))));
    } catch (e) {
      if (mounted) setState(() => _registrando = false);
      messenger.showSnackBar(SnackBar(content: Text('${s.rostroNoRegistrado}\n$e')));
    }
  }

  Future<String?> _pedirNombre() {
    final s = context.l10n;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.rostroEsConocido,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.rostroAdvertencia,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: s.rostroNombre),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(s.rostroRegistrar, style: GoogleFonts.inter(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagen = _imagen;
    if (imagen == null) return const SizedBox.shrink();
    final s = context.l10n;
    final puedeRegistrar = _desconocido &&
        _fotos.length == 3 &&
        context.read<DevSettingsProvider>().isPrimaryEffective(context.read<AuthProvider>().user);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.rostroTitulo,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                          backgroundColor: Colors.black,
                          iconTheme: const IconThemeData(color: Colors.white)),
                      body: InteractiveViewer(
                          minScale: 1, maxScale: 5, child: Center(child: Image.network(imagen))),
                    ))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(imagen, fit: BoxFit.contain,
                  errorBuilder: (c, e, st) => const SizedBox.shrink()),
            ),
          ),
          const SizedBox(height: 10),
          Text(_desconocido ? s.rostroExplicacionDesconocido : s.rostroExplicacionReconocido,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          if (puedeRegistrar) ...[
            const SizedBox(height: 12),
            if (_registrado)
              Row(children: [
                const Icon(Icons.check_circle, color: AppColors.safeGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(s.rostroYaRegistrado,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.safeGreen))),
              ])
            else
              OutlinedButton.icon(
                onPressed: _registrando ? null : _registrar,
                icon: _registrando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Icon(Icons.person_add_alt_1, color: AppColors.accent, size: 18),
                label: Text(s.rostroEsConocido,
                    style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.accent)),
              ),
          ],
        ]),
      ),
    );
  }
}

/// Textos de esta sección (español e inglés), con el mismo criterio que
/// [AppStrings]: los dos idiomas juntos para que nunca falte una traducción.
extension RostroStrings on AppStrings {
  String get rostroTitulo => en ? 'Face' : 'Rostro';
  String get rostroExplicacionReconocido => en
      ? 'The captured face next to the registered photo. The marked points help you compare; '
          'facial recognition decides using the whole face.'
      : 'El rostro capturado junto a la foto registrada. Los puntos marcados ayudan a comparar; '
          'el reconocimiento facial decide con el rostro completo.';
  String get rostroExplicacionDesconocido => en
      ? 'This face does not match any registered resident.'
      : 'Este rostro no coincide con ningún residente registrado.';
  String get rostroEsConocido => en ? 'This is someone I know' : 'Es alguien conocido';
  String get rostroAdvertencia => en
      ? 'They will be registered with the 3 photos from the camera. Only register someone you trust: '
          'from now on the system will not treat them as unknown. For better recognition you can also '
          'add clear photos from Faces.'
      : 'Se registrará con las 3 fotos de la cámara. Registra solo a alguien de confianza: desde ahora '
          'el sistema no lo tratará como desconocido. Para un mejor reconocimiento también puedes '
          'agregar fotos nítidas desde Rostros.';
  String get rostroNombre => en ? 'Name' : 'Nombre';
  String get rostroRegistrar => en ? 'Register' : 'Registrar';
  String rostroRegistrado(String nombre) => en
      ? '$nombre was registered. The system will recognize them in the next detections.'
      : '$nombre quedó registrado. El sistema lo reconocerá en las próximas detecciones.';
  String get rostroNoRegistrado => en ? 'Could not register the face.' : 'No se pudo registrar el rostro.';
  String get rostroYaRegistrado => en ? 'Registered as a known person.' : 'Registrado como persona conocida.';
}
