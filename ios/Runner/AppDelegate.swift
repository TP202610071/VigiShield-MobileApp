import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Antes de terminar de arrancar, para no perder la notificación que abrió la app.
    PushNativo.compartido.alArrancar()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushNativo") as FlutterPluginRegistrar? {
      PushNativo.register(with: registrar)
    }
  }
}

// MARK: - Notificaciones push por APNs directo (sin Firebase)

/// Canal "vigishield/push" con Dart:
/// - pedirPermisoYToken: pide permiso y devuelve el token de APNs en
///   hexadecimal (null si el usuario no lo dio).
/// - estadoPermiso: "concedido", "denegado" o "sin_decidir".
/// - entorno: "sandbox" (compilada desde Xcode) o "produccion" (TestFlight y
///   App Store). APNs tiene un servidor para cada uno.
/// - eventoInicial: el evento de la notificación que abrió la app, si hubo.
/// - Hacia Dart: tokenRenovado(token) y abrirEvento(id).
///
/// Va en este archivo para no tener que agregar uno nuevo al proyecto de Xcode.
final class PushNativo: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
  static let compartido = PushNativo()

  private var canal: FlutterMethodChannel?
  private var token: String?
  private var eventoPendiente: String?
  private var esperandoToken: [FlutterResult] = []

  func alArrancar() {
    UNUserNotificationCenter.current().delegate = self
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let yo = compartido
    let canal = FlutterMethodChannel(name: "vigishield/push", binaryMessenger: registrar.messenger())
    yo.canal = canal
    registrar.addMethodCallDelegate(yo, channel: canal)
    // Así FlutterAppDelegate le reenvía el token de APNs.
    registrar.addApplicationDelegate(yo)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "plataforma":
      result("ios")
    case "entorno":
      result(PushNativo.entorno())
    case "eventoInicial":
      result(eventoPendiente)
      eventoPendiente = nil
    case "estadoPermiso":
      UNUserNotificationCenter.current().getNotificationSettings { ajustes in
        let estado: String
        switch ajustes.authorizationStatus {
        case .authorized, .provisional, .ephemeral: estado = "concedido"
        case .denied: estado = "denegado"
        default: estado = "sin_decidir"
        }
        DispatchQueue.main.async { result(estado) }
      }
    case "pedirPermisoYToken":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { concedido, _ in
        DispatchQueue.main.async {
          guard concedido else {
            result(nil)
            return
          }
          if let token = self.token {
            result(token)
            return
          }
          self.esperandoToken.append(result)
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Token de APNs (lo reenvía FlutterAppDelegate)

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    let cambio = token != nil && token != hex
    token = hex
    esperandoToken.forEach { $0(hex) }
    esperandoToken.removeAll()
    if cambio { canal?.invokeMethod("tokenRenovado", arguments: hex) }
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    esperandoToken.forEach { $0(FlutterError(code: "apns", message: error.localizedDescription, details: nil)) }
    esperandoToken.removeAll()
  }

  // MARK: UNUserNotificationCenterDelegate

  /// Con la app abierta también se muestra (por defecto iOS la escondería).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  /// Se tocó la notificación: se abre el evento.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let id = response.notification.request.content.userInfo["eventId"] as? String {
      // Se guarda por si Dart aún no escucha (app abierta en frío por el toque).
      eventoPendiente = id
      canal?.invokeMethod("abrirEvento", arguments: id)
    }
    completionHandler()
  }

  /// Las apps de TestFlight y App Store no traen embedded.mobileprovision y usan
  /// producción; las instaladas desde Xcode lo traen con aps-environment development.
  private static func entorno() -> String {
    guard let ruta = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
          let datos = try? Data(contentsOf: URL(fileURLWithPath: ruta)),
          let texto = String(data: datos, encoding: .isoLatin1) else { return "produccion" }
    let limpio = texto.components(separatedBy: .whitespacesAndNewlines).joined()
    return limpio.contains("<key>aps-environment</key><string>development</string>") ? "sandbox" : "produccion"
  }
}
