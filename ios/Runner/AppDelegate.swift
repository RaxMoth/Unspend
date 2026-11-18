import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let screenTimeChannel = ScreenTimeChannel()
    private let appPickerChannel = AppPickerChannel()

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenTimePlugin") else {
            return
        }
        screenTimeChannel.register(with: registrar)
        appPickerChannel.register(with: registrar)
    }
}
