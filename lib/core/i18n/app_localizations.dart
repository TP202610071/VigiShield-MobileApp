import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/auth_storage.dart';

/// Supported app languages. Spanish is the default.
enum AppLocale { es, en }

extension AppLocaleX on AppLocale {
  String get code => this == AppLocale.es ? 'es' : 'en';
  Locale get flutterLocale => Locale(code);
  static AppLocale fromCode(String? code) =>
      code == 'en' ? AppLocale.en : AppLocale.es;
}

/// Holds the active language, persists it, and exposes the [AppStrings] bundle.
/// Changing it rebuilds the whole app (MaterialApp listens via Provider).
class LocaleProvider extends ChangeNotifier {
  final AuthStorage _storage;
  AppLocale _locale;

  LocaleProvider(this._storage, AppLocale initial) : _locale = initial;

  AppLocale get locale => _locale;
  Locale get flutterLocale => _locale.flutterLocale;
  AppStrings get strings => AppStrings(_locale == AppLocale.en);
  bool get isEnglish => _locale == AppLocale.en;

  Future<void> setLocale(AppLocale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    await _storage.saveLocale(locale.code);
  }

  static Future<AppLocale> load(AuthStorage storage) async =>
      AppLocaleX.fromCode(await storage.getLocale());
}

/// Convenient access: `context.l10n.someKey`.
///
/// Uses `read` (not `watch`) so it is safe to call from event handlers, async
/// callbacks and `showModalBottomSheet` builders — `watch` would throw there in
/// debug builds. Live language switching is driven instead by a keyed rebuild in
/// [MaterialApp.router]'s builder (see main.dart), so the whole visible subtree
/// re-renders with the new strings when the locale changes.
extension L10nContext on BuildContext {
  AppStrings get l10n => read<LocaleProvider>().strings;
}

/// All user-facing strings. One getter per string, both languages inline so a
/// translation is never silently missing. `en` selects English, else Spanish.
class AppStrings {
  final bool en;
  const AppStrings(this.en);

  String _(String es, String enText) => en ? enText : es;

  // ── Common ────────────────────────────────────────────────────────────────
  String get appName => 'VigiShield';
  String get save => _('Guardar', 'Save');
  String get saveChanges => _('Guardar cambios', 'Save changes');
  String get cancel => _('Cancelar', 'Cancel');
  String get delete => _('Eliminar', 'Delete');
  String get remove => _('Quitar', 'Remove');
  String get retry => _('Reintentar', 'Retry');
  String get close => _('Cerrar', 'Close');
  String get add => _('Agregar', 'Add');
  String get edit => _('Editar', 'Edit');
  String get requiredField => _('Campo requerido', 'Required field');
  String get error => _('Error', 'Error');
  String get loading => _('Cargando…', 'Loading…');
  String get comingSoon => _('Próximamente', 'Coming soon');

  // ── Bottom navigation ───────────────────────────────────────────────────────
  String get navHome => _('Inicio', 'Home');
  String get navCamera => _('Cámara', 'Camera');
  String get navHistory => _('Historial', 'History');
  String get navSettings => _('Ajustes', 'Settings');

  // ── Dashboard ───────────────────────────────────────────────────────────────
  String greeting(String name) => _('Hola, $name', 'Hi, $name');
  String get recentEvents => _('Eventos recientes', 'Recent events');
  String get seeAll => _('Ver todo', 'See all');
  String get systemActive => _('Sistema activo', 'System active');
  String get systemPaused => _('Sistema pausado', 'System paused');
  String get monitoringRealtime =>
      _('Monitoreando en tiempo real', 'Monitoring in real time');
  String get monitoringStopped =>
      _('El monitoreo está detenido', 'Monitoring is stopped');
  String get pause => _('Pausar', 'Pause');
  String get resume => _('Reanudar', 'Resume');
  String get eventsToday => _('Eventos hoy', 'Events today');
  String get lastEvent => _('Último evento', 'Last event');
  String get noRecentEvents => _('Sin eventos recientes', 'No recent events');
  String get homeSafe => _('Tu hogar está seguro', 'Your home is safe');

