import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // رمز إشعارات Apple (APNs): firebase_messaging يطلبه لحاله عند بدء التطبيق، بس بنسخ Flutter
    // الجديدة إشعار البدء ما يوصله فالرمز ما يجي. فنطلبه هنا، ومن Dart (PushService) بعد ما
    // يشتغل Firebase حتى يلزم الرمز.
    application.registerForRemoteNotifications()
    if let registrar = self.registrar(forPlugin: "ModoPushRegistration") {
      let channel = FlutterMethodChannel(name: "modo/push", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "registerForRemoteNotifications" {
          UIApplication.shared.registerForRemoteNotifications()
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
