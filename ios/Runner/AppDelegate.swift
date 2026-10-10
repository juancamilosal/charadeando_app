import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TvDisplayPlugin") {
      TvDisplayPlugin.register(with: registrar)
    }
  }
}

/// Avisa a Flutter si el iPhone se está viendo en un televisor (duplicar
/// pantalla con AirPlay o un adaptador HDMI): en ese caso el sistema
/// conecta una segunda pantalla.
class TvDisplayPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var last: Bool?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TvDisplayPlugin()
    let methods = FlutterMethodChannel(
      name: "charadeando/tv", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: "charadeando/tv/conexion", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "abrirAjustes", "desconectar":
      // iOS no deja abrir ni detener "Duplicar pantalla" desde una app: la
      // app explica cómo hacerlo desde el Centro de control.
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var connected: Bool {
    if #available(iOS 16.0, *) {
      let external = UIApplication.shared.connectedScenes.contains {
        $0.session.role == .windowExternalDisplayNonInteractive
      }
      if external { return true }
    }
    return UIScreen.screens.count > 1
  }

  // Las notificaciones llegan antes de que la escena o la pantalla salga de
  // la lista, así que se revisa en la siguiente vuelta.
  @objc private func changed() {
    DispatchQueue.main.async { [weak self] in self?.send() }
  }

  private func send() {
    let now = connected
    if now == last { return }
    last = now
    sink?(now)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    last = nil
    let center = NotificationCenter.default
    for name in [
      UIScreen.didConnectNotification, UIScreen.didDisconnectNotification,
      UIScene.willConnectNotification, UIScene.didDisconnectNotification,
    ] {
      center.addObserver(self, selector: #selector(changed), name: name, object: nil)
    }
    send()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    sink = nil
    return nil
  }
}
