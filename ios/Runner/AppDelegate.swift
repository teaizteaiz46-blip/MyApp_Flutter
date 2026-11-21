import Flutter
import UIKit

// iOS 27: أي تطبيق ينبني بـ Xcode 27 لازم يستخدم دورة حياة UIScene، وإلا iOS 27 يسدّه أول ما ينفتح
// (صار بـ 2.0.7/2.0.8 على آيفون بيه iOS 27). الشاشة هسه يديرها FlutterSceneDelegate (Info.plist)،
// والإضافات والقنوات تنسجل بـ didInitializeImplicitFlutterEngine بدل didFinishLaunching.
// الدليل: https://docs.flutter.dev/to/uiscene-migration
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // رمز إشعارات Apple (APNs): firebase_messaging يطلبه لحاله عند بدء التطبيق، بس بنسخ Flutter
    // الجديدة إشعار البدء ما يوصله فالرمز ما يجي. فنطلبه هنا، ومن Dart (PushService) بعد ما
    // يشتغل Firebase حتى يلزم الرمز.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // قناة modo/push: Dart يطلب تسجيل الإشعارات من جديد بعد ما يشتغل Firebase
    let channel = FlutterMethodChannel(
      name: "modo/push",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "registerForRemoteNotifications" {
        UIApplication.shared.registerForRemoteNotifications()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
