import UIKit
import UniformTypeIdentifiers

final class ShareViewController:UIViewController {
  override func viewDidAppear(_ animated:Bool){super.viewDidAppear(animated);save()}
  private func save(){guard let root=FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:"group.app.scanandopen.shared")?.appendingPathComponent("Inbox") else{finish();return};try? FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let providers=(extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap{$0.attachments ?? []}.filter{$0.hasItemConformingToTypeIdentifier(UTType.image.identifier)};let group=DispatchGroup();let stamp=Int(Date().timeIntervalSince1970*1000);for (index,provider) in providers.enumerated(){group.enter();provider.loadFileRepresentation(forTypeIdentifier:UTType.image.identifier){url,_ in defer{group.leave()};guard let url else{return};try? FileManager.default.copyItem(at:url,to:root.appendingPathComponent("\(stamp)_\(String(format:"%03d",index))_\(UUID().uuidString).\(url.pathExtension.isEmpty ? "jpg":url.pathExtension)"))}};group.notify(queue:.main){self.finish()}}
  private func finish(){extensionContext?.completeRequest(returningItems:nil)}
}
