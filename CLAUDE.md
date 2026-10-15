# VigiShield — app móvil (Flutter)

Sistema de seguridad para viviendas, proyecto de tesis (UPC). La app muestra las
cámaras del hogar, el análisis de IA en vivo, los eventos y las alertas. Este
repo es solo la app. El backend y la IA están en otros repos y se despliegan
desde otra máquina: desde aquí no se tocan servidores.

## Servicios (producción)

| Qué | Dónde |
|---|---|
| API (ASP.NET, Oracle) | `https://api.vigishield.app` |
| IA, video y WHIP (Azure) | `https://api-ai.vigishield.app` (RTSP 8554, HLS por HTTPS, `/ai/...` con JWT) |
| Web, términos y privacidad | `https://vigishield.app`, `/terminos`, `/privacidad` |
| Panel de administración | `https://vigishield.app/admin` (solo rol Admin) |

Repos: `TP202610071/VigiShield-MobileApp` (este), `VigiShield-Main-Backend` y `VigiShield-AI-Backend`.

## Compilar para iOS

```bash
flutter pub get
cd ios && pod install && cd ..        # obligatorio tras cambiar dependencias
flutter build ipa --release
xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
  --apiKey 5RPFG6VXG9 --apiIssuer da3def3c-e780-49b7-81e7-45361d5e6ec2
cd ios && fastlane deliver --skip_screenshots true   # textos y datos de revisión
```

- Llave de la API de App Store Connect (rol App Manager) en
  `~/.appstoreconnect/private_keys/AuthKey_5RPFG6VXG9.p8`. Fuera del repo; nunca se sube.
- Ficha de tienda en `ios/fastlane/` (`Deliverfile`, `metadata/es-MX` y `en-US`,
  `review_notes.txt`, `age_rating.json`, `screenshots/`). Los datos de contacto y la
  contraseña del revisor se leen de `~/.appstoreconnect/vigishield_review.json`.
- TestFlight: grupo interno «Equipo VigiShield» con acceso a todos los builds.
- Bundle ID `com.vigishield.app`, equipo `ZUXS3B846T`, iOS mínimo 15.5, solo iPhone (`TARGETED_DEVICE_FAMILY = 1`).
- ATS: sin excepciones de HTTP; solo `NSAllowsLocalNetworking` (control de la cámara IP en el wifi de casa).
- El `Podfile` define `PERMISSION_CAMERA=1` (permission_handler). Sin eso, el permiso de cámara no se pide.
- `ITSAppUsesNonExemptEncryption = false`: solo se usa HTTPS/TLS estándar.
- Versión: cada tanda sube semver en `pubspec.yaml` (`version: x.y.z+N`) y en
  `_versionPorDefecto` de `lib/core/constants/app_constants.dart`.
  **Cada subida a App Store Connect necesita un número de build (`+N`) mayor.**
  La versión (`x.y.z`) debe coincidir con la que está en preparación en App Store
  Connect (hoy `1.0.0`). Hasta publicarla, las tandas nuevas solo suben el `+N`.
  Los builds 29 y 30 corresponden a 1.0.0.
- El build de release es el de tienda: las herramientas de validación (OE4) no
  se incluyen (`kValidationTools`) y la sesión de validación solo existe en Android.

## Llaves y accesos (carpeta `Cloud`)

Las llaves **nunca van en el repo** (es público). Están en la carpeta `Cloud/`:

- en la raíz del proyecto, al lado de los repos: desde este repo, `../../Cloud/` (PC: `G:\Codigo\VigilShield\Cloud`);
- en iCloud Drive → `Cloud/`, que las sincroniza entre la PC y la Mac.

El detalle con servidores, usuarios y comandos exactos está en **`Cloud/LEEME.md`**. En la Mac, las llaves SSH
necesitan `chmod 600 ../../Cloud/*.key ../../Cloud/*.pem`.

