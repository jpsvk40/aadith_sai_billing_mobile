import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Force iOS to request an APNs device token from Apple.
    //
    // firebase_messaging's method swizzling is supposed to call this
    // automatically once notification permission is granted, but with this
    // app's storyboard-instantiated FlutterViewController (implicit engine) it
    // never fired — so FirebaseMessaging.getToken() stayed stuck on
    // `apns-token-not-set` and no iPhone ever registered an FCM token.
    //
    // Calling it explicitly here (runs in didFinishLaunching, before scene /
    // storyboard setup) reliably triggers the APNs token. FCM's swizzling still
    // intercepts application:didRegisterForRemoteNotificationsWithDeviceToken:
    // and maps the APNs token to the FCM token — so this does not conflict with
    // the plugin, it just guarantees the request is actually made.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
