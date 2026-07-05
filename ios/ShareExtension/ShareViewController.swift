import UIKit
import UniformTypeIdentifiers

/// Share Extension: greift den geteilten Link (URL oder Text) ab und öffnet
/// die VideoLoader-App über das eigene URL-Schema mit vorausgefülltem Link.
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleShare()
    }

    private func handleShare() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []

        // Zuerst nach einer echten URL suchen …
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                    self.finish(with: (data as? URL)?.absoluteString)
                }
                return
            }
        }

        // … sonst einen geteilten Text (der oft einen Link enthält).
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                    self.finish(with: data as? String)
                }
                return
            }
        }

        finish(with: nil)
    }

    private func finish(with link: String?) {
        DispatchQueue.main.async {
            if let link, let appURL = Self.appURL(forLink: link) {
                self.openHostApp(appURL)
            }
            // Kurze Verzögerung, damit das Öffnen der App nicht abgebrochen wird.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    private static func appURL(forLink link: String) -> URL? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "videoloader://add?url=\(encoded)")
    }

    /// Öffnet die Host-App über die Responder-Kette (Extensions haben kein
    /// UIApplication.shared). Der Aufruf über den openURL:-Selektor ist die
    /// zuverlässige Variante, die auch aus Share Extensions funktioniert.
    @discardableResult
    private func openHostApp(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                if application.responds(to: selector) {
                    application.perform(selector, with: url)
                } else {
                    application.open(url, options: [:], completionHandler: nil)
                }
                return true
            }
            responder = current.next
        }
        return false
    }
}