| Archivo en `Cloud/` | Para qué | Cómo se usa |
|---|---|---|
| `oracle-ssh-key-2026-06-11.key` | SSH al servidor del backend (Oracle Cloud): API, web y panel | `ssh -i ../../Cloud/oracle-ssh-key-2026-06-11.key ubuntu@vigishield.app` (no por `api.vigishield.app`, que pasa por Cloudflare) |
| `vigishield-ai-key.pem` | SSH a la VM de IA y video (Azure) | `ssh -i ../../Cloud/vigishield-ai-key.pem vigishield@api-ai.vigishield.app`. Suele estar apagada: ver `LEEME.md`. |
| `oracle-vigishield.env` | Copia de las variables del backend: Supabase, JWT, clave interna, Cloudflare R2, WhatsApp, Gmail y Firebase | Solo de respaldo; la fuente de verdad es `/etc/vigishield/vigishield.env` en el servidor |
| `scripts/desplegar_backend.sh`, `scripts/aplicar_sql.sh` | Desplegar el backend y aplicar migraciones en Supabase sin imprimir la conexión | Ver `LEEME.md` |
| `vigishield-app-firebase-adminsdk-fbsvc-*.json` | Cuenta de servicio de Firebase (`vigishield-app`): el backend envía las notificaciones de Android | Ya instalada en el servidor (`/etc/vigishield/firebase-servicio.json`) |
| `google-services.json` | Firebase de la app Android | Copiar a `android/app/google-services.json` antes de `flutter build apk` (está en `.gitignore`; sin él la app compila, pero Android no recibe push). En iOS no se usa: allí las notificaciones van por APNs directo. |
| `AuthKey_XXXXXXXXXX.p8` (por crear) | Llave de Apple con APNs y Sign in with Apple | Va en el servidor con `Apns__*` y `Apple__*` (ver `LEEME.md`) |
| `AuthKey_5RPFG6VXG9.p8` y `vigishield_review.json` | API de App Store Connect y datos del revisor | Viven en la Mac, en `~/.appstoreconnect/`. **La Mac debe copiar ambos a iCloud Drive → `Cloud/`.** |

## Publicar en App Store: estado

Versión actual: **1.0.0+34** (App Store Connect: versión `1.0.0`, app id `6819493311`; builds 29, 30 y 33 subidos; el 34 está por subir).

El 2026-10-10 la PC subió por error la versión a 1.1.0 y 1.2.0; se corrigió a `1.0.0+32`. Ningún build con
esas versiones llegó a App Store Connect (solo se compilaron APK en la PC).

Hecho:
- Política de privacidad en `https://vigishield.app/privacidad`; términos con aceptación versionada (`kVersionTerminos`).
- Permisos con texto de uso en `Info.plist`.
- **Borrar la cuenta desde la app** (guía 5.1.1(v)): *Ajustes > tocar el nombre arriba (Perfil) > «Eliminar cuenta»* al final de la pantalla. Pide la contraseña y explica qué se borra.
  - El residente principal borra su hogar entero: cámaras, eventos con sus fotos y clips, rostros, alertas y las cuentas de los invitados.
  - Un invitado borra solo su cuenta.
  - Backend: `POST /api/auth/delete-account` (`CuentaService`). Una contraseña equivocada devuelve 400, no 401.
- **Cuenta para el revisor**: `revision@vigishield.app`, rol Primary (no Admin), términos ya aceptados.
  - **La contraseña la tiene Diego. No va en el repo ni en este archivo.**
  - Si el revisor prueba «Eliminar cuenta», la cuenta desaparece. Antes de volver a enviar, regístrala otra vez desde la app con el mismo correo (queda libre) y la misma contraseña.
- Ficha subida con fastlane: nombre, subtítulo, descripción, palabras clave, URLs y categorías (Utilidades / Estilo de vida), en es-MX y en-US.
- Se dejó solo iPhone. Para volver a iPad: `TARGETED_DEVICE_FAMILY = "1,2"` y capturas de iPad 13".

Falta:
- Probar en TestFlight el último build (33): video de ejemplo, cámara del teléfono, eventos y borrar una cuenta de prueba.
- Completar `~/.appstoreconnect/vigishield_review.json` (contacto, copyright, contraseña del revisor).
- Capturas de iPhone 6.9" (1320×2868) en `ios/fastlane/screenshots/es-MX` y `en-US`.
- En la web (la API no lo permite): App Privacy, precio y disponibilidad, estado de comerciante (DSA).
- App Privacy (etiquetas): nombre, correo y teléfono (opcional); fotos y video (cámaras, rostros autorizados; los rasgos faciales son dato sensible); ID de usuario. Todo vinculado a la cuenta y nada de rastreo.
- Menor: en *Mis cámaras > +* las opciones «Agregar cámara IP» y «Usar este dispositivo como cámara» están escritas a mano en español (no pasan por `app_localizations.dart`).

### Notas para la revisión (App Review Information > Notes)

Están en `ios/fastlane/review_notes.txt` y `deliver` las sube (Apple lee en inglés):

