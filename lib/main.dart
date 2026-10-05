import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'providers/validation_provider.dart';
import 'data/services/validation_platform.dart';
import 'widgets/validation_overlay.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/i18n/app_localizations.dart';
import 'core/network/api_client.dart';
import 'core/storage/auth_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'data/services/camera_service.dart';
import 'data/services/event_service.dart';
import 'data/services/system_service.dart';
import 'providers/auth_provider.dart';
import 'providers/camera_provider.dart';
import 'providers/dev_settings_provider.dart';
import 'providers/event_provider.dart';
import 'providers/server_config_provider.dart';
import 'providers/system_provider.dart';
import 'providers/ui_provider.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'core/utils/deep_links.dart';
import 'router/app_router.dart';
import 'data/services/mobile_camera_publisher.dart';
import 'data/services/emergency_effects.dart';
import 'providers/emergency_provider.dart';
import 'widgets/emergency_overlay.dart';
import 'widgets/consentimiento_gate.dart';
import 'core/orientation/orientacion_app.dart';
import 'core/utils/pantalla_encendida.dart';
import 'data/services/captura_camara.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // libmpv video backend
  // La version de Ajustes sale del paquete instalado, no de un literal.
  await AppConstants.loadAppVersion();
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load persisted settings before building the tree so the ApiClient, language
  // and role preview all start in the right state.
  // Wrapped in try-catch: flutter_secure_storage can throw a Keychain
  // PlatformException on iOS when accessed outside a debugger session.
  final storage = AuthStorage();
  String initialUrl;
  AppLocale initialLocale;
  String? initialPreviewRole;
  try {
    final savedUrl = await storage.getServerUrl();
    initialUrl = savedUrl ?? AppConstants.defaultServerUrl;
    initialLocale = await LocaleProvider.load(storage);
    initialPreviewRole = await DevSettingsProvider.load(storage);
  } catch (_) {
    initialUrl = AppConstants.defaultServerUrl;
    initialLocale = AppLocale.es;
    initialPreviewRole = null;
  }

  runApp(VigiShieldApp(
    initialServerUrl: initialUrl,
    initialLocale: initialLocale,
    initialPreviewRole: initialPreviewRole,
  ));
}

class VigiShieldApp extends StatefulWidget {
  final String initialServerUrl;
  final AppLocale initialLocale;
  final String? initialPreviewRole;
  const VigiShieldApp({
    super.key,
    required this.initialServerUrl,
    required this.initialLocale,
    required this.initialPreviewRole,
  });

  @override
  State<VigiShieldApp> createState() => _VigiShieldAppState();
}