  // ── Settings ────────────────────────────────────────────────────────────────
  String get settings => _('Ajustes', 'Settings');
  String get sectionAccount => _('CUENTA', 'ACCOUNT');
  String get sectionSystem => _('SISTEMA', 'SYSTEM');
  String get sectionPreferences => _('PREFERENCIAS', 'PREFERENCES');
  String get sectionAbout => _('ACERCA DE', 'ABOUT');
  String get sectionDeveloper => _('DESARROLLADOR', 'DEVELOPER');
  String get changePassword => _('Cambiar contraseña', 'Change password');
  String get currentPassword => _('CONTRASEÑA ACTUAL', 'CURRENT PASSWORD');
  String get newPassword => _('NUEVA CONTRASEÑA', 'NEW PASSWORD');
  String get passwordMin => _('Mínimo 8 caracteres', 'At least 8 characters');

  // ── Contraseña segura (checklist en vivo) ───────────────────────────────────
  String get passwordWeak =>
      _('La contraseña no cumple los requisitos', 'The password does not meet the requirements');
  String pwRuleLength(int n) => _('Al menos $n caracteres', 'At least $n characters');
  String get pwRuleUpper => _('Una letra mayúscula', 'One uppercase letter');
  String get pwRuleLower => _('Una letra minúscula', 'One lowercase letter');
  String get pwRuleDigit => _('Un número', 'One number');
  String get pwRuleSymbol => _('Un carácter especial', 'One special character');
  // ── Restablecer contraseña / invitación (enlaces de correo) ─────────────────
  String get resetTitle => _('Nueva contraseña', 'New password');
  String get resetSubtitle => _(
      'Elige una contraseña nueva para tu cuenta.',
      'Choose a new password for your account.');
  String get resetDone => _(
      'Listo. Ya puedes iniciar sesión con tu contraseña nueva.',
      'Done. You can now sign in with your new password.');
  String get resetLinkInvalid => _(
      'Este enlace ya caducó o fue utilizado. Solicita uno nuevo desde "¿Olvidaste tu contraseña?".',
      'This link has expired or was already used. Request a new one from "Forgot your password?".');
  String get repeatPassword => _('Repite la contraseña', 'Repeat the password');
  String get passwordsDoNotMatch => _('Las contraseñas no coinciden', 'The passwords do not match');
  String get savePassword => _('Guardar contraseña', 'Save password');
  String get backToLogin => _('Volver a iniciar sesión', 'Back to sign in');

  String get connectionError => _(
      'No se pudo conectar con el servidor. Revisa tu conexión.',
      'Could not reach the server. Check your connection.');
  String get inviteTitle => _('Invitación a una vivienda', 'Household invitation');
  String invitedBy(String quien) => _(
      '$quien te invitó a la vigilancia de su vivienda.',
      '$quien invited you to monitor their home.');
  String get inviteSubtitle => _(
      'Crea tu cuenta para unirte. Tendrás acceso de solo lectura: video en vivo, historial y evidencias.',
      'Create your account to join. You will have read-only access: live video, history and evidence.');
  String get inviteAccept => _('Unirme a la vivienda', 'Join the household');
  String get inviteDone => _(
      'Listo. Ya formas parte de la vivienda.',
      'Done. You are now part of the household.');
  String get inviteInvalid => _(
      'Este enlace de invitación no es válido.',
      'This invitation link is not valid.');
  String get inviteUsed => _(
      'Esta invitación ya fue utilizada. Si ya tienes cuenta, inicia sesión.',
      'This invitation was already used. If you already have an account, sign in.');
  String get inviteExpired => _(
      'Esta invitación caducó. Pide al residente principal que te envíe una nueva.',
      'This invitation has expired. Ask the primary resident to send you a new one.');
  String get yourEmail => _('Tu correo', 'Your email');
  String get yourName => _('Tu nombre', 'Your name');
  String get createYourPassword => _('Crea tu contraseña', 'Create your password');