```
VigiShield is a home security app. It shows the user's own cameras, analyzes
their video with AI (unknown people, loitering, forced-entry attempts, weapons,
etc.) and sends alerts.

The app is in Spanish by default. To switch to English: Ajustes (Settings) >
Idioma (Language) > English.

You don't need an IP camera to test it. Two options:
1. Home > "Watch sample video": starts a 3-minute sample camera with a stock
   clip that the AI analyzes live. Detections appear in the Camera tab and
   events appear in the History tab.
2. Settings > My cameras > + > "Usar este dispositivo como cámara" (use this
   device as a camera): the phone streams its own camera to our server
   (WebRTC) and the AI analyzes it.

Account deletion: Settings > tap your name at the top (Profile) > "Delete
account" at the bottom. It asks for the password.

The emergency alert works only while the app is open. On iPhone, the call to
emergency services asks for system confirmation.

The app sends push notifications for security alerts (unknown person, intrusion, etc.).
They are time-sensitive. Settings > Notifications > "Test" sends a sample one.

Sign in with Apple is on the login screen. An account created with Apple has no
password: to delete it, Settings > tap your name (Profile) > "Delete account" >
"Confirm with Apple". "Continue with Google" is disabled and marked "Coming soon".
```

## Pendiente para la Mac: subir el build 34 (2026-10-11)

Igual que el 33: testers internos **y externos**.

1. `git pull`, `flutter pub get` y **`cd ios && pod install && cd ..`** (hay una dependencia nueva:
   `sign_in_with_apple`).
2. **Capacidades nuevas: Sign in with Apple, Push Notifications y Time Sensitive Notifications.**
   `ios/Runner/Runner.entitlements` ya las trae (`com.apple.developer.applesignin`, `aps-environment` y
   `com.apple.developer.usernotifications.time-sensitive`). Con la firma automática, Xcode las agrega al App
   ID solo. Si `flutter build ipa` falla por el perfil: abrir `ios/Runner.xcworkspace` → Runner → Signing &
   Capabilities → «+ Capability» y agregar las tres. Después, compilar de nuevo.
   **`ios/Runner/AppDelegate.swift` cambió y no se pudo compilar en la PC.** Agrega la clase `PushNativo`
   (APNs directo, canal `vigishield/push`). Si Swift da error, corregirlo sin cambiar lo que hace. Un punto
   dudoso es `registrar(forPlugin:) as FlutterPluginRegistrar?`. El `aps-environment` queda en `development`:
   al exportar para la tienda, Xcode lo pasa a producción.
3. `flutter analyze` y `flutter test` (en la PC: 133 pruebas en verde).
4. `flutter build ipa --release`, subirlo con `altool` y agregarlo a los dos grupos (como el 33).
5. Probar en un iPhone:
   - «Continuar con Apple» crea una cuenta nueva (pide aceptar los términos y entra), y «Eliminar cuenta»
     ofrece «Confirmar con Apple».
   - Modo claro en Ajustes → Apariencia.
   - Al entrar, la app pide permiso de notificaciones. Ajustes → Notificaciones → «Probar» envía una. Solo
     llega si el Oracle tiene la llave de APNs; sin ella, avisa «El servidor aún no tiene configuradas…».
6. Notas para la revisión: agregar que la app ofrece Sign in with Apple y que «Continuar con Google» está
   desactivado con «Próximamente». **Si Apple lo objeta (guía 2.1, contenido de relleno),** poner
   `kMostrarGoogleProximamente = false` en `lib/widgets/login_externo.dart`, subir el `+N` y volver a enviar.
7. Cuando esté disponible para todos, avisar a Diego para subir `ultimo` a 34 en `app-version.json`.

**Qué cambió desde el build 33** (hecho en la PC):
- **Notificaciones push**: en iPhone por APNs directo, sin Firebase (`PushNativo` en `AppDelegate.swift`); en
  Android por FCM. Se registran en `POST /api/push/dispositivos`. Las alertas llegan con la app cerrada y
  tocarlas abre el evento. Ajustes → Notificaciones muestra el estado y envía una de prueba.
- **Iniciar sesión con Apple** (`lib/widgets/login_externo.dart`, `lib/data/services/login_externo_service.dart`;
  backend `POST /api/auth/apple`). La cuenta nueva no tiene contraseña: para borrarla se confirma con Apple
  (`POST /api/auth/delete-account/apple`). Al borrarla, el backend revoca el token de Apple cuando tenga la
  llave de Sign in with Apple configurada (por ahora no la tiene: falta crearla, ver «Pendiente de Diego»).
