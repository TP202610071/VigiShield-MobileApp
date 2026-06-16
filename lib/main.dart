import 'package:flutter/material.dart';
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
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // libmpv video backend
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
  late final ServerConfigProvider _serverConfigProvider;
  late final LocaleProvider _localeProvider;
  late final DevSettingsProvider _devSettingsProvider;
  final UiProvider _uiProvider = UiProvider();

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
    _localeProvider = LocaleProvider(_storage, widget.initialLocale);
    _devSettingsProvider =
        DevSettingsProvider(_storage, widget.initialPreviewRole);
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
        ChangeNotifierProvider.value(value: _localeProvider),
        ChangeNotifierProvider.value(value: _devSettingsProvider),
        ChangeNotifierProvider.value(value: _uiProvider),
      ],
      child: Builder(
        builder: (context) {
          final router = createRouter(_authProvider);
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
            builder: (context, child) => KeyedSubtree(
              key: ValueKey(locale.languageCode),
              child: child ?? const SizedBox.shrink(),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