  // ── Usuarios de la vivienda ─────────────────────────────────────────────────
  String get householdUsers => _('Usuarios', 'Users');
  String get householdUsersHint => _(
      'Personas con acceso de solo lectura a tu vivienda: pueden ver el video y el historial, pero no cambiar la configuración.',
      'People with read-only access to your home: they can see the video and history, but cannot change settings.');
  String get inviteUser => _('Invitar', 'Invite');
  String get inviteUserTitle => _('Invitar a alguien', 'Invite someone');
  String get inviteUserHint => _(
      'Le enviaremos un correo con un enlace para crear su cuenta. Caduca en 7 días.',
      'We will email them a link to create their account. It expires in 7 days.');
  String get inviteSent => _('Invitación enviada', 'Invitation sent');
  String get noSecondaryUsers => _('Sin usuarios invitados', 'No invited users');
  String get noSecondaryUsersHint => _(
      'Invita a alguien de confianza para que pueda vigilar la vivienda contigo.',
      'Invite someone you trust so they can watch over the home with you.');
  String get revokeAccess => _('Revocar acceso', 'Revoke access');
  String revokeAccessConfirm(String nombre) => _(
      '¿Quitar el acceso de $nombre? Dejará de poder ver tu vivienda de inmediato.',
      'Remove $nombre\'s access? They will immediately lose access to your home.');
  String get accessRevoked => _('Acceso revocado', 'Access revoked');
  String memberSinceShort(String fecha) => _('Desde $fecha', 'Since $fecha');

  String get pwWeak => _('Débil', 'Weak');
  String get pwMedium => _('Media', 'Medium');
  String get pwStrong => _('Segura', 'Strong');
  String get passwordUpdated => _('Contraseña actualizada', 'Password updated');
  String get configureAlerts => _('Configurar alertas', 'Configure alerts');
  String get configureAlertsHint => _(
      'Elige qué situaciones quieres que te avisen. Las que apagues se seguirán registrando en el historial, pero sin notificarte.',
      'Choose which situations you want to be alerted about. The ones you turn off are still recorded in the history, just without notifying you.');
  String get disableAllAlerts => _('Desactivar todas', 'Turn all off');
  String get enableAllAlerts => _('Activar todas', 'Turn all on');
  String get myCameras => _('Mis cámaras', 'My cameras');
  String get authorizedFaces => _('Caras autorizadas', 'Authorized faces');
  String get language => _('Idioma', 'Language');
  String get spanish => _('Español', 'Spanish');
  String get english => _('Inglés', 'English');
  String get appInfo => _('Información', 'Information');
  String version(String v) => _('VigiShield v$v', 'VigiShield v$v');
  String get logout => _('Cerrar sesión', 'Log out');
  String get logoutConfirm =>
      _('¿Deseas cerrar tu sesión?', 'Do you want to log out?');
  String get developerOptions =>
      _('Opciones de desarrollador', 'Developer options');

  // ── Roles ───────────────────────────────────────────────────────────────────
  String get roleAdmin => _('Administrador', 'Administrator');
  String get rolePrimary => _('Residente principal', 'Primary resident');
  String get roleSecondary => _('Residente secundario', 'Secondary resident');
  String roleLabel(String role) => switch (role) {
        'Admin' => roleAdmin,
        'Primary' => rolePrimary,
        'Secondary' => roleSecondary,
        _ => role,
      };