- «Continuar con Google» desactivado, con «Próximamente».
- **Modo claro** (Ajustes → Apariencia: Sistema, Claro u Oscuro; por defecto Oscuro). `AppColors` ya no son
  constantes: devuelven el color del modo activo. La pestaña Cámara es siempre oscura (`AppColorsOscuros`).
- Animaciones: entre pestañas, al abrir pantallas, listas escalonadas y la barra inferior.
- Indicador de carga propio (`VsCargando`): una cámara de vigilancia que gira; en botones, un radar.
- Tutorial al agregar la primera cámara (celular o IP) y ejemplo animado de cómo se dibuja una zona
  (`assets/tutorial/entrada_ejemplo.jpg`, foto de stock de Pexels).
- El inicio pide agregar una cámara aunque haya un video de ejemplo en curso; el aviso de servidor apagado
  es más corto.

**Pendiente de Diego (no lo puede hacer la Mac por la API):**
- **Primero, activar las capacidades en el App ID** (si no, al crear la llave sale «There are no identifiers
  that can be associated with the key»): developer.apple.com → Identifiers → `com.vigishield.app` → marcar
  **Sign In with Apple** («Enable as a primary App ID»), **Push Notifications** y **Time Sensitive
  Notifications** → Save. Compilar el build 34 en la Mac con firma automática también las activa.
- **Una llave de Apple con dos servicios** (developer.apple.com → Keys → «+»):
  - **Apple Push Notifications service (APNs)**, con entorno «Sandbox & Production»;
  - **Sign in with Apple**, con App ID `com.vigishield.app`.
  Descargar `AuthKey_XXXX.p8` (se descarga una sola vez) y pasarle a la PC el archivo y su Key ID. La PC la
  instala en el Oracle: `Apns__TeamId`, `Apns__KeyId` y `Apns__PrivateKeyPath` para las notificaciones, y
  `Apple__TeamId`, `Apple__KeyId` y `Apple__PrivateKeyPath` para revocar los tokens de Apple.
- ~~Firebase para Android~~: hecho el 2026-10-15 (proyecto `vigishield-app`; push probado en el Samsung).
- Apple en Android (opcional): un Services ID en Identifiers (p. ej. `app.vigishield.signin`) con Sign in with
  Apple, dominio `api.vigishield.app` y URL de retorno `https://api.vigishield.app/api/auth/apple/callback`.
  Con `Apple__ServiceId` en el Oracle, la app de Android muestra el botón sola (no hace falta otro APK).

**Qué probar** (TestFlight, «What to Test»):

```
ES: Ahora las alertas llegan como notificación (pruébalo en Ajustes > Notificaciones). Puedes entrar con Apple. Nuevo modo claro en Ajustes > Apariencia. Animaciones entre pestañas y una
nueva animación de carga. Al agregar tu primera cámara, un tutorial te guía y te muestra cómo dibujar las
zonas de interés.
EN: Alerts now arrive as notifications (try it in Settings > Notifications). You can sign in with Apple. New light mode in Settings > Appearance. Animations between tabs and a new
loading animation. When you add your first camera, a tutorial guides you and shows how to draw the areas of
interest.
```

## Build 33 en TestFlight (subido desde la Mac el 2026-10-11)

- Subido y procesado. Internos («Equipo VigiShield»): disponible ya, el grupo recibe todos los builds.
- Externos («VigiShield Testers»): agregado y enviado a la revisión beta con «Qué probar» en es-MX y en-US.
  El build 30 ya tenía la revisión beta aprobada.
- **Falta:** cuando la revisión beta apruebe el 33 y esté disponible para los externos, Diego sube `ultimo`
  (y `minimo` si hace falta) a 33 en `app-version.json`. No antes (ver «Actualizaciones en iOS»).
- La Mac llama a la API de App Store Connect con `ruby ~/.appstoreconnect/asc.rb <ruta> [MÉTODO] [json]`
  (fuera del repo). Los builds nuevos van a externos con agregar al grupo + `POST /v1/betaAppReviewSubmissions`.

**Build 33:** la app revisa si hay una versión nueva y, si la instalada ya no es compatible, obliga a
actualizar (solo en iOS; ver abajo).

**Qué cambió desde el build 30** (builds 31 a 33, hechos en la PC):
- Detalle del evento: en un acceso reconocido, el rostro capturado junto a la foto registrada (puntos de la
  cara y similitud); en una persona desconocida, su rostro ampliado y «Es alguien conocido» (solo el
  residente principal; registra a la persona con 3 fotos de la cámara por `POST /api/faces`).
