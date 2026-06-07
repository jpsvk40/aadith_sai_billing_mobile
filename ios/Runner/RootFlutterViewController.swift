import Flutter
import UIKit

final class RootFlutterViewController: FlutterViewController {
  private let diagnosticsChannelName = "aadith_sai_billing_mobile/startup_diagnostics"

  override func viewDidLoad() {
    super.viewDidLoad()

    // Light background to avoid a black flash before the Flutter UI paints.
    view.backgroundColor = UIColor(red: 0.90, green: 0.96, blue: 1.0, alpha: 1.0)

    // Keep the diagnostics channel as a no-op so the Dart side's calls still
    // succeed, but do NOT render any on-screen label. (This used to show a
    // centered "startup state" UILabel for debugging the white-screen issue,
    // which leaked through as "Login screen build" over the app UI.)
    let channel = FlutterMethodChannel(
      name: diagnosticsChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      result(call.method == "startupState" ? nil : FlutterMethodNotImplemented)
    }
  }
}
