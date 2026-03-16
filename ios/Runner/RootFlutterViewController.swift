import Flutter
import UIKit

final class RootFlutterViewController: FlutterViewController {
  private let diagnosticsChannelName = "aadith_sai_billing_mobile/startup_diagnostics"
  private var statusLabel: UILabel?

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = UIColor(red: 0.90, green: 0.96, blue: 1.0, alpha: 1.0)

    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Native iOS host loaded.\nWaiting for Flutter UI..."
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = UIColor(red: 0.05, green: 0.18, blue: 0.39, alpha: 1.0)
    label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
    label.backgroundColor = UIColor.white.withAlphaComponent(0.88)
    label.layer.cornerRadius = 16
    label.layer.masksToBounds = true
    label.accessibilityIdentifier = "startup_diagnostic_label"

    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
    ])

    statusLabel = label

    let channel = FlutterMethodChannel(
      name: diagnosticsChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "startupState" else {
        result(FlutterMethodNotImplemented)
        return
      }

      if let args = call.arguments as? [String: Any],
         let message = args["message"] as? String {
        DispatchQueue.main.async {
          self?.statusLabel?.text = message
        }
      }
      result(nil)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      guard let self = self else { return }
      if self.statusLabel?.text == "Native iOS host loaded.\nWaiting for Flutter UI..." {
        self.statusLabel?.text = "Dart/Flutter has not reported startup after 5 seconds.\nPlease report this screen."
      }
    }
  }
}
