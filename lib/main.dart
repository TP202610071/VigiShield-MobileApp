import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/storage/auth_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'data/services/camera_service.dart';
import 'data/services/event_service.dart';
import 'data/services/system_service.dart';
import 'providers/auth_provider.dart';
import 'providers/camera_provider.dart';
import 'providers/event_provider.dart';
import 'providers/server_config_provider.dart';
import 'providers/system_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // libmpv video backend
  await initializeDateFormatting('es', null);

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load stored server URL before building the widget tree so ApiClient starts
  // with the correct address (real device vs emulator).
  final storage = AuthStorage();
  final savedUrl = await storage.getServerUrl();
  final initialUrl = savedUrl ?? AppConstants.defaultEmulatorUrl;

  runApp(VigiShieldApp(initialServerUrl: initialUrl));
}

class VigiShieldApp extends StatefulWidget {
  final String initialServerUrl;
  const VigiShieldApp({super.key, required this.initialServerUrl});

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
  late final ServerConfigProvider _serverConfigProvider;

  @override
  void initState() {
    super.initState();
    _storage = AuthStorage();
    _api = ApiClient(_storage, baseUrl: widget.initialServerUrl);

    _authProvider = AuthProvider(AuthService(_api), _storage);
    _eventProvider = EventProvider(EventService(_api));
    _systemProvider = SystemProvider(SystemService(_api));
    _cameraProvider = CameraProvider(CameraDataService(_api));
    _serverConfigProvider =
        ServerConfigProvider(_storage, _api, widget.initialServerUrl);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _eventProvider),
        ChangeNotifierProvider.value(value: _systemProvider),
        ChangeNotifierProvider.value(value: _cameraProvider),
        ChangeNotifierProvider.value(value: _serverConfigProvider),
      ],
      child: Builder(
        builder: (context) {
          final router = createRouter(_authProvider);
          return MaterialApp.router(
            title: 'VigiShield',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
