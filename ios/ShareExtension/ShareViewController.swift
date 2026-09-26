import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private static let maximumImages = 50
  private static let maximumImageBytes = 100 * 1024 * 1024

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    saveIncomingImages()
  }

  private func saveIncomingImages() {
    guard let root = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.app.scanandopen.shared"
    )?.appendingPathComponent("Inbox") else {
      finish()
      return
    }
    try? FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
    )

    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
      .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
      .prefix(Self.maximumImages)
    let group = DispatchGroup()
    for provider in providers {
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
        defer { group.leave() }
        guard let url,
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= Self.maximumImageBytes else { return }
        let fileExtension = url.pathExtension.isEmpty ? "img" : url.pathExtension
        let destination = root.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        try? FileManager.default.copyItem(at: url, to: destination)
      }
    }
    group.notify(queue: .main) { [weak self] in self?.finish() }
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