class _VigiShieldAppState extends State<VigiShieldApp> {
  late final AuthStorage _storage;
  late final ApiClient _api;
  late final AuthProvider _authProvider;
  late final EventProvider _eventProvider;
  late final SystemProvider _systemProvider;
  late final CameraProvider _cameraProvider;
  late final MobileCameraPublisher _mobilePublisher;
  late final CapturaCamara _capturas;
  bool _transmitia = false;
  late final ValidationProvider _validationProvider;
  late final EmergencyProvider _emergencyProvider;
  static const _emergencyKey = 'emergency_settings';
  final Dio _validationDio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3)));
  late final ServerConfigProvider _serverConfigProvider;
  late final LocaleProvider _localeProvider;
  late final DevSettingsProvider _devSettingsProvider;
  final UiProvider _uiProvider = UiProvider();
  late final GoRouter _router;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _storage = AuthStorage();
    _api = ApiClient(_storage, baseUrl: widget.initialServerUrl);

    _authProvider = AuthProvider(AuthService(_api), _storage);
    _eventProvider = EventProvider(EventService(_api));
    _systemProvider = SystemProvider(SystemService(_api));
    _cameraProvider = CameraProvider(CameraDataService(_api));
    // El publicador vive aqui, no dentro de la pantalla: si lo tuviera la
    // pantalla, retroceder para ver la camara en vivo cortaria la propia
    // transmision que se quiere ver.
    _mobilePublisher = MobileCameraPublisher(
      transport: CameraDataService(_api),
      antesDeAbrir: OrientacionApp.instance.iniciarTransmision,
    );
    _capturas = CapturaCamara(_storage);
    _mobilePublisher.addListener(_alCambiarTransmision);
    // Teléfono girado mientras transmite: la pantalla ya giró con él; se
    // reinicia la sesión para que el video siga derecho y con tamaño estable.
    OrientacionApp.instance.alCambiarFisicaTransmitiendo = (_) => Future<void>.delayed(
        const Duration(milliseconds: 1200), _mobilePublisher.reiniciar);
    _validationProvider = ValidationProvider(
      platform: ValidationPlatform(),
      canMonitor: () => _authProvider.isAuthenticated && _systemProvider.status?.isMonitoringActive != false,
      loadPaused: () async => !(await SystemService(_api).getStatus()).isMonitoringActive,
      loadCameras: CameraDataService(_api).getCameras,
      loadEvents: (started) async => (await EventService(_api).getEvents(from: started, pageSize: 100)).items,
      loadStatus: (camera) async {
        final host = Uri.parse(camera.hlsViewUrl!).host;
        final token = await _storage.getToken();
        final response = await _validationDio.get<Map<String, dynamic>>(
          'https://$host/ai/status/${Uri.encodeComponent(camera.id)}',
          options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}));
        return response.data ?? {};
      },
    );
    _emergencyProvider = EmergencyProvider(
      readSettings: () => _storage.readValue(_emergencyKey),
      writeSettings: (v) => _storage.writeValue(_emergencyKey, v),
      effects: DeviceEmergencyEffects(),
      canMonitor: () => _authProvider.isAuthenticated && _systemProvider.status?.isMonitoringActive != false,
      loadCameras: CameraDataService(_api).getCameras,
      loadStatus: _validationProvider.loadStatus,
    )..load();
    _cameraProvider.addListener(_syncValidationCameras);
    _systemProvider.addListener(_syncValidationSystem);
    _authProvider.addListener(_emergencyProvider.reconcile);
    _systemProvider.addListener(_emergencyProvider.reconcile);
    _serverConfigProvider =
        ServerConfigProvider(_storage, _api, widget.initialServerUrl);
    _localeProvider = LocaleProvider(_storage, widget.initialLocale);
    _devSettingsProvider =
        DevSettingsProvider(_storage, widget.initialPreviewRole);
    // Al cerrar sesión hay que vaciar estos: viven toda la vida de la app y si
    // no, la siguiente cuenta hereda cámaras, eventos y alertas de la anterior.
    _authProvider.registerSessionScoped(
        [_eventProvider, _systemProvider, _cameraProvider, _validationProvider,
          _mobilePublisher, _emergencyProvider]);
    _router = createRouter(_authProvider);
    _initDeepLinks();
  }

  void _syncValidationCameras() => _validationProvider.updateCameras(_cameraProvider.cameras);
  void _syncValidationSystem() {
    if (_systemProvider.status?.isMonitoringActive == false) _validationProvider.stop();
  }
  /// Lo que pasa alrededor de la transmisión del teléfono:
  /// - la pantalla no se apaga (si se apagara, la app pasaría a segundo plano
  ///   y la transmisión se cortaría);
  /// - al terminar, cada vista recupera su orientación;
  /// - al empezar, se toma una captura para el editor de zonas de interés.
  void _alCambiarTransmision() {
    final p = _mobilePublisher;
    final activo = p.isPublishing || p.isStarting;
    if (activo) {
      PantallaEncendida.pedir('transmision');
    } else {
      PantallaEncendida.soltar('transmision');
      OrientacionApp.instance.finTransmision();
    }
    if (p.isPublishing && !_transmitia) {
      final id = p.cameraId;
      Future<void>.delayed(const Duration(seconds: 4), () async {
        if (!_mobilePublisher.isPublishing || _mobilePublisher.cameraId != id) return;
        if (_cameraProvider.cameras.every((c) => c.id != id)) await _cameraProvider.fetchCameras();
        final cam = _cameraProvider.cameras.where((c) => c.id == id).firstOrNull;
        if (cam != null) await _capturas.tomar(cam);
      });
    }
    _transmitia = p.isPublishing;
  }

  @override
  void dispose() {
    _mobilePublisher.removeListener(_alCambiarTransmision);
    _cameraProvider.removeListener(_syncValidationCameras);
    _systemProvider.removeListener(_syncValidationSystem);
    _authProvider.removeListener(_emergencyProvider.reconcile);
    _systemProvider.removeListener(_emergencyProvider.reconcile);
    _emergencyProvider.dispose();
    _validationProvider.dispose();
    _validationDio.close(force: true);
    super.dispose();
  }

  /// Abre la app en el destino de un enlace: el evento de una alerta
  /// (`/event/<id>`), el restablecimiento de contraseña (`/reset?token=`) o una
  /// invitación a una vivienda (`/invitacion?token=`).
  ///
  /// Todo enlace que el sistema envíe por correo debe resolverse AQUÍ y estar
  /// declarado en el AndroidManifest: si falta cualquiera de las dos cosas,
  /// Android lo abre en el navegador aunque la app esté instalada.
  Future<void> _initDeepLinks() async {
    // Enlace en caliente (app ya abierta): navegar sobre la pantalla actual.
    _appLinks.uriLinkStream.listen((uri) {
      final destino = _rutaPara(uri);
      if (destino != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _router.push(destino));
      }
    }, onError: (_) {});
    // Arranque en frío: se guarda para que la pantalla de bienvenida navegue
    // después de resolver la sesión (un push aquí lo borraría su go('/dashboard')).
    try {
      final initial = await _appLinks.getInitialLink();
      final destino = initial == null ? null : _rutaPara(initial);
      if (destino != null) DeepLinks.pendingRoute = destino;
    } catch (_) {/* no initial link */}
  }

  /// Ruta interna a la que corresponde un enlace, o null si no lo reconocemos.
  String? _rutaPara(Uri uri) {
    final segs = uri.pathSegments;
    final token = uri.queryParameters['token'];

    // En https://vigishield.app/reset?token= la palabra va en la ruta, pero en
    // vigishield://reset?token= va en el host. Hay que mirar las dos: el
    // esquema propio es la via de respaldo cuando el navegador se queda el
    // enlace del correo.
    bool apunta(String nombre) => uri.host == nombre || segs.contains(nombre);

    if (apunta('reset') && (token ?? '').isNotEmpty) {
      return '/reset-password?token=$token';
    }
    if (apunta('invitacion') && (token ?? '').isNotEmpty) {
      return '/invitacion?token=$token';
    }
    final id = _extractEventId(uri);
    return id == null ? null : '/history/$id';
  }

  String? _extractEventId(Uri uri) {
    final segs = uri.pathSegments;
    if (uri.host == 'event' && segs.isNotEmpty) return segs.first; // vigishield://event/<id>
    final i = segs.indexOf('event'); // https://vigishield.app/event/<id>
    if (i >= 0 && i + 1 < segs.length) return segs[i + 1];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        Provider<CapturaCamara>.value(value: _capturas),
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _eventProvider),
        ChangeNotifierProvider.value(value: _systemProvider),
        ChangeNotifierProvider.value(value: _cameraProvider),
        ChangeNotifierProvider.value(value: _mobilePublisher),
        ChangeNotifierProvider.value(value: _validationProvider),
        ChangeNotifierProvider.value(value: _emergencyProvider),
        ChangeNotifierProvider.value(value: _serverConfigProvider),
        ChangeNotifierProvider.value(value: _localeProvider),
        ChangeNotifierProvider.value(value: _devSettingsProvider),
        ChangeNotifierProvider.value(value: _uiProvider),
      ],
      child: Builder(
        builder: (context) {
          final router = _router;
          final locale = context.watch<LocaleProvider>().flutterLocale;
          return MaterialApp.router(
            title: 'VigiShield',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            locale: locale,
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Re-key the visible subtree by language so every screen re-renders
            // its (read-based) strings the instant the user switches languages —
            // without tearing down the go_router navigation stack.
            builder: (context, child) => _OcultarTeclado(
              child: KeyedSubtree(
                key: ValueKey(locale.languageCode),
                child: ConsentimientoGate(
                  child: EmergencyOverlay(
                    child: ValidationOverlay(child: child ?? const SizedBox.shrink()),
                  ),
                ),
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}

/// Oculta el teclado al tocar fuera de un campo o al arrastrar una lista.
///
/// Se envuelve la app entera en vez de repetirlo en cada pantalla: antes, con
/// el teclado abierto, la unica forma de cerrarlo era el boton del sistema, y
/// en formularios largos tapaba justo lo que hacia falta leer.
class _OcultarTeclado extends StatelessWidget {
  final Widget child;
  const _OcultarTeclado({required this.child});

  void _soltarFoco() {
    final foco = FocusManager.instance.primaryFocus;
    if (foco != null && foco.hasFocus) foco.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // translucent: no se traga los toques, solo los observa.
      behavior: HitTestBehavior.translucent,
      onTap: _soltarFoco,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          // Solo al arrastrar con el dedo; un desplazamiento programatico
          // (por ejemplo al enfocar un campo) no debe cerrar el teclado.
          if (n.dragDetails != null) _soltarFoco();
          return false;
        },
        child: child,
      ),
    );
  }
}
