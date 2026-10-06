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
flutter build ipa --release           # luego Xcode > Organizer (o Transporter) para subirlo
```

- Bundle ID `com.vigishield.app`, equipo `ZUXS3B846T`, iOS mínimo 15.5.
- El `Podfile` define `PERMISSION_CAMERA=1` (permission_handler). Sin eso, el permiso de cámara no se pide.
- `ITSAppUsesNonExemptEncryption = false`: solo se usa HTTPS/TLS estándar.
- Versión: cada tanda sube semver en `pubspec.yaml` (`version: x.y.z+N`) y en
  `_versionPorDefecto` de `lib/core/constants/app_constants.dart`.
  **Cada subida a App Store Connect necesita un número de build (`+N`) mayor.**
- El build de release es el de tienda: las herramientas de validación (OE4) no
  se incluyen (`kValidationTools`) y la sesión de validación solo existe en Android.

## Publicar en App Store: estado

Hecho:
- Política de privacidad en `https://vigishield.app/privacidad`; términos con aceptación versionada (`kVersionTerminos`).
- Permisos con texto de uso en `Info.plist`.

Falta (bloqueante para Apple):
- **Borrar la cuenta desde la app** (guía 5.1.1(v)): no existe todavía. Hace falta un endpoint en el backend y una pantalla en Perfil.
- **Cuenta de prueba para el revisor**, sin rol Admin. El revisor no tiene cámara IP: que use *Inicio > «Ver video de ejemplo»* (video de 3 min analizado por la IA) o *Ajustes > Mis cámaras > Agregar > «Usar este dispositivo como cámara»*.
- App Privacy (etiquetas): nombre, correo y teléfono (opcional); fotos y video (cámaras, rostros autorizados; los rasgos faciales son dato sensible); ID de usuario. Todo vinculado a la cuenta y nada de rastreo.
- Capturas de iPhone 6.9". Si se mantiene iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), también de iPad 13"; la app no está pensada para iPad.

## Reglas del proyecto

- Interfaz y comentarios en español. Los textos de la app van en ES y EN en `lib/core/i18n/app_localizations.dart`.
- Orientación: la interfaz va siempre en vertical. Solo van en horizontal la pestaña Cámara visible y el clip a pantalla completa (`lib/core/orientation/orientacion_app.dart`). Las pantallas no llaman a `SystemChrome.setPreferredOrientations`.
- Cámara del teléfono: publica por WHIP con resolución fija (`maintain-resolution`). Si el teléfono gira, se reinicia la sesión. En Android, `RotacionCamara.kt` fija la rotación del video con la posición física. En iOS no hace falta (WebRTC ya usa la orientación del dispositivo).
- La alerta de emergencia funciona solo con la app abierta. En iPhone, la llamada pide confirmación del sistema.
- Antes de entregar: `flutter analyze` sin errores y `flutter test` en verde.
- No subir al repo `yolov8n-pose.pt` ni secretos. Commits con `Co-Authored-By: Claude ...`.
- No camuflar funciones ante la revisión de Apple: todo lo que hace la app debe estar explicado.