  // ── Profile ─────────────────────────────────────────────────────────────────
  String get profile => _('Perfil', 'Profile');
  String get editProfile => _('Editar perfil', 'Edit profile');
  String get name => _('Nombre', 'Name');
  String get fullName => _('NOMBRE COMPLETO', 'FULL NAME');
  String get email => _('Correo', 'Email');
  String get role => _('Rol', 'Role');
  String get whatsapp => _('WhatsApp', 'WhatsApp');
  String get whatsappLabel => _('NÚMERO DE WHATSAPP', 'WHATSAPP NUMBER');
  String get whatsappOptional =>
      _('Opcional — para alertas', 'Optional — for alerts');
  String get changePhoto => _('Cambiar foto', 'Change photo');
  String get fromGallery => _('Galería', 'Gallery');
  String get fromCamera => _('Cámara', 'Camera');
  String get photoUpdated =>
      _('Foto de perfil actualizada', 'Profile photo updated');
  String get photoError =>
      _('No se pudo subir la foto', 'Could not upload the photo');
  String get profileUpdated => _('Perfil actualizado', 'Profile updated');
  String memberSince(String date) =>
      _('Miembro desde $date', 'Member since $date');

  // ── Camera ──────────────────────────────────────────────────────────────────
  String get live => _('EN VIVO', 'LIVE');
  String get aiDetection => _('AI DETECCIÓN', 'AI DETECTION');
  String get connecting => _('Conectando…', 'Connecting…');
  String get aiConnecting =>
      _('Conectando al motor AI…', 'Connecting to the AI engine…');
  String get aiHint => _(
      'Asegúrate de que el backend Python esté corriendo.\nLos frames aparecerán cuando se procese el primer fotograma.',
      'Make sure the Python backend is running.\nFrames appear once the first one is processed.');
  String get noCameras =>
      _('No hay cámaras configuradas', 'No cameras configured');
  String get noCamerasHint => _(
      'Ve a Ajustes → Mis Cámaras para agregar tu cámara IP.',
      'Go to Settings → My Cameras to add your IP camera.');
  String get addCamera => _('Agregar cámara', 'Add camera');
  String get streamUnavailable => _('Stream no disponible', 'Stream unavailable');
  String get streamUnavailableHint => _(
      'Verifica que MediaMTX esté corriendo y la cámara accesible.',
      'Check that MediaMTX is running and the camera is reachable.');
  String get allCameras => _('Todas las cámaras', 'All cameras');
  String get tipFullscreen => _('Pantalla completa', 'Fullscreen');
  String get tipExitFullscreen => _('Salir de pantalla completa', 'Exit fullscreen');
  String get tipScreenshot => _('Captura de pantalla', 'Screenshot');
  String get tipCameraSettings => _('Ajustes de cámara', 'Camera settings');
  String get tipReconnect => _('Reconectar', 'Reconnect');
  String get tipAiView => _('Vista AI', 'AI view');
  String get tipLiveView => _('Vista en vivo', 'Live view');
  String get tipViewAll => _('Ver todas', 'View all');
  String get tipExitGrid => _('Salir del modo cuadrícula', 'Exit grid mode');
  String get screenshotSaved =>
      _('Captura guardada en galería', 'Screenshot saved to gallery');
  String screenshotError(String e) =>
      _('Error al guardar: $e', 'Save failed: $e');