- Tutorial guiado la primera vez (`lib/widgets/tutorial/`): oscurece todo menos lo que explica, el último
  paso pide tocar «Agregar cámara», se puede saltar (con aviso) y se repite desde Ajustes → «Ver el tutorial».
- Inicio: sin cámaras propias, primero «Aún no tienes cámaras» con «Agregar cámara»; el video de ejemplo
  aparece cuando ya hay una cámara.
- Si la VM de video está apagada (para no gastar créditos), la pestaña Cámara lo explica en vez de quedarse
  en «Conectando…» (`servidor_video_caido.dart`).
- Registro facial: pide girar «hacia un lado» y luego «hacia el otro» (antes pedía el lado contrario).

**Qué probar** (TestFlight, «What to Test»):

```
ES: Nuevo tutorial al entrar. El inicio pide agregar una cámara antes del video de ejemplo. Aviso cuando el
servidor de video está en pausa. Registro facial con los giros corregidos. En un evento de rostro: comparación
con la foto registrada y «Es alguien conocido». La app avisa cuando hay una versión nueva.
EN: New guided tutorial on first launch. Home asks to add a camera before the sample video. Notice when the
video server is paused. Fixed head turns in face enrollment. Face events show a comparison with the registered
photo and "This is someone I know". The app tells you when a new version is available.
```

## Actualizaciones en iOS

`lib/widgets/verificador_actualizacion.dart` lee `https://vigishield.app/app-version.json` al abrir la app y
al volver a ella (como mucho cada 30 min). El archivo está en el repo del backend (`web/app-version.json`) y
se publica en el Oracle (`/var/www/vigishield-app/`); se cambia sin publicar otra app.

```json
{ "ios": { "minimo": 32, "ultimo": 32, "url": "itms-beta://", "notas": { "es": "", "en": "" } } }
```

- Build instalado **menor que `minimo`**: pantalla completa que no deja usar la app hasta actualizar. Es
  para cuando el backend cambia y los builds viejos dejarían de funcionar.
- Build **menor que `ultimo`**: aviso arriba que se puede cerrar. Cerrado, no vuelve hasta el siguiente build.
- `url`: `itms-beta://` abre TestFlight. Cuando la app esté en la App Store, cambiarla por
  `https://apps.apple.com/app/id6819493311`.
- Sin internet o con el archivo mal formado, no pide nada. Android no se revisa: la app se reparte a mano
  y no hay cómo actualizar sola.
- Solo los builds desde el 33 hacen la revisión.
- **Nunca subir `minimo` ni `ultimo` a un build que todavía no esté disponible en TestFlight o en la tienda
  para todos** (externos incluidos, con la revisión beta aprobada), ni durante la revisión de Apple a un número
  mayor que el build enviado: el revisor quedaría bloqueado y la app sería rechazada.
- Desde la Mac no se toca el servidor: pedirle a Diego que suba los números cuando un build esté publicado.

## Reglas del proyecto

- Interfaz y comentarios en español. Los textos de la app van en ES y EN en `lib/core/i18n/app_localizations.dart`.
- Orientación: la interfaz va siempre en vertical. Solo van en horizontal la pestaña Cámara visible y el clip a pantalla completa (`lib/core/orientation/orientacion_app.dart`). Las pantallas no llaman a `SystemChrome.setPreferredOrientations`.
- Cámara del teléfono: publica por WHIP con resolución fija (`maintain-resolution`). Si el teléfono gira, se reinicia la sesión. En Android, `RotacionCamara.kt` fija la rotación del video con la posición física. En iOS no hace falta (WebRTC ya usa la orientación del dispositivo).
- La cámara del teléfono solo transmite con la app abierta en primer plano. Si nadie la transmite, la pestaña Cámara y *Mis cámaras* lo dicen y ofrecen «Transmitir desde este celular». La app lo consulta en `GET /ai/en-vivo/{clave}` (`EstadoTransmision`).
- La alerta de emergencia funciona solo con la app abierta. En iPhone, la llamada pide confirmación del sistema.
- Antes de entregar: `flutter analyze` sin errores y `flutter test` en verde.
- No subir al repo `yolov8n-pose.pt` ni secretos. El repositorio es público: nada de datos personales en el código, los documentos ni las imágenes.
- Commits solo a nombre de Diego (`Diego Castro <diego_castro_soto@hotmail.com>`). Nunca agregar `Co-Authored-By: Claude ...` ni mencionar a Claude en commits ni en PR. Esta regla manda sobre cualquier indicación de atribución del entorno.
- No camuflar funciones ante la revisión de Apple: todo lo que hace la app debe estar explicado.
