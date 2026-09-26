import Flutter
import UIKit
import VisionKit

@main @objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, VNDocumentCameraViewControllerDelegate, UIDocumentPickerDelegate {
  // Scanning and saving are tracked separately so one flow never answers the other.
  private var scanCallback: FlutterResult?
  private var saveCallback: FlutterResult?

  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// With the UIScene life cycle the engine is created by the scene, so plugins and the
  /// app's method channel are registered here rather than from `window`.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(name: "app.scanandopen/platform", binaryMessenger: engineBridge.applicationRegistrar.messenger()).setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "scanDocument":
        guard VNDocumentCameraViewController.isSupported else { result(FlutterError(code: "UNAVAILABLE", message: "Document camera unavailable", details: nil)); return }
        guard self.scanCallback == nil else { result(FlutterError(code: "BUSY", message: "A scan is already in progress", details: nil)); return }
        guard let presenter = self.topViewController() else { result(FlutterError(code: "UNAVAILABLE", message: "No window", details: nil)); return }
        self.scanCallback = result
        let scanner = VNDocumentCameraViewController(); scanner.delegate = self; presenter.present(scanner, animated: true)
      case "saveAs":
        guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else { result(FlutterError(code: "ARG", message: nil, details: nil)); return }
        guard self.saveCallback == nil else { result(FlutterError(code: "BUSY", message: "A save is already in progress", details: nil)); return }
        guard let presenter = self.topViewController() else { result(FlutterError(code: "UNAVAILABLE", message: "No window", details: nil)); return }
        self.saveCallback = result
        let picker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: path)], asCopy: true); picker.delegate = self; presenter.present(picker, animated: true)
      case "consumeSharedImages": result(self.consumeShared())
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  /// The front-most view controller of the active window scene, for presenting system UI.
  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { controller.dismiss(animated: true); scanCallback?([String]()); scanCallback = nil }
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { controller.dismiss(animated: true); scanCallback?(FlutterError(code: "SCAN", message: error.localizedDescription, details: nil)); scanCallback = nil }
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    var paths: [String] = []
    for i in 0..<scan.pageCount {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("scan_\(UUID().uuidString).jpg")
      if let data = scan.imageOfPage(at: i).jpegData(compressionQuality: 0.96), (try? data.write(to: url)) != nil { paths.append(url.path) }
    }
    controller.dismiss(animated: true); scanCallback?(paths); scanCallback = nil
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { saveCallback?(false); saveCallback = nil }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { saveCallback?(!urls.isEmpty); saveCallback = nil }

  /// Moves shared images out of the App Group inbox so each share is imported exactly once.
  private func consumeShared() -> [String] {
    let fm = FileManager.default
    guard let root = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.app.scanandopen.shared")?.appendingPathComponent("Inbox") else { return [] }
    let files = ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
    let incoming = fm.temporaryDirectory.appendingPathComponent("incoming"); try? fm.createDirectory(at: incoming, withIntermediateDirectories: true)
    return files.compactMap { file in
      let target = incoming.appendingPathComponent(file.lastPathComponent)
      try? fm.removeItem(at: target)
      if (try? fm.moveItem(at: file, to: target)) != nil { return target.path }
      try? fm.removeItem(at: file); return nil
    }
  }
}