  // Camera control sheet
  String get cameraSettings => _('Ajustes de Cámara', 'Camera Settings');
  String get cameraSettingsHint => _(
      'Valores actuales leídos de la cámara por la red local. Mueve y guarda para aplicar en vivo.',
      'Current values read from the camera over your local network. Adjust and save to apply live.');
  String get cameraSettingsLanOnly => _(
      'No se pudo contactar con la cámara. Estos ajustes viajan directo del teléfono a la cámara, así que conecta el teléfono al wifi de casa (el mismo de la cámara) e inténtalo de nuevo. Desde fuera de casa no se pueden cambiar.',
      "Couldn't reach the camera. These settings go straight from your phone to the camera, so connect the phone to your home Wi-Fi (the camera's network) and try again. They can't be changed from outside the house.");
  String get cameraSettingsBadCredentials => _(
      'La cámara respondió, pero rechazó el usuario o la contraseña guardados. Corrígelos en Mis cámaras y vuelve a intentarlo.',
      'The camera answered but rejected the saved username or password. Fix them in My cameras and try again.');
  // Bloqueo biometrico
  String get biometricReason => _(
      'Confirma tu identidad para entrar a VigiShield',
      'Confirm your identity to open VigiShield');
  String get biometricLock => _('Desbloqueo biométrico', 'Biometric unlock');
  String get biometricLockHint => _(
      'Pide tu huella o rostro cada vez que abras la app, aunque la sesión siga iniciada.',
      'Ask for your fingerprint or face every time you open the app, even if the session is still active.');
  String get biometricFailed =>
      _('No se pudo verificar tu identidad', 'Could not verify your identity');
  String get biometricRetry => _('Reintentar', 'Try again');
  String get biometricUsePassword =>
      _('Entrar con contraseña', 'Sign in with password');
  String get applyToCamera => _('Aplicar a la cámara', 'Apply to camera');
  String get settingsApplied =>
      _('Ajustes aplicados a la cámara', 'Settings applied to the camera');
  String get settingsApplyError =>
      _('Error al aplicar ajustes', 'Failed to apply settings');
  String get grpImage => _('IMAGEN', 'IMAGE');
  String get grpVideo => _('VIDEO', 'VIDEO');
  String get brightness => _('Brillo', 'Brightness');
  String get contrast => _('Contraste', 'Contrast');
  String get saturation => _('Saturación', 'Saturation');
  String get sharpness => _('Nitidez', 'Sharpness');
  String get wdr => _('WDR (rango dinámico)', 'WDR (dynamic range)');
  String get nightVision => _('Visión nocturna', 'Night vision');
  String get nightAuto => _('Automática', 'Automatic');
  String get nightOn => _('Siempre ON', 'Always ON');
  String get nightOff => _('Siempre OFF', 'Always OFF');
  String get bitrate => _('Bitrate', 'Bitrate');
  String get fps => _('FPS', 'FPS');
  String get keyframeInterval => _('Intervalo keyframe', 'Keyframe interval');

  // ── History ─────────────────────────────────────────────────────────────────
  String get history => _('Historial', 'History');
  // Las fichas de filtro por tipo toman su texto de eventTypeLabel, no de
  // cadenas propias: tener dos listas era justo lo que hacía que el mismo evento
  // se llamara de una forma en el filtro y de otra en la ficha del historial.
  String get filterAll => _('Todos', 'All');
  String get filterAllCameras => _('Todas las cámaras', 'All cameras');
  String get noEventsLogged =>
      _('Sin eventos registrados', 'No events logged');
  String get eventsWillAppear => _(
      'Los eventos detectados aparecerán aquí',
      'Detected events will appear here');

  // ── Event detail ────────────────────────────────────────────────────────────
  String get eventDetail => _('Detalle del evento', 'Event detail');
  String get details => _('Detalles', 'Details');
  String get person => _('Persona', 'Person');
  String get riskLevel => _('Nivel de riesgo', 'Risk level');
  String get confidence => _('Confianza', 'Confidence');
  String get eventType => _('Tipo de evento', 'Event type');
  String get imageCapture => _('Captura de imagen', 'Image capture');
  String get imageUnavailable =>
      _('Imagen no disponible', 'Image unavailable');
  String get videoClip => _('Clip de video', 'Video clip');
  String get fullscreen => _('Pantalla completa', 'Fullscreen');
  String get share => _('Compartir', 'Share');
  String get savedToGallery => _('Guardado en la galería', 'Saved to gallery');
  String get saveFailed => _('No se pudo guardar', 'Could not save');
  String get nightActivity => _('Actividad nocturna', 'Nighttime activity');
  String get deleteEvent => _('Eliminar evento', 'Delete event');
  String get deleteEventConfirm => _(
      '¿Estás seguro de que deseas eliminar este evento?',
      'Are you sure you want to delete this event?');
  String get eventNotFound => _('Evento no encontrado', 'Event not found');

  // ── Risk labels ─────────────────────────────────────────────────────────────
  String riskLabel(String risk) => switch (risk) {
        'None' => _('Ninguno', 'None'),
        'Low' => _('Bajo', 'Low'),
        'Medium' => _('Medio', 'Medium'),
        'High' => _('Alto', 'High'),
        'Critical' => _('Crítico', 'Critical'),
        _ => risk,
      };

