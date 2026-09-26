import Flutter
import UIKit
import VisionKit

@main @objc class AppDelegate: FlutterAppDelegate, VNDocumentCameraViewControllerDelegate, UIDocumentPickerDelegate {
  private var callback: FlutterResult?
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    FlutterMethodChannel(name: "app.scanandopen/platform", binaryMessenger: controller.binaryMessenger).setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "scanDocument": guard VNDocumentCameraViewController.isSupported else { result(FlutterError(code:"UNAVAILABLE",message:"Document camera unavailable",details:nil)); return }; callback=result; let scanner=VNDocumentCameraViewController();scanner.delegate=self;controller.present(scanner,animated:true)
      case "saveAs": guard let args=call.arguments as? [String:Any], let path=args["path"] as? String else { result(FlutterError(code:"ARG",message:nil,details:nil));return };callback=result;let picker=UIDocumentPickerViewController(forExporting:[URL(fileURLWithPath:path)],asCopy:true);picker.delegate=self;controller.present(picker,animated:true)
      case "consumeSharedImages": result(self.consumeShared())
      default: result(FlutterMethodNotImplemented)
      }
    }
    GeneratedPluginRegistrant.register(with:self); return super.application(application,didFinishLaunchingWithOptions:launchOptions)
  }
  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController){controller.dismiss(animated:true);callback?([]);callback=nil}
  func documentCameraViewController(_ controller:VNDocumentCameraViewController,didFailWithError error:Error){controller.dismiss(animated:true);callback?(FlutterError(code:"SCAN",message:error.localizedDescription,details:nil));callback=nil}
  func documentCameraViewController(_ controller:VNDocumentCameraViewController,didFinishWith scan:VNDocumentCameraScan){var paths:[String]=[];for i in 0..<scan.pageCount{let url=FileManager.default.temporaryDirectory.appendingPathComponent("scan_\(UUID().uuidString).jpg");if let data=scan.imageOfPage(at:i).jpegData(compressionQuality:0.96){try? data.write(to:url);paths.append(url.path)}};controller.dismiss(animated:true);callback?(paths);callback=nil}
  func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController){callback?(false);callback=nil}
  func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){callback?(!urls.isEmpty);callback=nil}
  private func consumeShared() -> [String] {
    guard let root = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.app.scanandopen.shared"
    )?.appendingPathComponent("Inbox") else { return [] }
    let files = (try? FileManager.default.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: nil
    )) ?? []
    return files.compactMap { source in
      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("shared_\(UUID().uuidString).\(source.pathExtension)")
      do {
        try FileManager.default.moveItem(at: source, to: destination)
        return destination.path
      } catch {
        // A partially written or already claimed item is retried on the next launch.
        return nil
      }
    }
  }
}