  // ── Alert config ────────────────────────────────────────────────────────────
  String get alertUnknownPerson =>
      _('Persona desconocida', 'Unknown person');
  String get alertForcedAccess => _('Acceso forzado', 'Forced access');
  String get alertLoiterer => _('Merodeo', 'Loitering');
  String get alertClimbing => _('Escalamiento', 'Climbing');
  String get alertAggression => _('Agresión física', 'Physical aggression');

  // ── Auth ────────────────────────────────────────────────────────────────────
  String get welcome => _('Bienvenido', 'Welcome');
  String get loginSubtitle => _(
      'Inicia sesión para acceder a tu sistema de seguridad',
      'Sign in to access your security system');
  String get emailField => _('CORREO ELECTRÓNICO', 'EMAIL');
  String get passwordField => _('CONTRASEÑA', 'PASSWORD');
  String get invalidEmail => _('Correo inválido', 'Invalid email');
  String get login => _('Iniciar sesión', 'Sign in');
  String get loginError =>
      _('Error al iniciar sesión', 'Sign-in failed');
  String get forgotPassword =>
      _('¿Olvidaste tu contraseña?', 'Forgot your password?');
  String get noAccount => _('¿No tienes cuenta? ', "Don't have an account? ");
  String get createAccount => _('Crear cuenta', 'Create account');
  String get registerSubtitle =>
      _('Configura tu sistema VigiShield', 'Set up your VigiShield system');
  String get nameHint => _('Tu nombre', 'Your name');
  String get nameMin => _('Mínimo 2 caracteres', 'At least 2 characters');
  String get passwordHintMin => _('Mínimo 8 caracteres', 'At least 8 characters');
  String get householdAddressField => _('DIRECCIÓN DEL HOGAR', 'HOME ADDRESS');
  String get addressHint => _('Av. Ejemplo 123', '123 Example St');
  String get addressTooShort => _('Dirección muy corta', 'Address too short');
  String get registerPrimaryInfo => _(
      'Serás el residente principal con acceso completo al sistema.',
      'You will be the primary resident with full system access.');
  String get alreadyHaveAccount =>
      _('¿Ya tienes cuenta? ', 'Already have an account? ');
  String get registerError => _('Error al registrarse', 'Registration failed');
  String get recoverPassword => _('Recuperar contraseña', 'Recover password');
  String get recoverHint => _(
      'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
      "Enter your email and we'll send you a reset link.");
  String get sendLink => _('Enviar enlace', 'Send link');
  String linkSent(String email) => _(
      'Enlace enviado a $email.\nRevisa tu bandeja de entrada.',
      'Link sent to $email.\nCheck your inbox.');

  // ── Developer screen ────────────────────────────────────────────────────────
  String get developer => _('Desarrollador', 'Developer');
  String get developerTools => _('Herramientas de desarrollador', 'Developer tools');
  String get rolePreview => _('Vista previa de rol', 'Role preview');
  String get rolePreviewHint => _(
      'Cambia cómo se ve la app para presentar como otro tipo de usuario. No cambia tu cuenta real.',
      "Change how the app looks to present as another user type. Doesn't change your real account.");
  String get previewing => _('Previsualizando como', 'Previewing as');
  String get exitPreview => _('Salir de la vista previa', 'Exit preview');
  String get serverAddress => _('Dirección del servidor', 'Server address');
  String get serverAddressHint => _(
      'Solo para administradores. La app de producción usa el servidor en la nube.',
      'Administrators only. The production app uses the cloud server.');
  String get serverUrlField => _('URL del servidor', 'Server URL');
  String get saveAndReconnect =>
      _('Guardar y reconectar', 'Save and reconnect');
  String get serverUpdated => _(
      'Servidor actualizado. Inicia sesión de nuevo.',
      'Server updated. Sign in again.');
  String get manageAdmins =>
      _('Administradores', 'Administrators');
  String get manageAdminsHint => _(
      'Cuentas con acceso a las herramientas de desarrollador.',
      'Accounts with access to the developer tools.');
  String get addAdmin => _('Agregar administrador', 'Add administrator');
  String get adminEmailField =>
      _('CORREO DEL USUARIO', 'USER EMAIL');
  String get adminAdded => _('Administrador agregado', 'Administrator added');
  String get adminRemoved => _('Administrador removido', 'Administrator removed');
  String get adminAddHint => _(
      'El usuario debe tener una cuenta registrada. Se le concederá el rol de administrador.',
      'The user must already have an account. They will be granted the administrator role.');
  String get diagnostics => _('Diagnóstico', 'Diagnostics');
  String get you => _('Tú', 'You');

  // ── Event type labels ───────────────────────────────────────────────────────
  // Este es el vocabulario CANÓNICO del sistema: debe coincidir palabra por
  // palabra con EventService.SpanishLabel del backend, que es el que nombra el
  // evento en los mensajes de WhatsApp. Si aquí dice una cosa y allá otra, el
  // mismo incidente aparece con dos nombres distintos.
  // Son sustantivos ("Merodeo"), no frases con "detectado": el tipo de evento se
  // usa como etiqueta, y el hecho de que se haya detectado ya lo dice el contexto.
  String eventTypeLabel(String type) => switch (type) {
        'FaceRecognized' => _('Acceso reconocido', 'Recognized access'),
        'UnknownFace' => _('Persona desconocida', 'Unknown person'),
        'LowConfidenceFace' =>
          _('Detección de baja confianza', 'Low-confidence detection'),
        'RecurrentUnknownFace' => _(
            'Visitante desconocido recurrente', 'Recurrent unknown visitor'),
        'ForcedAccessAttempt' =>
          _('Intento de acceso forzado', 'Forced-access attempt'),
        'LockpickingAttempt' =>
          _('Intento de ganzúa', 'Lock-picking attempt'),
        'Tailgating' => _('Merodeo', 'Loitering'),
        'Climbing' => _('Escalamiento', 'Climbing'),
        'Burglary' => _('Allanamiento', 'Burglary'),
        'PhysicalAggression' =>
          _('Agresión física', 'Physical aggression'),
        'Assault' => _('Asalto', 'Assault'),
        'Abuse' => _('Abuso', 'Abuse'),
        'Arrest' => _('Arresto', 'Arrest'),
        'Stealing' => _('Hurto', 'Theft'),
        'Shoplifting' => _('Hurto en tienda', 'Shoplifting'),
        'Vandalism' => _('Vandalismo', 'Vandalism'),
        'Robbery' => _('Robo a mano armada', 'Armed robbery'),
        'Arson' => _('Incendio provocado', 'Arson'),
        'Explosion' => _('Explosión', 'Explosion'),
        'Roadaccidents' =>
          _('Accidente de tránsito', 'Traffic accident'),
        'WeaponDetected' => _('Arma detectada', 'Weapon detected'),
        'SuspiciousIntent' => _('Riesgo de intrusión', 'Intrusion risk'),
        _ => type,
      };

  // ── Relative time ───────────────────────────────────────────────────────────
  String get justNow => _('Hace un momento', 'Just now');
  String minutesAgo(int m) => _('Hace $m min', '$m min ago');
  String hoursAgo(int h) => _('Hace $h h', '$h h ago');

  // ── Date formats (intl patterns + locale tag) ───────────────────────────────
  String get localeCode => en ? 'en' : 'es';
  String get dateFormatLong => en ? 'EEEE, MMMM d' : "EEEE d 'de' MMMM";
  String get dateFormatFull =>
      en ? 'MMMM d, yyyy · HH:mm:ss' : "d 'de' MMMM, yyyy · HH:mm:ss";
  String get dateFormatShort => en ? 'MMM d, HH:mm' : 'd MMM, HH:mm';
}
